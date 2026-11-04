import Foundation
import YSFCodec

final class MemoryDMRPasswordStore:DMRPasswordStorage {
 private let lock=NSLock()
 var values=[String:String]()
 func read(for id:String)->String? {lock.lock();defer{lock.unlock()};return values[id]}
 func save(_ password:String,for id:String)->Bool {lock.lock();defer{lock.unlock()};values[id]=password;return true}
 func remove(for id:String){lock.lock();defer{lock.unlock()};values.removeValue(forKey:id)}
}

extension ProtocolTests {
 func testDMRWireAndReferenceFrames() throws {
  var config=DMRConfiguration();XCTAssertNil(config.validated())
  config.radioID="2040001";config.ssid="01"
  let settings=config.validated()!
  XCTAssertEqual(settings.peer,204000101)
  config.ssid="100";XCTAssertNil(config.validated());config.ssid=""
  XCTAssertEqual(config.validated()?.peer,2040001)
  config.destination="16777216";XCTAssertNil(config.validated())
  XCTAssertEqual(VoiceProfile.dmr(settings).rate,Data([0x61,0,13,0,10,4,49,7,84,36,0,0,0,0,0,111,72]))
  let auth=DMRPackets.authentication(peer:settings.peer,salt:Data([1,2,3,4]),password:"test-secret")
  XCTAssertEqual(auth.count,40)
  XCTAssertEqual(auth.suffix(32).map{String(format:"%02x",$0)}.joined(),"ce60424c7e5ff854d3f8af299a6f287fe1a4980c81e2bf3d9f522396a981d12b")
  let registration=DMRPackets.configuration(peer:settings.peer,call:"PA3EKE")
  XCTAssertEqual(registration.count,302)
  XCTAssertEqual(registration.prefix(8),DMRPackets.control("RPTC",peer:settings.peer))
  // Check the external Homebrew field offsets, including padding, rather than
  // letting a successful mock handshake hide an incompatible registration.
  func textField(_ range:Range<Int>)->String {String(decoding:registration[range],as:UTF8.self)}
  XCTAssertEqual(textField(8..<16),"PA3EKE  ")
  XCTAssertEqual(textField(16..<25),"438800000")
  XCTAssertEqual(textField(25..<34),"438800000")
  XCTAssertEqual(textField(34..<38),"0001")
  XCTAssertEqual(textField(38..<58),"0.00000000.000000000")
  XCTAssertEqual(textField(58..<78),String(repeating:" ",count:20))
  XCTAssertEqual(textField(97..<98),"4")
  XCTAssertEqual(textField(222..<262),"20261025"+String(repeating:" ",count:32))
  XCTAssertEqual(textField(262..<302),"MMDVM_FusionLab"+String(repeating:" ",count:25))
  XCTAssertEqual(String(decoding:DMRPackets.configuration(peer:settings.peer,call:"PA3EKE",colorCode:15)[36..<38],as:UTF8.self),"15")
  let raw=(0..<27).map{UInt8(($0*37+11)&255)}
  let voice=stride(from:0,to:27,by:9).map{Data(raw[$0..<$0+9])}
  let url=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/DroidStarDMR.json")
  let golden=try JSONDecoder().decode([String:String].self,from:Data(contentsOf:url))
  for sequence in 0...9 {
   let kind:UInt8=sequence==0 ? 0:sequence==9 ? 2:1
   let key=sequence==0 ? "header":sequence==9 ? "end":"voice-\(sequence-1)"
   let packet=DMRPackets.transmit(settings:settings,sequence:sequence,stream:0x12345678,kind:kind,voice:voice)
   XCTAssertEqual(packet.map{String(format:"%02x",$0)}.joined(),golden[key]!,key)
   let frame=DMRPackets.receive(packet)!
   XCTAssertEqual(frame.source,settings.source);XCTAssertEqual(frame.destination,9990)
   XCTAssertEqual(frame.peer,settings.peer);XCTAssertEqual(frame.slot,2);XCTAssertEqual(frame.privateCall,true)
   XCTAssertEqual(frame.stream,0x12345678);XCTAssertEqual(frame.kind,kind)
   if kind==1 {XCTAssertEqual(frame.frames,voice)}
   else {
    var lc=[UInt8](repeating:0,count:12)
    XCTAssertEqual(dmr_decode_lc(Array(packet[20..<53]),kind,&lc),1)
    XCTAssertEqual(lc[0],3) // private-call LC opcode
   }
  }
  XCTAssertNil(DMRPackets.receive(Data(repeating:0,count:55)))
  XCTAssertNil(DMRPackets.receive(DMRPackets.transmit(settings:settings,sequence:0,stream:1,kind:0).dropLast()))
  var badLC=DMRPackets.transmit(settings:settings,sequence:0,stream:1,kind:0)
  badLC.replaceSubrange(20..<53,with:Data(repeating:0,count:33))
  XCTAssertNil(DMRPackets.receive(badLC))
  let reply=Data([0x61,0,14,1,1,72])+voice[0]+Data([2,0,2])
  XCTAssertEqual(Packets.encodedVoice(reply,bits:72),voice[0]);XCTAssertNil(Packets.encodedVoice(reply))
  XCTAssertEqual(Packets.ambe(voice[0],bits:72).prefix(6),Data([0x61,0,11,1,1,72]))
  let group=DMRVoiceSettings(source:settings.source,destination:204,peer:settings.peer,slot:1,colorCode:15,privateCall:false)
  let groupHeader=DMRPackets.transmit(settings:group,sequence:0,stream:1,kind:0)
  let received=DMRPackets.receive(groupHeader)!
  XCTAssertEqual(received.privateCall,false);XCTAssertEqual(received.slot,1);XCTAssertEqual(received.destination,204)
 }

