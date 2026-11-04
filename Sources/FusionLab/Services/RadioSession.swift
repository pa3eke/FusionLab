import Foundation
import Combine
import AppKit

final class RadioSession: ObservableObject {
 @Published private(set) var selectedMode:DigitalMode = .fusion
 @Published private(set) var selectedVocoder:VocoderBackend = .ambeServer
 @Published private(set) var fusionPresets=QuickPreset.load(.fusion)
 @Published private(set) var dmrPresets=QuickPreset.load(.dmr)
 @Published private(set) var nxdnPresets=QuickPreset.load(.nxdn)
 @Published var nxdn=NXDNConfiguration.load() {didSet{nxdn.save()}}
 @Published private(set) var switchingReflector=false
 @Published private(set) var modeSwitchTarget:DigitalMode?
 var switchingMode:Bool {modeSwitchTarget != nil}
 private var modeSwitchExclusive:Bool?
 private var disconnectToken=UUID()
 var canSwitchMode:Bool {!transmitting && !preparingTransmit && !drainingTransmit && !switchingReflector && !switchingMode && !closing && !pttRequests.hasHeld}
 private var reflectorSwitchToken=UUID()
 var quickPresets:[QuickPreset?] {switch selectedMode {case .fusion:return fusionPresets;case .dmr:return dmrPresets;case .nxdn:return nxdnPresets}}
 private func networkEndpoint(for mode:DigitalMode)->(host:String,port:String) {
  switch mode {case .fusion:return (host,port);case .dmr:return (dmr.host,dmr.port);case .nxdn:return (nxdn.host,nxdn.port)}
 }
 var canChoosePreset:Bool {!transmitting && !preparingTransmit && !drainingTransmit && !switchingReflector && !switchingMode && !closing}
 @Published var dmr=DMRConfiguration.load()
 @Published var dmrPassword=""
 @Published var rememberDMRPassword=UserDefaults.standard.bool(forKey:"rememberDMRPassword")
 private var connectionProfile:VoiceProfile = .fusion
 private let brandMeister:BrandMeisterConnection
 private var dmrLoggedIn=false
 private let passwordStore:DMRPasswordStorage
 private let passwordQueue=DispatchQueue(label:"nl.pa3eke.FusionLab.password",qos:.userInitiated)
 @Published private(set) var loadingDMRPassword=false
 private var initialPasswordRestoreStarted=false
 private let nxdnCallsignDirectory:DMRCallsignLookup
 private var nxdnStationSource:UInt16?
 private var nxdnCallsignTask:Task<Void,Never>?
 private let callsignDirectory:DMRCallsignLookup
 private var dmrStationSource:UInt32?
 private var dmrCallsignTask:Task<Void,Never>?
 private var dmrReceiveStream:UInt32?
 @Published var call=UserDefaults.standard.string(forKey:"call") ?? "PA3EKE"
 @Published var host=UserDefaults.standard.string(forKey:"host") ?? "c4fm.pa7lim.nl"
 @Published var port=UserDefaults.standard.string(forKey:"port") ?? "42000"
 @Published var ambeHost=UserDefaults.standard.string(forKey:"ambeHost") ?? "192.168.1.111"
 @Published var ambePort=UserDefaults.standard.string(forKey:"ambePort") ?? "2460"
 @Published var exclusive=false
 @Published var active=false
 @Published var transmitting=false {didSet{xkeys.setTransmitting(transmitting)}}
 @Published var preparingTransmit=false
 @Published var drainingTransmit=false
 @Published var microphoneTesting=false
 @Published var readyToTransmit=false
 @Published var connectionError=""
 @Published var pttKeyMode=PTTKeyMode(rawValue:UserDefaults.standard.string(forKey:"pttKeyMode") ?? "hold") ?? .hold {
  didSet{
   guard pttKeyMode != oldValue else{return}
   releasePTT(prefix:"keyboard",reason:"toetsmodus gewijzigd");pttKey.setActive(false)
   UserDefaults.standard.set(pttKeyMode.rawValue,forKey:"pttKeyMode");syncPTTKey()
  }
 }
 @Published var pttKeyStatus="Numerieke 0 wordt actief zodra de verbinding zendklaar is."
 @Published var pttSecondsRemaining=180
 @Published var transmitLimit=TransmitLimit.load() {
  didSet{UserDefaults.standard.set(transmitLimit.rawValue,forKey:"transmitLimitSeconds")}
 }
 private var activeTransmitLimit:TransmitLimit = .threeMinutes
 @Published var pttButtonToggle=UserDefaults.standard.bool(forKey:"pttButtonToggle") {
  didSet{
   guard pttButtonToggle != oldValue else{return}
   releasePTT(prefix:"button",reason:"PTT-modus gewijzigd");releasePTT(prefix:"keyboard",reason:"PTT-modus gewijzigd");pttKey.setActive(false)
   UserDefaults.standard.set(pttButtonToggle,forKey:"pttButtonToggle")
   syncPTTKey()
  }
 }
 let xkeys:XKeysController
 private var pttRequests=PTTRequests()
 private var pttInhibitions=Set<String>()
 private var activityObservers:[(NotificationCenter,NSObjectProtocol)]=[]
 private var effectivePTTKeyMode:PTTKeyMode {pttKeyMode == .off ? .off:pttButtonToggle ? .toggle:.hold}
 private let pttKey:PTTKeyRegistration

