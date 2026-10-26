import Foundation
import Combine
import AppKit

final class RadioSession: ObservableObject {
 @Published private(set) var selectedMode:DigitalMode = .fusion
 @Published var dmr=DMRConfiguration.load()
 @Published var dmrPassword=""
 @Published var rememberDMRPassword=UserDefaults.standard.bool(forKey:"rememberDMRPassword")
 private var connectionProfile:VoiceProfile = .fusion
 private let brandMeister=BrandMeisterHandshake()
 private let passwordStore:DMRPasswordStorage
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
 @Published var transmitting=false
 @Published var preparingTransmit=false
 @Published var drainingTransmit=false
 @Published var microphoneTesting=false
 @Published var readyToTransmit=false
 @Published var connectionError=""
 @Published var pttKeyMode=PTTKeyMode(rawValue:UserDefaults.standard.string(forKey:"pttKeyMode") ?? "hold") ?? .hold {
  didSet{
   guard pttKeyMode != oldValue else{return}
   stopTransmit();pttState.reset();pttKey.setActive(false)
   UserDefaults.standard.set(pttKeyMode.rawValue,forKey:"pttKeyMode");syncPTTKey()
  }
 }
 @Published var pttKeyStatus="Numerieke 0 wordt actief zodra de verbinding zendklaar is."
 @Published var pttSecondsRemaining=180
 @Published var pttButtonToggle=UserDefaults.standard.bool(forKey:"pttButtonToggle") {
  didSet{
   guard pttButtonToggle != oldValue else{return}
   stopTransmit();buttonState.reset();pttState.reset();pttKey.setActive(false)
   UserDefaults.standard.set(pttButtonToggle,forKey:"pttButtonToggle")
   syncPTTKey()
  }
 }
 private var buttonState=PTTKeyState()
 private var effectivePTTKeyMode:PTTKeyMode {pttKeyMode == .off ? .off:pttButtonToggle ? .toggle:.hold}
 private let pttKey:PTTKeyRegistration
 private var pttState=PTTKeyState()
 private var sleepObserver:NSObjectProtocol?
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
 var canTransmit:Bool {active && ambeReady && readyToTransmit && !closing && !preparingTransmit && !transmitting && !microphoneTesting && !receivingAudio && Date().timeIntervalSince(lastIncoming ?? .distantPast)>0.4}
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
 private let ambe:UDPLink
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
 init(microphone:MicrophoneSource=MicrophoneInput(),pttKey:PTTKeyRegistration=GlobalPTTKey(),passwordStore:DMRPasswordStorage=DMRPasswordStore(),callsignDirectory:DMRCallsignLookup=DMRCallsignDirectory()){
  self.microphone=microphone
  self.pttKey=pttKey
  self.passwordStore=passwordStore
  self.callsignDirectory=callsignDirectory
  self.ysf=UDPLink(queue:ioQueue);self.ambe=UDPLink(queue:ioQueue);self.audio=AudioOutput(queue:ioQueue)
  self.transmitter=TransmissionLoop(queue:ioQueue)
  self.selectedInputUID=UserDefaults.standard.string(forKey:"inputUID") ?? AudioInputDevices.list().first(where:{$0.name.localizedCaseInsensitiveContains("PUC2")})?.id ?? ""
  self.audio.setAGCEnabled(receiveAGCEnabled)
  self.applyReceiveEQ()
  selectedMode=DigitalMode(rawValue:UserDefaults.standard.string(forKey:"digitalMode") ?? "fusion") ?? .fusion
  if rememberDMRPassword {dmrPassword=passwordStore.read(for:dmr.radioID) ?? ""}
  mode=selectedMode == .fusion ? "Fusion DN · V/D2":"DMR · BrandMeister"
  brandMeister.onSend={[weak self] in self?.ysf.send($0)}
  brandMeister.onProgress={[weak self] in self?.ysfStatus=$0;self?.note($0)}
  brandMeister.onReady={[weak self] in
   guard let self,self.active,!self.closing else{return}
   self.lastYSF=Date();self.readyToTransmit=true;self.transmitter.setEnabled(true)
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
   self.pttState.transmissionEnded();self.pttSecondsRemaining=0
   self.buttonState.transmissionEnded()
   if snapshot.timedOut {self.note("Time-out: PTT automatisch gestopt na 180 seconden.")}
   self.syncPTTKey()
   self.microphoneFrames=snapshot.inputCount;self.encodedFrames=snapshot.encodedCount;self.transmittedFrames=snapshot.networkCount
   self.pttSecondsRemaining=snapshot.remainingSeconds
   self.note("PTT gestopt · \(self.encodedFrames) AMBE-blokken, \(self.transmittedFrames) YSF-pakketten · bufferpiek \(snapshot.inputHighWaterMark) · overgeslagen \(snapshot.droppedInputCount).")
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
   self.pcmFrames=count;self.lastPCM=date;self.level=rms;self.ambeStatus=self.selectedMode == .fusion ? "Gereed · Fusion DN 2450":"Gereed · DMR 2450/1150"
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
   self?.transmitter.receiveNetworkAudio(data)
   DispatchQueue.main.async{guard let self else{return};if self.selectedMode == .dmr {self.receiveDMR(data)}else{self.receiveYSF(data)}}
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
  sleepObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main){[weak self] _ in
   self?.stopTransmit();self?.transmitter.cancel();self?.pttKey.setActive(false);self?.pttState.reset()
  }
 }
 private func syncPTTKey(){
  let engaged=transmitting || preparingTransmit
  let wanted=active && !closing && pttKeyMode != .off && (canTransmit || engaged || pttState.held)
  pttKey.setActive(wanted)
  if pttKeyMode == .off {pttKeyStatus="Numerieke 0 uit · gebruik de PTT-knop."}
  else if pttKey.failed {pttKeyStatus="Numerieke 0 bezet of niet beschikbaar · gebruik de PTT-knop."}
  else if pttKey.registered {pttKeyStatus="Numerieke 0 actief in alle programma’s · \(effectivePTTKeyMode.title.lowercased())."}
  else {pttKeyStatus="Numerieke 0 wordt actief zodra de verbinding zendklaar is."}
 }
 private func handlePTTKey(_ pressed:Bool){
  guard pttKey.registered else{return}
  switch pttState.event(pressed:pressed,mode:effectivePTTKeyMode,canStart:canTransmit,engaged:transmitting || preparingTransmit){
  case .start:toggleTransmit()
  case .stop:stopTransmit(reason:effectivePTTKeyMode == .toggle ? "numerieke 0 opnieuw ingedrukt":"numerieke 0 losgelaten")
  case .none:break
  }
  if !transmitting && !preparingTransmit {pttState.transmissionEnded()}
  syncPTTKey()
 }
 func setPTT(_ on:Bool){
  if on {if !transmitting && !preparingTransmit {toggleTransmit()}}
  else {stopTransmit()}
 }
 func handlePTTButton(pressed:Bool){
  switch buttonState.event(pressed:pressed,mode:pttButtonToggle ? .toggle:.hold,canStart:canTransmit,engaged:transmitting || preparingTransmit){
  case .start:toggleTransmit()
  case .stop:stopTransmit(reason:pttButtonToggle ? "PTT-knop opnieuw ingedrukt":"PTT-knop losgelaten")
  case .none:break
  }
  if !transmitting && !preparingTransmit {buttonState.transmissionEnded()}
 }
 func handleFocusLoss(){
  if !(pttKey.registered && pttState.ownsTransmission) {stopTransmit(reason:"vensterfocus verloren")}
 }
 func note(_ s:String){
  let time=DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.medium)
  let lines=(log+"\(time)  \(s)\n").split(separator:"\n",omittingEmptySubsequences:false)
  log=lines.suffix(250).joined(separator:"\n")
 }
 func refreshInputDevices(){inputDevices=AudioInputDevices.list()}
 func selectReflector(_ reflector:YSFHost){
  guard !active else{return}
  host=reflector.host;port=String(reflector.port)
  UserDefaults.standard.set(host,forKey:"host");UserDefaults.standard.set(port,forKey:"port")
 }
 func selectMode(_ mode:DigitalMode){
  guard !active else{return};selectedMode=mode;connectionError=""
  dmrCallsignTask?.cancel();dmrStationSource=nil
  self.mode=mode == .fusion ? "Fusion DN · V/D2":"DMR · BrandMeister"
  station="Wachten op ontvangst";gateway="—"
 }
 func loadDMRPassword(){
  guard let saved=passwordStore.read(for:dmr.radioID),!saved.isEmpty else {
   note("Geen bewaard BrandMeister-wachtwoord gevonden. Een eventueel al ingevuld wachtwoord blijft staan.");return
  }
  dmrPassword=saved
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
   // still stops an empty stream. The 180-second TX deadline is never reset.
  }
 }
 func toggleTransmit(){
  if transmitting || preparingTransmit {stopTransmit();return}
  guard canTransmit else{note("PTT nog niet beschikbaar: verbind met AMBE en YSF en wacht tot het kanaal vrij is.");return}
  if selectedMode == .dmr {
   guard let settings=dmr.validated() else{note("Vul een geldige DMR-bestemming in (1–16777215).");return}
   connectionProfile = .dmr(settings);transmitter.configure(connectionProfile)
  }
  preparingTransmit=true;microphoneToken=UUID();let token=microphoneToken
  microphone.requestAccess{[weak self] granted in
   guard let self,self.microphoneToken==token,self.preparingTransmit else{return}
   self.preparingTransmit=false
   guard granted else{self.note("Geen microfoontoegang. Sta FusionLab toe via Systeeminstellingen → Privacy en beveiliging → Microfoon.");return}
   guard self.canTransmit else{self.note("PTT geannuleerd: verbinding of kanaal niet meer beschikbaar.");return}
   do {
    self.microphoneHasAudio=false
    try self.startTransmitMicrophone()
    self.audio.resetPlayback();self.transmitting=true;self.pttSecondsRemaining=180
    if case .dmr(let settings)=self.connectionProfile {
     self.mode="DMR · \(settings.privateCall ? "Privé":"TG") \(settings.destination) · TS\(settings.slot)";self.dmr.save()
    }else{self.mode="Fusion DN · V/D2"}
    self.microphoneFrames=0;self.encodedFrames=0;self.transmittedFrames=0
    self.note("PTT AAN · \(self.call) · \(self.mode). Automatische stop na maximaal 180 s.")
    self.transmitter.start(call:self.call)
    self.watchMicrophoneStartup(token:token)
   }catch{self.microphone.stop();self.note("Microfoon starten mislukt: \(error.localizedDescription)")}
  }
 }
 func stopTransmit(reason:String="bediening"){
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

 func connect(){
  guard !active else{return}
  connectionError=""
  let clean=call.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
  let networkHost=selectedMode == .fusion ? host:dmr.host,networkPort=selectedMode == .fusion ? port:dmr.port
  guard clean.count>=3,clean.count<=10,clean.utf8.allSatisfy({(65...90).contains($0)||(48...57).contains($0)||$0==47}), !networkHost.trimmingCharacters(in:.whitespaces).isEmpty,!ambeHost.trimmingCharacters(in:.whitespaces).isEmpty,let p=UInt16(networkPort),p>0,let a=UInt16(ambePort),a>0 else{note("Vul een geldige call, hosts en poorten (1–65535) in.");return}
  guard exclusive else{note("Koppel MacDV/andere AMBE-clients eerst los en bevestig dit.");return}
  if selectedMode == .dmr {
   guard let settings=dmr.validated(),clean.count<=8,!dmrPassword.isEmpty else {
    note("Vul je 7-cijferige DMR-ID, master, Hotspot Security-wachtwoord en geldige bestemming in. Call maximaal 8 tekens; SSID leeg of 00–99.");return
   }
   connectionProfile = .dmr(settings);dmr.save()
   UserDefaults.standard.set(rememberDMRPassword,forKey:"rememberDMRPassword")
   if rememberDMRPassword {
    if !passwordStore.save(dmrPassword,for:dmr.radioID){note("Wachtwoord kon niet in de Sleutelhanger worden bewaard; het blijft alleen voor deze sessie beschikbaar.")}
   }else{passwordStore.remove(for:dmr.radioID)}
  }else{connectionProfile = .fusion}
  if microphoneTesting {stopMicrophoneTest()}
  call=clean
  for (k,v) in [("call",call),("host",host),("port",port),("ambeHost",ambeHost),("ambePort",ambePort)] {UserDefaults.standard.set(v,forKey:k)}
  do{try audio.start()}catch{note("Audio starten mislukt: \(error.localizedDescription)");return}
  transmitter.reset()
  transmitter.configure(connectionProfile);brandMeister.reset();dmrReceiveStream=nil
  UserDefaults.standard.set(selectedMode.rawValue,forKey:"digitalMode")
  active=true;closing=false;ambeReady=false;ysfStarted=false;readyToTransmit=false;lastIncoming=nil;lastYSF=nil;lastPCM=nil;lastSequence=nil;streamSource=""
  networkFrames=0;voiceFrames=0;pcmFrames=0;errors=0;dropped=0;began=Date();lastPoll = .distantPast
  receivingAudio=false;receptionDetail="";rxDiscarded=0
  ambeStatus="Wachten op server…";ysfStatus="Wacht op AMBE-profiel"
  mode=selectedMode == .fusion ? "Fusion DN · V/D2":"DMR · BrandMeister"
  note(selectedMode == .fusion ? "Fusion-test gestart. AMBE \(ambeHost):\(a), YSF \(host):\(p).":"DMR-test gestart. AMBE \(ambeHost):\(a), BrandMeister \(dmr.host):\(dmr.port).")
  handshakeDeadline=Date().addingTimeInterval(6)
  ambe.open(host:ambeHost.trimmingCharacters(in:.whitespacesAndNewlines),port:a)
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
   case 0x0a:note(selectedMode == .fusion ? "Fusion DN-profiel bevestigd (2450 bit/s, 49 bits).":"DMR-profiel bevestigd (2450/1150 bit/s, 72 bits).");command(Data([0x61,0,3,0,0x15,0,1]),expect:0x15)
   case 0x15:
    expected=nil;ambeReady=true;transmitter.setEnabled(selectedMode == .fusion || brandMeister.phase == .ready);ambeStatus=selectedMode == .fusion ? "Gereed · Fusion DN 2450":"Gereed · DMR 2450/1150"
    if !ysfStarted {
     ysfStarted=true;ysfStatus=selectedMode == .fusion ? "Wachten op YSF-antwoord…":"Aanmelden bij BrandMeister…";began=Date()
     ysf.open(host:(selectedMode == .fusion ? host:dmr.host).trimmingCharacters(in:.whitespacesAndNewlines),port:UInt16(selectedMode == .fusion ? port:dmr.port)!)
    }else{readyToTransmit=lastYSF != nil;note("AMBE hersteld; reflectorverbinding behouden.")}
   default:break
   }
  }
 }
 private func poll(){
  guard active,!closing else{return};lastPoll=Date()
  if case .dmr(let settings)=connectionProfile {brandMeister.start(peer:settings.peer,call:call,password:dmrPassword,colorCode:settings.colorCode)}
  else{ysf.send(Packets.poll(call))}
 }
 private func receiveDMR(_ data:Data){
  guard active,!closing,case .dmr(let settings)=connectionProfile else{return}
  brandMeister.receive(data)
  guard brandMeister.phase == .ready,let frame=DMRPackets.receive(data),frame.slot==settings.slot else{return}
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
  guard active,!closing else{return}
  if d.count==14,d.prefix(4)==Data("YSFP".utf8){
   if lastYSF==nil{note("YSF-reflector antwoordt op poll.")};lastYSF=Date();readyToTransmit=true;ysfStatus="Verbonden · YSF";return
  }
  guard d.prefix(4)==Data("YSFD".utf8) else{return}
  do {
   let r=try Packets.receive(d);lastYSF=Date();readyToTransmit=true;ysfStatus="Verbonden · YSF";networkFrames += 1
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
   if selectedMode == .dmr {brandMeister.tick(now:now)}
   else {
    if now.timeIntervalSince(lastPoll)>=5{poll()}
    if now.timeIntervalSince(lastYSF ?? began)>16{fail("YSF: geen antwoord of keepalive binnen 16 seconden. Controleer host, poort en netwerk.");return}
   }
  }
  if now.timeIntervalSince(lastPCM ?? .distantPast)>0.4 && level != 0{level=0}
  syncPTTKey()
 }
 private func recoverTransmit(_ message:String){
  guard active,!closing else{return}
  microphoneStartupTimer?.invalidate();microphoneStartupTimer=nil
  transmitter.cancel();microphone.stop();microphoneToken=UUID();preparingTransmit=false
  errors += 1;note(message+" Reflector blijft verbonden; AMBE wordt hersteld.")
  audio.resetPlayback();ambeReady=false;transmitter.setEnabled(false);readyToTransmit=false
  ambeStatus="AMBE herstellen…";command(Packets.control(0x33),expect:0x39)
 }
 func disconnect(){
  microphoneStartupTimer?.invalidate();microphoneStartupTimer=nil
  if preparingTransmit {stopTransmit()}
  if microphoneTesting {stopMicrophoneTest()}
  guard active,!closing else{return}
  transmitter.cancel();transmitter.setEnabled(false);closing=true;readyToTransmit=false;pttKey.setActive(false);pttState.reset()
  if ysfStarted {
   if selectedMode == .dmr {brandMeister.disconnect()}
   else {ysf.send(Packets.poll(call,disconnect:true)){[weak self] in DispatchQueue.main.async{self?.finish()}}}
   DispatchQueue.main.asyncAfter(deadline:.now()+0.2){[weak self] in self?.finish()}
  }
  else{finish()}
 }
 private func finish(){
  dmrCallsignTask?.cancel();dmrStationSource=nil
  guard active else{return};timer?.invalidate();timer=nil;ysf.close();ambe.close();audio.stop();brandMeister.reset();active=false;closing=false;exclusive=false;ambeReady=false;ysfStarted=false;expected=nil
  ysfStatus="Losgekoppeld";ambeStatus="Losgekoppeld";level=0;readyToTransmit=false;note("Verbinding gestopt.")
 }
 private func fail(_ s:String){connectionError=s;note(s);disconnect()}
 deinit{microphone.stop();timer?.invalidate();ysf.close();ambe.close();pttKey.setActive(false);if let sleepObserver {NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)}}
}