 @MainActor func testDMRReceiveFilteringAndSequenceWrap() async throws {
  let settings=DMRVoiceSettings(source:2040001,destination:9990,peer:204000101,slot:2,colorCode:1,privateCall:true)
  let queue=DispatchQueue(label:"FusionLabTests.dmrRX")
  // Use a single queue to make all network and decode ordering deterministic.
  let audio=TransmissionLoop(queue:queue)
  var received=0
  audio.onAMBE={data in
   XCTAssertEqual(data[5],72);received += 1
   audio.receivePCM(Data([0x61,1,66,2,0,160])+Data(repeating:0,count:320))
  }
  audio.configure(.dmr(settings));audio.setEnabled(true)
  let voice=Array(repeating:Data(repeating:0x55,count:9),count:3)
  for (slot,destination) in [(UInt8(1),UInt32(2040001)),(UInt8(2),UInt32(2040002))] {
   let wrong=DMRVoiceSettings(source:9990,destination:destination,peer:settings.peer,slot:slot,colorCode:1,privateCall:true)
   audio.receiveNetworkAudio(DMRPackets.transmit(settings:wrong,sequence:1,stream:10,kind:1,voice:voice))
  }
  queue.sync{};XCTAssertEqual(queue.sync{received},0)
  let echo=DMRVoiceSettings(source:9990,destination:settings.source,peer:settings.peer,slot:2,colorCode:1,privateCall:true)
  for sequence in [255,0,0,254] {
   audio.receiveNetworkAudio(DMRPackets.transmit(settings:echo,sequence:sequence,stream:20,kind:1,voice:voice))
  }
  let deadline=Date().addingTimeInterval(2)
  while queue.sync(execute:{received})<6,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(queue.sync{received},6,"Wrong slot/private destination, duplicates and stale packets must be ignored; 255 → 0 is valid")
  audio.reset();queue.sync{}
 }