 @Published var inputDevices:[AudioInputDevice]=AudioInputDevices.list()
 @Published var selectedInputUID:String {didSet{UserDefaults.standard.set(selectedInputUID,forKey:"inputUID")}}
 @Published var inputChannel:Int=UserDefaults.standard.integer(forKey:"inputChannel") {didSet{UserDefaults.standard.set(inputChannel,forKey:"inputChannel")}}
 @Published var microphoneTestFrames=0
 @Published var microphoneGainDB:Double=UserDefaults.standard.double(forKey:"microphoneGainDB") {
  didSet{
   let bounded=microphoneGainDB.isFinite ? min(36,max(-12,microphoneGainDB)):0
   if microphoneGainDB != bounded {microphoneGainDB=bounded;return}
   UserDefaults.standard.set(microphoneGainDB,forKey:"microphoneGainDB");transmitter.setGain(microphoneGainDB)
  }
 }
 @Published var microphonePeak:Float=0
 @Published var microphoneClipping=false
 @Published var microphoneLevel:Float=0
 @Published var microphoneFrames=0
 @Published var encodedFrames=0
 @Published var transmittedFrames=0
 @Published var receivingAudio=false
 @Published var receptionDetail=""
 private var rxDiscarded=0
 var canTransmit:Bool {active && ambeReady && readyToTransmit && pttInhibitions.isEmpty && !closing && !switchingMode && !preparingTransmit && !transmitting && !microphoneTesting && !receivingAudio && Date().timeIntervalSince(lastIncoming ?? .distantPast)>0.4}
 private let microphone:MicrophoneSource
 private let transmitter:TransmissionLoop
 private var microphoneToken=UUID()
 private var lastIncoming:Date?
 @Published var ysfStatus="Losgekoppeld"
 @Published var ambeStatus="Losgekoppeld"
 @Published var station="Wachten op ontvangst"
 var receivedStationQRZURL:URL? {
  guard !transmitting else{return nil}
  let call=station.components(separatedBy:" · ")[0].trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
  guard (3...16).contains(call.count),call.utf8.allSatisfy({(65...90).contains($0)||(48...57).contains($0)||$0==47}),call.utf8.contains(where:{(65...90).contains($0)}),call.utf8.contains(where:{(48...57).contains($0)}),let escaped=call.addingPercentEncoding(withAllowedCharacters:.alphanumerics) else{return nil}
  return URL(string:"https://www.qrz.com/db/\(escaped)")
 }
 @Published var gateway="—"
 @Published var mode="Fusion DN · V/D2"
 @Published var networkFrames=0
 @Published var voiceFrames=0
 @Published var pcmFrames=0
 @Published var errors=0
 @Published var dropped=0
 @Published var level:Float=0
 @Published var log=""
 private let logClock:DateFormatter={let value=DateFormatter();value.dateFormat="HH:mm:ss";return value}()
 @Published var receiveMuted=false {didSet{audio.setMuted(receiveMuted)}}
 @Published var volume:Double=0.6 {didSet{audio.volume=Float(volume)}}
 @Published var receiveEQ=ReceiveEQSettings.load() {
  didSet{receiveEQ.save();applyReceiveEQ()}
 }
 @Published var receiveEQBypassed=UserDefaults.standard.bool(forKey:"receiveEQBypassed") {
  didSet{UserDefaults.standard.set(receiveEQBypassed,forKey:"receiveEQBypassed");applyReceiveEQ()}
 }
 private func applyReceiveEQ(){audio.setEQ(receiveEQBypassed ? .init():receiveEQ)}
 @Published var receiveAGCEnabled=(UserDefaults.standard.object(forKey:"receiveAGCEnabled") as? Bool) ?? true {
  didSet {UserDefaults.standard.set(receiveAGCEnabled,forKey:"receiveAGCEnabled");audio.setAGCEnabled(receiveAGCEnabled)}
 }
 private let ioQueue=DispatchQueue(label:"nl.pa3eke.FusionLab.audio",qos:.userInitiated)
 private let ysf:UDPLink
 private let ambe:VocoderTransport
 private let audio:AudioOutput
 private var timer:Timer?
 private var microphoneStartupTimer:Timer?
 private var microphoneHasAudio=false
 private var lastYSF:Date?, lastPCM:Date?
 private var lastPoll=Date.distantPast
 private var handshakeDeadline=Date.distantFuture
 private var expected:UInt8?
 private var ambeReady=false
 private var ysfStarted=false
 private var lastSequence:UInt8?
 private var streamSource=""
 private var began=Date()
 private var closing=false
 init(microphone:MicrophoneSource=MicrophoneInput(),pttKey:PTTKeyRegistration=GlobalPTTKey(),passwordStore:DMRPasswordStorage=DMRPasswordStore(),callsignDirectory:DMRCallsignLookup=DMRCallsignDirectory(),nxdnCallsignDirectory:DMRCallsignLookup=NXDNCallsignDirectory(),xkeysTransport:XKeysTransport=XKeysDeviceManager(),vocoderBackend:VocoderBackend = .ambeServer){
  self.xkeys=XKeysController(transport:xkeysTransport)
  self.microphone=microphone
  self.pttKey=pttKey
  self.passwordStore=passwordStore
  self.callsignDirectory=callsignDirectory
  self.nxdnCallsignDirectory=nxdnCallsignDirectory
  self.ysf=UDPLink(queue:ioQueue);self.ambe=VocoderTransport(queue:ioQueue);self.audio=AudioOutput(queue:ioQueue)
  self.transmitter=TransmissionLoop(queue:ioQueue)
  self.brandMeister=BrandMeisterConnection(queue:ioQueue)
  self.selectedInputUID=UserDefaults.standard.string(forKey:"inputUID") ?? AudioInputDevices.list().first(where:{$0.name.localizedCaseInsensitiveContains("PUC2")})?.id ?? ""
  self.selectedVocoder=vocoderBackend
  self.audio.setAGCEnabled(receiveAGCEnabled)
  self.applyReceiveEQ()
  selectedMode=DigitalMode(rawValue:UserDefaults.standard.string(forKey:"digitalMode") ?? "fusion") ?? .fusion
  mode=selectedMode.voiceTitle
  brandMeister.onSend={[weak self] in self?.ysf.send($0)}
  brandMeister.onProgress={[weak self] in self?.ysfStatus=$0;self?.note($0)}
  brandMeister.onReady={[weak self] in
   guard let self,self.active,!self.closing else{return}
   self.dmrLoggedIn=true;self.lastYSF=Date();self.readyToTransmit=true;self.modeSwitchTarget=nil;self.transmitter.setEnabled(true)
   self.ysfStatus="Verbonden · BrandMeister";self.note("BrandMeister-aanmelding bevestigd.")
  }
  brandMeister.onError={[weak self] in self?.fail($0)}
  transmitter.onAMBE={[weak self] in self?.ambe.send($0)}
  transmitter.onNetwork={[weak self] in self?.ysf.send($0)}
  transmitter.onFinished={[weak self] snapshot in
   guard let self else{return}
   self.microphoneStartupTimer?.invalidate();self.microphoneStartupTimer=nil
   self.microphone.stop();self.microphoneToken=UUID()
   self.transmitting=false;self.drainingTransmit=false;self.resetMicrophoneMeter()
   self.pttRequests.transmissionEnded();self.pttSecondsRemaining=0
   if snapshot.timedOut {self.note("Time-out: PTT automatisch gestopt na \(self.activeTransmitLimit.rawValue) seconden.")}
   self.syncPTTKey()
   self.microphoneFrames=snapshot.inputCount;self.encodedFrames=snapshot.encodedCount;self.transmittedFrames=snapshot.networkCount
   self.pttSecondsRemaining=snapshot.remainingSeconds
   self.note("PTT gestopt · \(self.encodedFrames) AMBE-blokken, \(self.transmittedFrames) \(self.selectedMode.shortTitle)-pakketten · bufferpiek \(snapshot.inputHighWaterMark) · overgeslagen \(snapshot.droppedInputCount).")
  }
  transmitter.onError={[weak self] in self?.recoverTransmit($0)}
  transmitter.onUpdate={[weak self] snapshot in
   guard let self,self.transmitting else{return}
   self.microphoneFrames=snapshot.inputCount;self.encodedFrames=snapshot.encodedCount;self.transmittedFrames=snapshot.networkCount
   self.pttSecondsRemaining=snapshot.remainingSeconds
   if snapshot.draining && !self.drainingTransmit {self.microphone.stop();self.microphoneToken=UUID();self.drainingTransmit=true;self.resetMicrophoneMeter()}
  }
  transmitter.onMeter={[weak self] token,meter in
   guard let self,self.microphoneToken==token else{return}
   self.microphoneHasAudio=true
   self.microphoneLevel=meter.rms;self.microphonePeak=meter.peak;self.microphoneClipping=meter.clipped
   if self.microphoneTesting {self.microphoneTestFrames=meter.count}
  }
  transmitter.onPCM={[weak self] in self?.audio.append($0)}
  transmitter.onPCMUpdate={[weak self] count,date,rms in
   guard let self,self.active,self.ambeReady,!self.transmitting else{return}
   self.pcmFrames=count;self.lastPCM=date;self.level=rms;self.ambeStatus=self.selectedMode == .dmr ? "Gereed · DMR 2450/1150":"Gereed · \(self.selectedMode.shortTitle) 2450"
  }
  transmitter.onRXTimeout={[weak self] in self?.ambeStatus="Geen PCM-audio ontvangen"}
  transmitter.onReception={[weak self] stats in
   guard let self,self.active else{return}
   self.receivingAudio=stats.busy
   self.receptionDetail="Ontvangst \(stats.received) → decoder \(stats.submitted) → audio \(stats.decoded) · wacht \(stats.buffered) · overgeslagen \(stats.discarded)"
   if stats.discarded>self.rxDiscarded {self.note("Ontvangstbuffer vol: \(stats.discarded) spraakblokken overgeslagen.")}
   self.rxDiscarded=stats.discarded
  }
  ysf.onReady={[weak self] in DispatchQueue.main.async{self?.poll()}}
  ysf.onData={[weak self] data in
   self?.brandMeister.receive(data)
   self?.transmitter.receiveNetworkAudio(data)
   DispatchQueue.main.async{guard let self else{return};switch self.selectedMode {case .dmr:self.receiveDMR(data);case .fusion:self.receiveYSF(data);case .nxdn:self.receiveNXDN(data)}}
  }
  ysf.onError={[weak self] error in DispatchQueue.main.async{self?.fail("Netwerk: \(error)")}}
  ambe.onReady={[weak self] in DispatchQueue.main.async{self?.command(Packets.control(0x33),expect:0x39)}}
  ambe.onData={[weak self] data in
   guard let self else{return}
   if data.count>4,data[3]==1 {self.transmitter.receiveEncoded(data)}
   else if data.count>4,data[3]==2 {self.transmitter.receivePCM(data)}
   else {DispatchQueue.main.async{[weak self] in self?.receiveAMBE(data)}}
  }
  ambe.onError={[weak self] error in DispatchQueue.main.async{self?.fail("AMBE: \(error)")}}
  pttKey.onKey={[weak self] pressed in self?.handlePTTKey(pressed)}
  xkeys.onAction={[weak self] source,key,binding,down in self?.handleXKeys(source:source,key:key,binding:binding,down:down)}
  xkeys.onRelease={[weak self] prefix in self?.releasePTT(prefix:prefix,reason:"X-keys vrijgegeven")}
  installPTTActivityObservers()
 }
 private func installPTTActivityObservers(){
  let workspace=NSWorkspace.shared.notificationCenter
  let events:[(NotificationCenter,Notification.Name,Bool,String)]=[
   (workspace,NSWorkspace.willSleepNotification,true,"sleep"),(workspace,NSWorkspace.didWakeNotification,false,"sleep"),
   (workspace,NSWorkspace.screensDidSleepNotification,true,"display"),(workspace,NSWorkspace.screensDidWakeNotification,false,"display"),
   (workspace,NSWorkspace.sessionDidResignActiveNotification,true,"session"),(workspace,NSWorkspace.sessionDidBecomeActiveNotification,false,"session")]
  for (center,name,on,reason) in events {
   let token=center.addObserver(forName:name,object:nil,queue:.main){[weak self] _ in self?.setPTTInputInhibited(on,reason:reason)}
   activityObservers.append((center,token))
  }
  // Screen-lock notifications supplement the documented session/sleep hooks.
  // They never enable a transmitter: unlock only removes this one inhibition.
  let distributed=DistributedNotificationCenter.default()
  for (name,on) in [("com.apple.screenIsLocked",true),("com.apple.screenIsUnlocked",false)] {
   let token=distributed.addObserver(forName:Notification.Name(name),object:nil,queue:.main){[weak self] _ in self?.setPTTInputInhibited(on,reason:"lock")}
   activityObservers.append((distributed,token))
  }
  if let info=CGSessionCopyCurrentDictionary() as? [String:Any],info["CGSSessionScreenIsLocked"] as? Bool == true {setPTTInputInhibited(true,reason:"lock")}
 }
 func setPTTInputInhibited(_ on:Bool,reason:String="test"){
  if on {pttInhibitions.insert(reason);emergencyStopTransmit(reason:"sessie niet actief / vergrendeld");_ = pttRequests.release(prefix:"",engaged:false)}
  else {pttInhibitions.remove(reason)}
  xkeys.setSuspended(!pttInhibitions.isEmpty);syncPTTKey()
 }

 private func syncPTTKey(){
  let engaged=transmitting || preparingTransmit
  let wanted=active && !closing && pttInhibitions.isEmpty && pttKeyMode != .off && (canTransmit || engaged || pttRequests.held("keyboard"))
  pttKey.setActive(wanted)
  if pttKeyMode == .off {pttKeyStatus="Numerieke 0 uit · gebruik de PTT-knop."}
  else if pttKey.failed {pttKeyStatus="Numerieke 0 bezet of niet beschikbaar · gebruik de PTT-knop."}
  else if pttKey.registered {pttKeyStatus="Numerieke 0 actief in alle programma’s · \(effectivePTTKeyMode.title.lowercased())."}
  else {pttKeyStatus="Numerieke 0 wordt actief zodra de verbinding zendklaar is."}
 }
 private func handlePTTKey(_ pressed:Bool){
  guard pttKey.registered else{return}
  handlePTTInput(source:"keyboard",pressed:pressed,mode:effectivePTTKeyMode,reason:effectivePTTKeyMode == .toggle ? "numerieke 0 opnieuw ingedrukt":"numerieke 0 losgelaten")
  syncPTTKey()
 }
 func setPTT(_ on:Bool){if on {if !transmitting && !preparingTransmit {toggleTransmit()}}else{stopTransmit()}}
 func handlePTTButton(pressed:Bool){
  handlePTTInput(source:"button",pressed:pressed,mode:pttButtonToggle ? .toggle:.hold,reason:pttButtonToggle ? "PTT-knop opnieuw ingedrukt":"PTT-knop losgelaten")
 }
 func handlePTTInput(source:String,pressed:Bool,mode:PTTKeyMode,reason:String="bediening"){
  let engaged=transmitting || preparingTransmit
  let canJoin=pttInhibitions.isEmpty && !closing && !drainingTransmit && (canTransmit || engaged)
  let action=pttRequests.event(source:source,pressed:pressed,mode:mode,canStart:canJoin,engaged:engaged)
  if action == .start {beginTransmit()}
  else if action == .stop {stopTransmit(reason:reason)}
  if !transmitting && !preparingTransmit {pttRequests.transmissionEnded()}
 }
 private func releasePTT(prefix:String,reason:String){
  if pttRequests.release(prefix:prefix,engaged:transmitting || preparingTransmit) == .stop {stopTransmit(reason:reason)}
 }
 func handleFocusLoss(){releasePTT(prefix:"button",reason:"vensterfocus verloren");releasePTT(prefix:"command",reason:"vensterfocus verloren")}
 private func handleXKeys(source:String,key:Int,binding:XKeysBinding,down:Bool){
  if binding.action == .ptt {handlePTTInput(source:source,pressed:down,mode:binding.mode.keyMode,reason:"X-keys toets \(key+1)");return}
  guard down else{return}
  switch binding.action {
  case .stopTX:emergencyStopTransmit(reason:"X-keys PTT OFF")
  case .connect:if !active && !switchingMode {connect()}
  case .disconnect:disconnect()
  case .volumeUp:volume=min(1,volume+0.05)
  case .volumeDown:volume=max(0,volume-0.05)
  case .audioMute:receiveMuted.toggle()
  case .agc:receiveAGCEnabled.toggle()
  case .eqBypass:receiveEQBypassed.toggle()
  default:if let i=binding.action.presetIndex {activatePreset(at:i)}
  }
 }
 func emergencyStopTransmit(reason:String="PTT OFF"){
  stopTransmit(reason:reason);transmitter.cancel()
 }
 func startXKeys(){xkeys.start()}
 func stopXKeys(){xkeys.stop()}
 func note(_ s:String){
  let time=logClock.string(from:Date())
  let message=String(s.prefix(512)).replacingOccurrences(of:"\n",with:" ")
  let lines=(log+"\(time)  \(message)\n").split(separator:"\n")
  log=lines.suffix(100).joined(separator:"\n")+"\n"
 }
 func refreshInputDevices(){inputDevices=AudioInputDevices.list()}
 func selectReflector(_ reflector:YSFHost){
  guard !active else{return}
  host=reflector.host;port=String(reflector.port)
  UserDefaults.standard.set(host,forKey:"host");UserDefaults.standard.set(port,forKey:"port")
 }
 func setQuickPreset(_ preset:QuickPreset?,at index:Int){
  guard (0..<8).contains(index),preset?.valid != false,preset==nil || preset?.mode==selectedMode else{return}
  if selectedMode == .fusion {fusionPresets[index]=preset;QuickPreset.save(fusionPresets,mode:.fusion)}
  else if selectedMode == .dmr {dmrPresets[index]=preset;QuickPreset.save(dmrPresets,mode:.dmr)}
  else {nxdnPresets[index]=preset;QuickPreset.save(nxdnPresets,mode:.nxdn)}
 }
 func saveCurrentPreset(at index:Int,title:String?=nil){
  let preset:QuickPreset
  if selectedMode == .fusion {
   guard let port=UInt16(port) else{note("Voorkeuze niet bewaard: ongeldige reflectorpoort.");return}
   preset = .fusion(title:String((title ?? host).prefix(40)),host:host.trimmingCharacters(in:.whitespacesAndNewlines),port:port)
  }else if selectedMode == .nxdn {
   guard let port=UInt16(nxdn.port),let target=UInt16(nxdn.destination),(0...63).contains(nxdn.ran) else{note("Voorkeuze niet bewaard: ongeldige NXDN-instellingen.");return}
   preset = .nxdn(title:String((title ?? "TG \(target)").prefix(40)),host:nxdn.host,port:port,destination:target,ran:UInt8(nxdn.ran))
  }else {
   guard let target=UInt32(dmr.destination) else{note("Voorkeuze niet bewaard: ongeldige DMR-bestemming.");return}
   preset = .dmr(title:title ?? (dmr.privateCall ? "Privé \(target)":"TG \(target)"),destination:target,privateCall:dmr.privateCall)
  }
  guard preset.valid else{note("Vul eerst een geldige reflector of bestemming in.");return}
  setQuickPreset(preset,at:index)
 }
 func presetIsSelected(_ preset:QuickPreset)->Bool {
  switch preset {
  case .fusion(_,let name,let p):return selectedMode == .fusion && name.caseInsensitiveCompare(host) == .orderedSame && UInt16(port)==p
  case .dmr(_,let target,let isPrivate):return selectedMode == .dmr && UInt32(dmr.destination)==target && dmr.privateCall==isPrivate
  case .nxdn(_,let name,let port,let target,let ran):return selectedMode == .nxdn && nxdn.host.caseInsensitiveCompare(name) == .orderedSame && UInt16(nxdn.port)==port && UInt16(nxdn.destination)==target && nxdn.ran==Int(ran)
  }
 }
 func activatePreset(at index:Int){
  guard canChoosePreset,(0..<8).contains(index),let preset=quickPresets[index],preset.valid else{return}
  switch preset {
  case .nxdn(_,let name,let port,let target,let ran):
   guard !presetIsSelected(preset) else{return}
   selectNXDNReflector(NXDNHost(number:target,host:name,port:port),ran:Int(ran))
  case .dmr(_,let target,let isPrivate):
   dmr.destination=String(target);dmr.privateCall=isPrivate;dmr.save()
   note("Voorkeuze: \(preset.title) · \(preset.detail). Bestemming voor de volgende PTT.")
  case .fusion(_,let name,let p):
   let entry=YSFHost(number:"",name:preset.title,description:"Voorkeuze",host:name,port:p)
   if !active {selectReflector(entry);return}
   guard ambeReady,!closing,!presetIsSelected(preset) else{return}
   switchingReflector=true;readyToTransmit=false;syncPTTKey()
   let token=UUID();reflectorSwitchToken=token
   ysf.send(Packets.poll(call,disconnect:true)){[weak self] in DispatchQueue.main.async {
    guard let self,self.active,!self.closing,self.reflectorSwitchToken==token else{return}
    self.ysf.close();self.host=name;self.port=String(p)
    UserDefaults.standard.set(name,forKey:"host");UserDefaults.standard.set(String(p),forKey:"port")
    self.transmitter.reset();self.transmitter.configure(.fusion);self.transmitter.setEnabled(true);self.audio.resetPlayback()
    self.lastYSF=nil;self.lastIncoming=nil;self.lastPCM=nil;self.lastSequence=nil;self.streamSource=""
    self.networkFrames=0;self.voiceFrames=0;self.pcmFrames=0;self.receivingAudio=false;self.receptionDetail="";self.rxDiscarded=0;self.level=0
    self.station="Wachten op ontvangst";self.gateway="—";self.began=Date();self.lastPoll = .distantPast
    self.ysfStatus="Wisselen naar \(preset.title)…";self.switchingReflector=false
    self.note("Reflectorvoorkeuze: \(preset.title) · \(preset.detail).")
    self.ysf.open(host:name,port:p)
   }}
  }
 }
 func selectNXDNReflector(_ entry:NXDNHost,ran:Int?=nil){
  guard canChoosePreset,selectedMode == .nxdn,!active || canSwitchMode else{return}
  var next=nxdn;next.host=entry.host;next.port=String(entry.port);next.destination=String(entry.number)
  if let ran {next.ran=ran}
  // The old connectionProfile is retained until unlink completes, so NXDNU
  // always addresses the old reflector even though the new settings are saved.
  if active,next.validated()==nil {connectionError="Vul een geldig NXDN-ID in SETUP in.";return}
  nxdn=next
  if active {requestMode(.nxdn,reconnect:true)}
 }
 // User-facing mode change. The low-level selectMode remains an idle-only
 // operation, so protocol state never changes underneath an open connection.
 func requestMode(_ target:DigitalMode,reconnect:Bool=false){
  guard target != selectedMode || reconnect else{return}
  guard canSwitchMode else{return}
  if !active {
   if microphoneTesting {stopMicrophoneTest()}
   selectMode(target);return
  }
  if let message=connectionValidation(for:target){
   connectionError=message;note(message);return
  }
  connectionError="";modeSwitchTarget=target;modeSwitchExclusive=exclusive
  note("Modewissel naar \(target.title) · huidige verbinding afronden en automatisch opnieuw verbinden.")
  beginDisconnect()
 }
 func selectMode(_ mode:DigitalMode){
  guard !active else{return};selectedMode=mode;connectionError=""
  dmrCallsignTask?.cancel();dmrStationSource=nil
  nxdnCallsignTask?.cancel();nxdnStationSource=nil
  self.mode=mode.voiceTitle
  station="Wachten op ontvangst";gateway="—"
 }
 func selectVocoder(_ backend:VocoderBackend){
  guard !active else{return}
  selectedVocoder=backend;UserDefaults.standard.set(backend.rawValue,forKey:"vocoderBackend");connectionError=""
 }
 func restoreDMRPasswordIfNeeded(){
  guard !initialPasswordRestoreStarted else{return};initialPasswordRestoreStarted=true
  if rememberDMRPassword,dmrPassword.isEmpty {loadDMRPassword(automatic:true)}
 }
 func loadDMRPassword(automatic:Bool=false){
  guard !active,!loadingDMRPassword else{return}
  loadingDMRPassword=true
  let id=dmr.radioID,entered=dmrPassword,store=passwordStore
  passwordQueue.async{[weak self] in
   let saved=store.read(for:id,allowInteraction:!automatic)
   DispatchQueue.main.async{[weak self] in
    guard let self else{return};self.loadingDMRPassword=false
    guard !self.active,self.dmr.radioID==id,self.dmrPassword==entered,!automatic || self.rememberDMRPassword else{return}
    guard let saved,!saved.isEmpty else {
     self.note("Geen bewaard BrandMeister-wachtwoord beschikbaar. Een eventueel al ingevuld wachtwoord blijft staan.");return
    }
    self.dmrPassword=saved
   }
  }
 }
 private func configureMicrophone(){
  if let input=microphone as? MicrophoneInput {
   input.deviceUID=selectedInputUID;input.channel=inputChannel;input.deliveryQueue=ioQueue;let token=microphoneToken
   input.onInfo={[weak self] message in guard let self,self.microphoneToken==token else{return};self.note(message)}
  }
  let device=inputDevices.first(where:{$0.id==selectedInputUID})
  note("Microfooningang: \(device?.name ?? "macOS-standaard") · kanaal \(inputChannel+1).")
 }
 private func startTransmitMicrophone() throws {
  let token=microphoneToken
  configureMicrophone()
  transmitter.prepareCapture(token:token,gain:microphoneGainDB,forTX:true)
  try microphone.start(onSamples:{[weak self] samples in
   self?.transmitter.appendMicrophone(samples,token:token)
  },onError:{[weak self] error in
   guard let self,self.microphoneToken==token else{return};self.recoverTransmit("Microfoon: \(error)")
  })
 }
 private func watchMicrophoneStartup(token:UUID){
  microphoneStartupTimer?.invalidate()
  microphoneStartupTimer=Timer.scheduledTimer(withTimeInterval:1,repeats:false){[weak self] _ in
   guard let self,self.microphoneToken==token,self.transmitting,!self.drainingTransmit,!self.microphoneHasAudio else{return}
   self.microphoneStartupTimer=nil
   self.note("Microfoon start zonder audio; ingang één keer opnieuw starten.")
   self.microphone.stop();self.microphoneToken=UUID()
   do {try self.startTransmitMicrophone()}
   catch {self.recoverTransmit("Microfoon opnieuw starten mislukt: \(error.localizedDescription)")}
   // No second retry: the transmitter's original two-second startup deadline
   // still stops an empty stream. The selected TX deadline is never reset.
  }
 }
 func toggleTransmit(){
  if transmitting || preparingTransmit {stopTransmit();return}
  handlePTTInput(source:"command",pressed:true,mode:.toggle)
  handlePTTInput(source:"command",pressed:false,mode:.toggle)
 }
 private func beginTransmit(){
  guard canTransmit else{note("PTT nog niet beschikbaar: verbind met vocoder en netwerk en wacht tot het kanaal vrij is.");return}
  if selectedMode == .dmr {
   guard let settings=dmr.validated() else{note("Vul een geldige DMR-bestemming in (1–16777215).");return}
   connectionProfile = .dmr(settings);transmitter.configure(connectionProfile)
  }
  activeTransmitLimit=transmitLimit
  preparingTransmit=true;microphoneToken=UUID();let token=microphoneToken
  microphone.requestAccess{[weak self] granted in
   guard let self,self.microphoneToken==token,self.preparingTransmit else{return}
   self.preparingTransmit=false
   guard granted else{self.pttRequests.transmissionEnded();self.note("Geen microfoontoegang. Sta FusionLab toe via Systeeminstellingen → Privacy en beveiliging → Microfoon.");return}
   guard self.canTransmit else{self.pttRequests.transmissionEnded();self.note("PTT geannuleerd: verbinding of kanaal niet meer beschikbaar.");return}
   do {
    self.microphoneHasAudio=false
    try self.startTransmitMicrophone()
    self.audio.resetPlayback();self.transmitting=true;self.pttSecondsRemaining=self.activeTransmitLimit.rawValue
    if case .dmr(let settings)=self.connectionProfile {
     self.mode="DMR · \(settings.privateCall ? "Privé":"TG") \(settings.destination) · TS\(settings.slot)";self.dmr.save()
    }else{self.mode=self.selectedMode.voiceTitle}
    self.microphoneFrames=0;self.encodedFrames=0;self.transmittedFrames=0
    self.note("PTT AAN · \(self.call) · \(self.mode). Automatische stop na maximaal \(self.activeTransmitLimit.rawValue) s.")
    self.transmitter.start(call:self.call,limit:self.activeTransmitLimit)
    self.watchMicrophoneStartup(token:token)
   }catch{self.pttRequests.transmissionEnded();self.microphone.stop();self.note("Microfoon starten mislukt: \(error.localizedDescription)")}
  }
 }
 func stopTransmit(reason:String="bediening"){
  pttRequests.transmissionEnded()
  microphoneStartupTimer?.invalidate();microphoneStartupTimer=nil
  if preparingTransmit {preparingTransmit=false;microphoneToken=UUID();note("PTT geannuleerd.")}
  guard transmitting,!drainingTransmit else{return}
  microphone.stop();microphoneToken=UUID();resetMicrophoneMeter()
  drainingTransmit=true;transmitter.stop();note("PTT UIT · \(reason) · laatste audio afronden…")
 }
 func toggleMicrophoneTest(){
  if microphoneTesting {stopMicrophoneTest();return}
  guard !transmitting,!preparingTransmit else{return}
  microphoneTesting=true;microphoneTestFrames=0;microphoneToken=UUID();let token=microphoneToken
  microphone.requestAccess{[weak self] granted in
   guard let self,self.microphoneToken==token,self.microphoneTesting else{return}
   guard granted else{self.stopMicrophoneTest();self.note("Microfoontoegang ontbreekt. Sta FusionLab toe in de privacy-instellingen van macOS.");return}
   do{
    self.configureMicrophone()
    self.transmitter.prepareCapture(token:token,gain:self.microphoneGainDB,forTX:false)
    try self.microphone.start(onSamples:{[weak self] samples in
     self?.transmitter.appendMicrophone(samples,token:token)
    },onError:{[weak self] error in
     guard let self,self.microphoneToken==token else{return};self.stopMicrophoneTest();self.note("Microfoon: \(error)")
    })
    self.note("Microfoontest: alleen de niveaumeter, er wordt niet uitgezonden.")
   }catch{self.stopMicrophoneTest();self.note(error.localizedDescription)}
  }
 }
 private func stopMicrophoneTest(){transmitter.endCapture();microphone.stop();microphoneToken=UUID();microphoneTesting=false;resetMicrophoneMeter()}
 private func resetMicrophoneMeter(){microphoneLevel=0;microphonePeak=0;microphoneClipping=false}