 func testBrandMeisterHandshakeAndTimeout(){
  let bm=BrandMeisterHandshake(),base=Date(timeIntervalSince1970:1000),peer:UInt32=204000101
  var sent=[Data](),errors=[String](),ready=0
  bm.onSend={sent.append($0)};bm.onError={errors.append($0)};bm.onReady={ready += 1}
  bm.start(peer:peer,call:"PA3EKE",password:"test-secret",now:base)
  XCTAssertEqual(sent.last,DMRPackets.control("RPTL",peer:peer))
  bm.receive(Data("RPTACK".utf8),now:base);XCTAssertEqual(bm.phase,.challenge)
  bm.receive(Data("RPTACK".utf8)+Data([1,2,3,4]),now:base)
  XCTAssertEqual(bm.phase,.authentication);XCTAssertEqual(sent.last?.count,40)
  bm.receive(Data("RPTACK".utf8)+DMRPackets.id(peer+1),now:base)
  XCTAssertEqual(bm.phase,.authentication)
  bm.receive(Data("RPTACK".utf8)+DMRPackets.id(peer),now:base)
  XCTAssertEqual(bm.phase,.configuration);XCTAssertEqual(sent.last?.count,302)
  bm.receive(Data("RPTACK".utf8)+DMRPackets.id(peer),now:base)
  XCTAssertEqual(ready,1);XCTAssertEqual(bm.phase,.ready)
  bm.tick(now:base.addingTimeInterval(5));XCTAssertEqual(sent.last,DMRPackets.control("RPTPING",peer:peer))
  bm.receive(Data("MSTPONG".utf8)+DMRPackets.id(peer),now:base.addingTimeInterval(5))
  bm.tick(now:base.addingTimeInterval(24));XCTAssertEqual(errors,[])
  bm.tick(now:base.addingTimeInterval(26));XCTAssertEqual(errors.count,1)
  bm.start(peer:peer,call:"PA3EKE",password:"test-secret",now:base)
  bm.receive(Data("MSTNAK".utf8),now:base);XCTAssertEqual(bm.phase,.failed)
  XCTAssertEqual(errors.last?.contains("vóór de wachtwoordcontrole"),true)
  bm.start(peer:peer,call:"PA3EKE",password:"test-secret",now:base)
  bm.receive(Data("RPTACK".utf8)+Data([1,2,3,4]),now:base)
  bm.receive(Data("MSTNAK".utf8),now:base)
  XCTAssertEqual(errors.last?.contains("weigert het hotspotwachtwoord"),true)
  bm.start(peer:peer,call:"PA3EKE",password:"test-secret",now:base)
  bm.receive(Data("RPTACK".utf8)+Data([1,2,3,4]),now:base)
  bm.receive(Data("RPTACK".utf8)+DMRPackets.id(peer),now:base)
  bm.receive(Data("MSTNAK".utf8),now:base)
  XCTAssertEqual(errors.last?.contains("wachtwoordcontrole was al geslaagd"),true)
  XCTAssertEqual(errors.joined().contains("test-secret"),false)
  bm.start(peer:peer,call:"PA3EKE",password:"test-secret",now:base)
  bm.tick(now:base.addingTimeInterval(9));XCTAssertEqual(bm.phase,.failed)
  bm.start(peer:peer,call:"PA3EKE",password:"test-secret",now:base);bm.disconnect()
  XCTAssertEqual(sent.last,DMRPackets.control("RPTCL",peer:peer));XCTAssertEqual(bm.phase,.idle)
 }

 func testDMRTransmitClockAndPadding() throws {
  let settings=DMRVoiceSettings(source:2040001,destination:9990,peer:204000101,slot:2,colorCode:1,privateCall:true)
  let tx=FusionTransmitter(),base=Date(timeIntervalSince1970:1000)
  var packets=[Data](),current=base,sendTimes=[Date]()
  tx.onNetwork={packets.append($0);sendTimes.append(current)}
  tx.onAMBE={_ in tx.receive(Packets.ambe(Data(repeating:0x55,count:9),bits:72),now:current)}
  tx.start(call:"PA3EKE",profile:.dmr(settings),now:base,uptime:1000)
  for _ in 0..<7 {tx.append([Float](repeating:0.1,count:160))}
  for i in 0..<7 {current=base.addingTimeInterval(Double(i)*0.02);tx.tick(now:current,uptime:1000+Double(i)*0.02)}
  tx.stop(now:current)
  for i in 7..<40 {current=base.addingTimeInterval(Double(i)*0.02);tx.tick(now:current,uptime:1000+Double(i)*0.02)}
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(tx.encodedCount,9)
  XCTAssertEqual(packets.count,5) // header, three 60ms voice packets, end
  XCTAssertEqual(packets.compactMap{DMRPackets.receive($0)?.kind},[0,1,1,1,2])
  XCTAssertEqual(sendTimes[2].timeIntervalSince(sendTimes[1])>0.055,true)
  XCTAssertEqual(sendTimes[3].timeIntervalSince(sendTimes[2])>0.055,true)
 }

 @MainActor func testLocalBrandMeisterAudioAndModeSwitch() async throws {
  let ambe=try MockUDP(),master=try MockUDP(),mic=StubMicrophone(),store=MemoryDMRPasswordStore()
  try await ambe.start();try await master.start()
  let peer:UInt32=204000101
  var rates=[Data](),bits:UInt8=72,encoded=0,decoded=0,dmrWire=[Data](),ysfWire=[Data](),logins=0,closed=0
  ambe.reply={data in
   guard let p=Packets.dv3k(data) else{return nil}
   if p.type==0 {
    let f=p.body.first!
    if f==0x33{return Data([0x61,0,1,0,0x39])}
    if f==0x30{return Data([0x61,0,5,0,0x30,84,69,83,84])}
    if f==0x0a {rates.append(data);bits=data==Packets.rate ? 49:72}
    return Data([0x61,0,2,0,f,0])
   }
   if p.type==2 {
    encoded += 1
    return Packets.ambe(Data(repeating:0x55,count:bits==72 ? 9:7),bits:bits)
   }
   if p.type==1 {
    XCTAssertEqual(data[5],bits);decoded += 1
    return Data([0x61,1,66,2,0,160])+Data(repeating:0,count:320)
   }
   return nil
  }
  master.reply={data in
   let tag=String(decoding:data.prefix(4),as:UTF8.self)
   switch tag {
   case "RPTL":logins += 1;return Data("RPTACK".utf8)+Data([1,2,3,4])
   case "RPTK":XCTAssertEqual(data,DMRPackets.authentication(peer:peer,salt:Data([1,2,3,4]),password:"test-secret"));return Data("RPTACK".utf8)+DMRPackets.id(peer)
   case "RPTC":
    if data.count==9 {closed += 1;return nil}
    XCTAssertEqual(data.count,302);return Data("RPTACK".utf8)+DMRPackets.id(peer)
   case "RPTP":return Data("MSTPONG".utf8)+DMRPackets.id(peer)
   case "DMRD":dmrWire.append(data)
   case "YSFP":return data
   case "YSFD":ysfWire.append(data)
   default:break
   }
   return nil
  }
  let defaults=UserDefaults.standard
  let keys=["call","host","port","ambeHost","ambePort","digitalMode","dmrID","dmrSSID","dmrHost","dmrPort","dmrDestination","dmrSlot","dmrColorCode","dmrPrivateCall","rememberDMRPassword"]
  let saved=keys.map{defaults.object(forKey:$0)}
  let s=RadioSession(microphone:mic,pttKey:StubPTTKey(),passwordStore:store)
  defer{s.disconnect();ambe.stop();master.stop();for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  s.selectMode(.dmr);s.call="PA3EKE";s.volume=0;s.exclusive=true;s.rememberDMRPassword=true
  s.dmr=DMRConfiguration(radioID:"2040001",ssid:"01",host:"127.0.0.1",port:String(master.port))
  s.ambeHost="127.0.0.1";s.ambePort=String(ambe.port);s.dmrPassword="test-secret"
  s.loadDMRPassword();XCTAssertEqual(s.dmrPassword,"test-secret","A missing saved password must not erase text already entered")
  let passwordDeadline=Date().addingTimeInterval(2)
  while s.loadingDMRPassword,Date()<passwordDeadline {try await Task.sleep(nanoseconds:10_000_000)}
  XCTAssertEqual(s.dmrPassword,"test-secret")
  s.connect()
  var deadline=Date().addingTimeInterval(4)
  while !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.canTransmit,true,s.log);XCTAssertEqual(logins,1)
  XCTAssertEqual(rates,[VoiceProfile.dmr(s.dmr.validated()!).rate])
  XCTAssertEqual(store.values["2040001"],"test-secret")
  s.selectMode(.fusion);XCTAssertEqual(s.selectedMode,.dmr)
  s.toggleTransmit()
  s.requestMode(.fusion)
  XCTAssertEqual(s.selectedMode,.dmr,"A live PTT must not be interrupted by a mode request")
  XCTAssertEqual(s.switchingMode,false)
  XCTAssertEqual(s.transmitting,true)
  for _ in 0..<15 {mic.emit([Float](repeating:0.1,count:160));try await Task.sleep(nanoseconds:20_000_000)}
  s.stopTransmit();deadline=Date().addingTimeInterval(3)
  while (s.transmitting || dmrWire.count<7),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.encodedFrames,15,s.log);XCTAssertEqual(encoded,15)
  XCTAssertEqual(dmrWire.count,7)
  XCTAssertEqual(dmrWire.compactMap{DMRPackets.receive($0)?.kind},[0,1,1,1,1,1,2])
  let echo=DMRVoiceSettings(source:9990,destination:2040001,peer:peer,slot:2,colorCode:1,privateCall:true)
  let voice=Array(repeating:Data(repeating:0x55,count:9),count:3)
  for (seq,kind) in [(0,UInt8(0)),(1,UInt8(1)),(2,UInt8(2))] {
   master.clients.first!.send(content:DMRPackets.transmit(settings:echo,sequence:seq,stream:42,kind:kind,voice:voice),completion:.contentProcessed{_ in})
  }
  deadline=Date().addingTimeInterval(3)
  while s.pcmFrames<3,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.pcmFrames,3,s.log);XCTAssertEqual(decoded,3);XCTAssertEqual(s.station,"Echo · 9990")
  XCTAssertEqual(s.log.contains("test-secret"),false)
  XCTAssertEqual(keys.compactMap{defaults.string(forKey:$0)}.contains("test-secret"),false)
  // Change a live destination without reconnecting or changing AMBE profile.
  deadline=Date().addingTimeInterval(2)
  while !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  s.dmr.destination="204";s.dmr.privateCall=false;s.toggleTransmit()
  for _ in 0..<3 {mic.emit([Float](repeating:0.1,count:160));try await Task.sleep(nanoseconds:20_000_000)}
  s.stopTransmit();deadline=Date().addingTimeInterval(3)
  while (s.transmitting || dmrWire.count<10),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(DMRPackets.receive(dmrWire.last!)?.destination,204)
  XCTAssertEqual(DMRPackets.receive(dmrWire.last!)?.privateCall,false)
  XCTAssertEqual(logins,1);XCTAssertEqual(rates.count,1)
  s.host="127.0.0.1";s.port=String(master.port)
  s.requestMode(.fusion)
  XCTAssertEqual(s.switchingMode,true)
  s.requestMode(.fusion) // repeated click while closing must not start twice
  XCTAssertEqual(s.modeSwitchTarget,.fusion)

  deadline=Date().addingTimeInterval(4)
  while !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.canTransmit,true,s.log);XCTAssertEqual(rates.last,Packets.rate)
  XCTAssertEqual(s.selectedMode,.fusion);XCTAssertEqual(s.switchingMode,false)
  XCTAssertEqual(s.selectedVocoder,.ambeServer);XCTAssertEqual(s.exclusive,true)
  XCTAssertEqual(closed,1)
  try await Task.sleep(nanoseconds:350_000_000)
  XCTAssertEqual(s.active,true,"The previous disconnect fallback must not close the new connection")
  s.toggleTransmit()
  for _ in 0..<10 {mic.emit([Float](repeating:0.1,count:160));try await Task.sleep(nanoseconds:20_000_000)}
  s.stopTransmit();deadline=Date().addingTimeInterval(3)
  while (s.transmitting || ysfWire.count<4),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(ysfWire.count,4,s.log)
  // Invalid target settings leave the working Fusion connection in place.
  s.dmrPassword="";s.requestMode(.dmr)
  XCTAssertEqual(s.selectedMode,.fusion);XCTAssertEqual(s.active,true)
  XCTAssertEqual(s.switchingMode,false);XCTAssertEqual(logins,1)
  XCTAssertEqual(s.connectionError.isEmpty,false)
  s.dmrPassword="test-secret";s.requestMode(.dmr)
  deadline=Date().addingTimeInterval(4)
  while (s.switchingMode || !s.canTransmit),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.selectedMode,.dmr);XCTAssertEqual(s.canTransmit,true,s.log)
  XCTAssertEqual(logins,2);XCTAssertEqual(rates,[VoiceProfile.dmrRate,Packets.rate,VoiceProfile.dmrRate])
  try await Task.sleep(nanoseconds:350_000_000)
  XCTAssertEqual(s.active,true,"Old YSF unlink completion/fallback cannot terminate the new DMR connection")
  // Cancel a queued change, then wait beyond all old disconnect callbacks.
  s.requestMode(.fusion);s.disconnect()
  deadline=Date().addingTimeInterval(2)
  while s.active,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  try await Task.sleep(nanoseconds:350_000_000)
  XCTAssertEqual(s.active,false);XCTAssertEqual(s.switchingMode,false)
  XCTAssertEqual(s.selectedMode,.dmr);XCTAssertEqual(logins,2)
  s.requestMode(.fusion)
  XCTAssertEqual(s.selectedMode,.fusion);XCTAssertEqual(s.active,false,"Idle mode selection must not auto-connect")
 }
}