 private func connectionValidation(for target:DigitalMode)->String? {
  let clean=call.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
  let endpoint=networkEndpoint(for:target),networkHost=endpoint.host,networkPort=endpoint.port
  let vocoderPort=selectedVocoder == .md380 ? UInt16(2460):UInt16(ambePort)
  guard clean.count>=3,clean.count<=10,clean.utf8.allSatisfy({(65...90).contains($0)||(48...57).contains($0)||$0==47}),
   !networkHost.trimmingCharacters(in:.whitespaces).isEmpty,
   selectedVocoder == .md380 || !ambeHost.trimmingCharacters(in:.whitespaces).isEmpty,
   let p=UInt16(networkPort),p>0,let a=vocoderPort,a>0 else{return "Vul een geldige call, hosts en poorten (1–65535) in."}
  guard selectedVocoder == .md380 || exclusive else{return "Koppel MacDV/andere AMBE-clients eerst los en bevestig dit."}
  if target == .dmr,dmr.validated()==nil || clean.count>8 || dmrPassword.isEmpty {
   return "Vul je 7-cijferige DMR-ID, master, Hotspot Security-wachtwoord en geldige bestemming in. Call maximaal 8 tekens; SSID leeg of 00–99. Ontkoppel om deze instellingen eenmalig in SETUP in te vullen."
  }
  if target == .nxdn,nxdn.validated()==nil {return "Vul je NXDN-ID (1–65519), reflector, TG, poort en RAN (0–63) in SETUP in."}
  return nil
 }
 func connect(){
  guard !active else{return}
  connectionError=""
  if let message=connectionValidation(for:selectedMode){connectionError=message;note(message);return}
  let clean=call.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
  let networkPort=networkEndpoint(for:selectedMode).port
  let p=UInt16(networkPort)!,a=selectedVocoder == .md380 ? UInt16(2460):UInt16(ambePort)!
  if selectedMode == .dmr {
   guard let settings=dmr.validated(),clean.count<=8,!dmrPassword.isEmpty else {
    note("Vul je 7-cijferige DMR-ID, master, Hotspot Security-wachtwoord en geldige bestemming in. Call maximaal 8 tekens; SSID leeg of 00–99.");return
   }
   connectionProfile = .dmr(settings);dmr.save()
   UserDefaults.standard.set(rememberDMRPassword,forKey:"rememberDMRPassword")
   if loadingDMRPassword {
    note("Sleutelhanger wacht nog; het ingevulde wachtwoord wordt alleen voor deze verbinding gebruikt.")
   }else if rememberDMRPassword {
    if !passwordStore.save(dmrPassword,for:dmr.radioID){note("Wachtwoord kon niet in de Sleutelhanger worden bewaard; het blijft alleen voor deze sessie beschikbaar.")}
   }else{passwordStore.remove(for:dmr.radioID)}
  }else if selectedMode == .nxdn {connectionProfile = .nxdn(nxdn.validated()!);nxdn.save()}else{connectionProfile = .fusion}
  if microphoneTesting {stopMicrophoneTest()}
  call=clean
  for (k,v) in [("call",call),("host",host),("port",port),("ambeHost",ambeHost),("ambePort",ambePort)] {UserDefaults.standard.set(v,forKey:k)}
  do{try audio.start()}catch{connectionError="Audio starten mislukt: \(error.localizedDescription)";note(connectionError);return}
  transmitter.reset()
  transmitter.configure(connectionProfile);brandMeister.reset();dmrLoggedIn=false;dmrReceiveStream=nil
  UserDefaults.standard.set(selectedMode.rawValue,forKey:"digitalMode")
  active=true;closing=false;disconnectToken=UUID();ambeReady=false;ysfStarted=false;readyToTransmit=false;lastIncoming=nil;lastYSF=nil;lastPCM=nil;lastSequence=nil;streamSource=""
  networkFrames=0;voiceFrames=0;pcmFrames=0;errors=0;dropped=0;began=Date();lastPoll = .distantPast
  receivingAudio=false;receptionDetail="";rxDiscarded=0
  ambeStatus="Wachten op server…";ysfStatus="Wacht op AMBE-profiel"
  mode=selectedMode.voiceTitle
  let vocoderAddress=selectedVocoder == .md380 ? "MD380 lokaal":"AMBE \(ambeHost):\(a)"
  note("\(selectedMode.shortTitle)-test gestart. \(vocoderAddress), \(networkEndpoint(for:selectedMode).host):\(p).")
  note("Vocoderkeuze: \(selectedVocoder.title).")
  handshakeDeadline=Date().addingTimeInterval(6)
  ambe.open(host:ambeHost.trimmingCharacters(in:.whitespacesAndNewlines),port:a,backend:selectedVocoder)
  let timer=Timer(timeInterval:0.1,repeats:true){[weak self] _ in self?.tick()}
  RunLoop.main.add(timer,forMode:.common);self.timer=timer
 }
 private func command(_ d:Data,expect:UInt8){expected=expect;handshakeDeadline=Date().addingTimeInterval(5);ambe.send(d)}
 private func receiveAMBE(_ d:Data){
  guard active,!closing else{return}
  guard let p=Packets.dv3k(d) else{errors += 1;note("Ongeldig DV3K-pakket (\(d.count) bytes).");return}
  if p.type==0 {
   let b=[UInt8](p.body), field=b[0]
   guard field==expected else{return}
   if field==0x0a || field==0x15 {
    guard b.count>=2,b[1]==0 else{fail("AMBE weigert instelling 0x\(String(field,radix:16)): \(b.map{String(format:"%02X",$0)}.joined(separator:" "))");return}
   }
   switch field {
   case 0x39: note("AMBE READY ontvangen.");command(Packets.control(0x30),expect:0x30)
   case 0x30:
    note("Vocoder: \(String(decoding:b.dropFirst().prefix(32).prefix(while:{$0 != 0}),as:UTF8.self))")
    command(connectionProfile.rate,expect:0x0a)
   case 0x0a:note("\(selectedMode.shortTitle)-profiel bevestigd (\(connectionProfile.bits) bits).");command(Data([0x61,0,3,0,0x15,0,1]),expect:0x15)
   case 0x15:
    expected=nil;ambeReady=true;transmitter.setEnabled(selectedMode != .dmr || dmrLoggedIn);ambeStatus=selectedVocoder == .md380 ? "Gereed · MD380 lokaal":selectedMode == .dmr ? "Gereed · DMR 2450/1150":"Gereed · \(selectedMode.shortTitle) 2450"
    if !ysfStarted {
     ysfStarted=true;ysfStatus=selectedMode == .dmr ? "Aanmelden bij BrandMeister…":"Wachten op \(selectedMode.shortTitle)-antwoord…";began=Date()
     let endpoint=networkEndpoint(for:selectedMode)
     ysf.open(host:endpoint.host.trimmingCharacters(in:.whitespacesAndNewlines),port:UInt16(endpoint.port)!)
    }else{readyToTransmit=lastYSF != nil;note("AMBE hersteld; reflectorverbinding behouden.")}
   default:break
   }
  }
 }
 private func poll(){
  guard active,!closing else{return};lastPoll=Date()
  if case .dmr(let settings)=connectionProfile {brandMeister.start(peer:settings.peer,call:call,password:dmrPassword,colorCode:settings.colorCode)}
  else if case .nxdn(let settings)=connectionProfile {ysf.send(NXDNPackets.poll(call,destination:settings.destination))}
  else{ysf.send(Packets.poll(call))}
 }
 private func receiveNXDN(_ data:Data){
  guard active,!closing,case .nxdn(let settings)=connectionProfile else{return}
  let poll=NXDNPackets.isPollReply(data,call:call,destination:settings.destination)
  let frame=NXDNPackets.receive(data)
  guard poll || frame?.destination==settings.destination else{return}
  if lastYSF==nil {note("NXDN-reflector antwoordt · TG \(settings.destination).")}
  lastYSF=Date();readyToTransmit=true;modeSwitchTarget=nil;ysfStatus="Verbonden · NXDN"
  guard let frame else{return}
  networkFrames += 1;gateway="NXDN · TG \(frame.destination) · RAN \(frame.ran)"
  if !frame.frames.isEmpty {
   if nxdnStationSource != frame.source {note("NXDN-ontvangst ID \(frame.source) · TG \(frame.destination).");updateNXDNStation(frame.source)}
   lastIncoming=Date();mode="NXDN · TG \(frame.destination) · RAN \(frame.ran)"
   if !transmitting {voiceFrames += frame.frames.count}
  }
  if frame.kind==2 {note("Einde NXDN-uitzending \(frame.source).")}
 }
 func updateNXDNStation(_ source:UInt16){
  nxdnCallsignTask?.cancel();nxdnStationSource=source;station=String(source)
  if source==UInt16(nxdn.radioID) {station="\(call) · \(source)";return}
  let directory=nxdnCallsignDirectory
  nxdnCallsignTask=Task { @MainActor [weak self] in
   let call=await directory.callsign(for:UInt32(source))
   guard !Task.isCancelled,let self,self.active,!self.closing,self.selectedMode == .nxdn,self.nxdnStationSource==source,let call else{return}
   self.station="\(call) · \(source)"
  }
 }
 private func receiveDMR(_ data:Data){
  guard active,!closing,case .dmr(let settings)=connectionProfile else{return}
  guard dmrLoggedIn,let frame=DMRPackets.receive(data),frame.slot==settings.slot else{return}
  if frame.privateCall,frame.destination != settings.source,frame.destination != settings.peer{return}
  networkFrames += 1
  if frame.stream != dmrReceiveStream || frame.kind==0 {lastSequence=nil;dmrReceiveStream=frame.stream}
  if let previous=lastSequence {
   let delta=(Int(frame.sequence)-Int(previous)+256)%256
   if delta==0 || delta>128{return}
   if delta>1{dropped += delta-1}
  }
  lastSequence=frame.sequence
  gateway="BrandMeister · \(frame.peer)"
  if !frame.frames.isEmpty {
   let source=String(frame.source)
   if dmrStationSource != frame.source {note("DMR-ontvangst ID \(source) · \(frame.privateCall ? "privé":"TG") \(frame.destination) · TS\(frame.slot).");updateDMRStation(frame.source)}
   lastIncoming=Date();mode="DMR · \(frame.privateCall ? "Privé":"TG") \(frame.destination) · TS\(frame.slot)"
   if !transmitting {voiceFrames += frame.frames.count}
  }
  if frame.kind==2 {lastSequence=nil;dmrReceiveStream=nil;note("Einde DMR-uitzending \(frame.source).")}
 }
 func updateDMRStation(_ source:UInt32){
  dmrCallsignTask?.cancel();dmrStationSource=source;station=String(source)
  if source==9990 {station="Echo · 9990";return}
  if source==UInt32(dmr.radioID) {station="\(call) · \(source)";return}
  let directory=callsignDirectory
  dmrCallsignTask=Task { @MainActor [weak self] in
   let call=await directory.callsign(for:source)
   guard !Task.isCancelled,let self,self.active,self.selectedMode == .dmr,self.dmrStationSource==source,let call else{return}
   self.station="\(call) · \(source)"
  }
 }
 private func receiveYSF(_ d:Data){
  guard active,!closing,!switchingReflector else{return}
  if d.count==14,d.prefix(4)==Data("YSFP".utf8){
   if lastYSF==nil{note("YSF-reflector antwoordt op poll.")};lastYSF=Date();readyToTransmit=true;modeSwitchTarget=nil;ysfStatus="Verbonden · YSF";return
  }
  guard d.prefix(4)==Data("YSFD".utf8) else{return}
  do {
   let r=try Packets.receive(d);lastYSF=Date();readyToTransmit=true;modeSwitchTarget=nil;ysfStatus="Verbonden · YSF";networkFrames += 1
   gateway=r.gateway
   if r.fi==0 || r.source != streamSource {lastSequence=nil;streamSource=r.source}
   if let prev=lastSequence {
    let delta=(Int(r.sequence)-Int(prev)+128)%128
    if delta==0{return}
    if delta>64 {return} // stale/reordered datagram
    if delta>1{dropped += delta-1}
   }
   lastSequence=r.sequence
   if !r.frames.isEmpty {
    if station != r.source {note("Ontvangst \(r.source) via \(r.gateway).")};station=r.source
    // Apply the same 400 ms receive hang time to an echo of our own call.
    // Otherwise small gaps between echo packets can flash the PTT enabled.
    lastIncoming=Date()
    guard !transmitting else{return}
    mode="Fusion DN · V/D2";voiceFrames += r.frames.count
   } else if r.mode != 2 {mode="Niet ondersteunde YSF-mode \(r.mode)"}
   if r.end || r.fi==2 {lastSequence=nil;streamSource="";note("Einde uitzending \(r.source).")}
  }catch{errors += 1;if errors<=5 || errors%50==0 {note(error.localizedDescription)}}
 }
 private func tick(){
  guard active,!closing else{return}
  let now=Date()
  if !ambeReady,now>handshakeDeadline {
   if !ysfStarted {fail("AMBE-initialisatie: geen geldig antwoord binnen 5 seconden.");return}
   note("AMBE-herstel mislukt; reflector blijft verbonden. Ontkoppel en verbind opnieuw om AMBE te herinitialiseren.")
   ambeStatus="AMBE niet gereed";transmitter.setEnabled(false);readyToTransmit=false;expected=nil;handshakeDeadline = .distantFuture;ambe.close()
  }
  if ysfStarted {
   if selectedMode == .fusion {
    if now.timeIntervalSince(lastPoll)>=5{poll()}
    if now.timeIntervalSince(lastYSF ?? began)>16{fail("YSF: geen antwoord of keepalive binnen 16 seconden. Controleer host, poort en netwerk.");return}
   }else if selectedMode == .nxdn {
    if now.timeIntervalSince(lastPoll)>=1{poll()}
    if now.timeIntervalSince(lastYSF ?? began)>10{fail("NXDN: geen antwoord of keepalive binnen 10 seconden. Controleer reflector, TG en netwerk.");return}
   }
  }
  if now.timeIntervalSince(lastPCM ?? .distantPast)>0.4 && level != 0{level=0}
  syncPTTKey()
 }
 private func recoverTransmit(_ message:String){
  guard active,!closing else{return}
  microphoneStartupTimer?.invalidate();microphoneStartupTimer=nil
  pttRequests.transmissionEnded();transmitter.cancel();microphone.stop();microphoneToken=UUID();preparingTransmit=false
  errors += 1;note(message+" Reflector blijft verbonden; AMBE wordt hersteld.")
  audio.resetPlayback();ambeReady=false;transmitter.setEnabled(false);readyToTransmit=false
  ambeStatus="AMBE herstellen…";command(Packets.control(0x33),expect:0x39)
 }
 func disconnect(){
  // Explicit disconnect (including shutdown/failure) cancels any queued switch.
  modeSwitchTarget=nil;modeSwitchExclusive=nil
  beginDisconnect()
 }
 private func beginDisconnect(){
  reflectorSwitchToken=UUID();switchingReflector=false
  microphoneStartupTimer?.invalidate();microphoneStartupTimer=nil
  if preparingTransmit {stopTransmit()}
  if microphoneTesting {stopMicrophoneTest()}
  guard active,!closing else{return}
  let token=UUID();disconnectToken=token
  transmitter.cancel();transmitter.setEnabled(false);closing=true;readyToTransmit=false;pttKey.setActive(false);pttRequests.transmissionEnded()
  if ysfStarted {
   if selectedMode == .dmr {brandMeister.disconnect()}
   else {
    let unlink:Data
    if case .nxdn(let settings)=connectionProfile {unlink=NXDNPackets.poll(call,destination:settings.destination,disconnect:true)}else{unlink=Packets.poll(call,disconnect:true)}
    ysf.send(unlink){[weak self] in DispatchQueue.main.async{self?.finish(disconnect:token)}}
   }
   DispatchQueue.main.asyncAfter(deadline:.now()+0.2){[weak self] in self?.finish(disconnect:token)}
  }
  else{finish(disconnect:token)}
 }
 private func finish(disconnect token:UUID){
  // A send completion and the 200-ms fallback may both fire. An old callback
  // must never close a newly opened mode/connection.
  guard active,closing,disconnectToken==token else{return}
  dmrLoggedIn=false
  dmrCallsignTask?.cancel();dmrStationSource=nil
  nxdnCallsignTask?.cancel();nxdnStationSource=nil
  timer?.invalidate();timer=nil;ysf.close();ambe.close();audio.stop();brandMeister.reset();active=false;closing=false;exclusive=false;ambeReady=false;ysfStarted=false;expected=nil
  ysfStatus="Losgekoppeld";ambeStatus="Losgekoppeld";level=0;readyToTransmit=false;note("Verbinding gestopt.")
  if let target=modeSwitchTarget,let confirmation=modeSwitchExclusive {
   modeSwitchExclusive=nil
   selectMode(target);exclusive=confirmation;connect()
   if !active {modeSwitchTarget=nil}
  }
 }
 private func fail(_ s:String){connectionError=s;note(s);disconnect()}
 deinit{microphone.stop();timer?.invalidate();ysf.close();ambe.close();pttKey.setActive(false);for (center,observer) in activityObservers {center.removeObserver(observer)}}
}
