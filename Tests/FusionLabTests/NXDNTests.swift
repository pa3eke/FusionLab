import Foundation
import Network

extension ProtocolTests {
 func testNXDNWireAndClock() throws {
  struct Vectors:Decodable {let voices:[String];let header:String;let end:String}
  let url=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/NXDNReference.json")
  let data=try Data(contentsOf:url),v=try JSONDecoder().decode(Vectors.self,from:data)
  let dict=try JSONSerialization.jsonObject(with:data) as! [String:Any]
  func hex(_ text:String)->Data {Data(stride(from:0,to:text.count,by:2).map{i in let a=text.index(text.startIndex,offsetBy:i);return UInt8(text[a..<text.index(a,offsetBy:2)],radix:16)!})}
  let voices=v.voices.map(hex),settings=NXDNVoiceSettings(source:41007,destination:204,ran:1)
  XCTAssertEqual(NXDNPackets.poll("pa3eke",destination:204),Data("NXDNPPA3EKE    ".utf8)+Data([0,204]))
  XCTAssertEqual(NXDNPackets.poll("PA3EKE",destination:204,disconnect:true).prefix(5),Data("NXDNU".utf8))
  XCTAssertEqual(NXDNPackets.isPollReply(Data(repeating:0,count:17),call:"PA3EKE",destination:204),false)
  XCTAssertEqual(NXDNPackets.isPollReply(NXDNPackets.poll("PA3EKE",destination:205),call:"PA3EKE",destination:204),false)
  XCTAssertEqual(VoiceProfile.nxdn(settings).rate,Packets.rate)
  XCTAssertEqual(VoiceProfile.nxdn(settings).blocks,4);XCTAssertEqual(VoiceProfile.nxdn(settings).bits,49)
  for (label,seq,kind) in [("header",0,UInt8(0)),("voice-1",1,1),("voice-2",2,1),("voice-3",3,1),("voice-4",4,1),("end",5,2)] {
   let expected=hex(dict[label] as! String),packet=NXDNPackets.transmit(settings:settings,sequence:seq,kind:kind,voice:voices)
   XCTAssertEqual(packet,expected,label)
   let received=NXDNPackets.receive(expected)
   XCTAssertEqual(received?.source,41007);XCTAssertEqual(received?.destination,204);XCTAssertEqual(received?.ran,1)
   XCTAssertEqual(received?.kind,kind);XCTAssertEqual(received?.frames,kind==1 ? voices:[])
   XCTAssertNil(NXDNPackets.receive(packet.dropLast()))
   for index in [0,9,11,14] {var bad=packet;bad[index] ^= 0x80;XCTAssertNil(NXDNPackets.receive(bad))}
   if kind != 1 {var bad=packet;bad[29] ^= 1;XCTAssertNil(NXDNPackets.receive(bad))}
  }
  var config=NXDNConfiguration(radioID:"41007")
  XCTAssertEqual(config.validated()?.source,41007)
  for invalid in ["2041007","0","65520","-1",""] {config.radioID=invalid;XCTAssertNil(config.validated())}
  let tx=FusionTransmitter(),base=Date(timeIntervalSince1970:1000)
  var now=base,wire=[Data](),times=[TimeInterval](),encoded=0
  tx.onNetwork={wire.append($0);times.append(now.timeIntervalSince(base))}
  tx.onAMBE={_ in encoded += 1;tx.receive(Packets.ambe(voices[(encoded-1)%4]),now:now)}
  tx.start(call:"PA3EKE",profile:.nxdn(settings),now:base)
  for _ in 0..<5 {tx.append(Array(repeating:0.1,count:160))}
  for i in 0..<6 {now=base.addingTimeInterval(Double(i)*0.02);tx.tick(now:now)}
  tx.stop(now:now)
  for i in 6..<30 {now=base.addingTimeInterval(Double(i)*0.02);tx.tick(now:now)}
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(encoded,8)
  XCTAssertEqual(wire.compactMap{NXDNPackets.receive($0)?.kind},[0,1,1,2])
  XCTAssertEqual(wire[1].count,43);XCTAssertEqual(times[1]>=0.079,true);XCTAssertEqual(times[2]-times[1]>=0.079,true)
 }
 @MainActor func testNXDNHostsAndPresets() async throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer{try? FileManager.default.removeItem(at:root)}
  let text="# attribution\n204\tnxdn.repeaters-haaglanden.nl\t41400\n205 127.0.0.1 42400 # comment\n204 nxdn.repeaters-haaglanden.nl 41400\n0 invalid 1\n204 bad/host 41400\nabc host 41400\n711 host 0\n"
  let hosts=NXDNHost.parse(text)
  XCTAssertEqual(hosts.count,2);XCTAssertEqual(hosts[0].number,204);XCTAssertEqual(hosts[1].matches("127.0"),true)
  let cache=root.appendingPathComponent("hosts.txt")
  let catalog=NXDNHostCatalog(seedText:"",cacheURL:cache,download:{Data(text.utf8)})
  await catalog.refresh();XCTAssertEqual(catalog.hosts,hosts)
  XCTAssertEqual(try String(contentsOf:cache,encoding:.utf8),text)
  let offline=NXDNHostCatalog(cacheURL:cache,download:{Data("<html>broken</html>".utf8)})
  await offline.refresh();XCTAssertEqual(offline.hosts,hosts)
  XCTAssertEqual(offline.status.contains("mislukt"),true)
  let suite="FusionLab.NXDNTests.\(UUID())",defaults=UserDefaults(suiteName:suite)!
  defer{defaults.removePersistentDomain(forName:suite)}
  let preset=QuickPreset.nxdn(title:"TG 204",host:"127.0.0.1",port:41400,destination:204,ran:1)
  QuickPreset.save([preset],mode:.nxdn,defaults:defaults)
  XCTAssertEqual(QuickPreset.load(.nxdn,defaults:defaults).first!,preset)
  XCTAssertEqual(QuickPreset.load(.dmr,defaults:defaults).first!!.mode,.dmr)
  XCTAssertEqual(QuickPreset.load(.fusion,defaults:defaults).first!!.mode,.fusion)
  XCTAssertEqual(preset.renamed("test").title,"test")
 }
 @MainActor func testNXDNLocalAudioAndModeSwitch() async throws {
  let reflector=try MockUDP(),ambe=try MockUDP(),mic=StubMicrophone()
  try await reflector.start();try await ambe.start()
  let defaults=UserDefaults.standard
  let keys=["call","host","port","ambeHost","ambePort","digitalMode","nxdnID","nxdnHost","nxdnPort","nxdnDestination","nxdnRAN","quickPresetsV1.nxdn","vocoderBackend"]
  let saved=keys.map{defaults.object(forKey:$0)}
  let s=RadioSession(microphone:mic,pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),nxdnCallsignDirectory:TestNXDNLookup())
  defer{s.disconnect();reflector.stop();ambe.stop();for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  var wire=[Data](),unlinks=[Data](),rates=[Data](),decode=0,encode=0
  reflector.reply={d in
   if d.prefix(5)==Data("NXDNP".utf8) {return d}
   if d.prefix(5)==Data("NXDNU".utf8) {unlinks.append(d)}
   if d.prefix(5)==Data("NXDND".utf8) {wire.append(d)}
   if d.prefix(4)==Data("YSFP".utf8) {return d}
   return nil
  }
  ambe.reply={d in
   guard let p=Packets.dv3k(d) else{return nil}
   if p.type==0 {
    let f=p.body.first!
    if f==0x33 {return Data([0x61,0,1,0,0x39])}
    if f==0x30 {return Data([0x61,0,5,0,0x30,84,69,83,84])}
    if f==0x0a {rates.append(d)}
    return Data([0x61,0,2,0,f,0])
   }
   if p.type==1 {XCTAssertEqual(d[5],49);decode += 1;return Data([0x61,1,66,2,0,160])+Data(repeating:0,count:320)}
   if p.type==2 {encode += 1;return Packets.ambe(Data(repeating:0,count:7))}
   return nil
  }
  s.call="PA3EKE";s.volume=0;s.exclusive=true
  s.selectMode(.nxdn);s.nxdn=NXDNConfiguration(radioID:"41007",host:"127.0.0.1",port:String(reflector.port))
  s.ambeHost="127.0.0.1";s.ambePort=String(ambe.port)
  s.connect()
  var deadline=Date().addingTimeInterval(4)
  while !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.canTransmit,true,s.log);XCTAssertEqual(rates,[Packets.rate])
  let incoming=NXDNVoiceSettings(source:12345,destination:204,ran:1),voice=Array(repeating:Data(repeating:0,count:7),count:4)
  // Send identical voice twice: NXDN has no packet sequence; silence must not be deduplicated.
  for kind:UInt8 in [0,1,1,2] {
   reflector.clients.first!.send(content:NXDNPackets.transmit(settings:incoming,sequence:1,kind:kind,voice:voice),completion:.contentProcessed{_ in})
  }
  deadline=Date().addingTimeInterval(3)
  while s.pcmFrames<8,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.pcmFrames,8,s.log);XCTAssertEqual(decode,8);XCTAssertEqual(s.voiceFrames,8);XCTAssertEqual(s.station,"PA0NX · 12345")
  XCTAssertEqual(s.receivedStationQRZURL?.absoluteString,"https://www.qrz.com/db/PA0NX")
  // Other TG and malformed datagrams never enter the decoder.
  let other=NXDNVoiceSettings(source:12345,destination:205,ran:1)
  for packet in [NXDNPackets.transmit(settings:other,sequence:1,kind:1,voice:voice),Data(repeating:0,count:43)] {
   reflector.clients.first!.send(content:packet,completion:.contentProcessed{_ in})
  }
  try await Task.sleep(nanoseconds:500_000_000);XCTAssertEqual(decode,8)
  s.toggleTransmit();XCTAssertEqual(s.transmitting,true,s.log)
  s.requestMode(.fusion);XCTAssertEqual(s.selectedMode,.nxdn,"PTT blocks mode changes")
  for _ in 0..<5 {mic.emit(Array(repeating:0.1,count:160));try await Task.sleep(nanoseconds:20_000_000)}
  s.stopTransmit();deadline=Date().addingTimeInterval(3)
  while s.transmitting || wire.count<4,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(encode,8);XCTAssertEqual(wire.compactMap{NXDNPackets.receive($0)?.kind},[0,1,1,2])
  XCTAssertEqual(NXDNPackets.receive(wire[1])?.source,41007)
  s.selectNXDNReflector(NXDNHost(number:205,host:"127.0.0.1",port:reflector.port))
  deadline=Date().addingTimeInterval(4)
  while s.switchingMode || !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.selectedMode,.nxdn);XCTAssertEqual(s.canTransmit,true,s.log)
  XCTAssertEqual(unlinks.first,NXDNPackets.poll("PA3EKE",destination:204,disconnect:true),"Unlink addresses the old TG")
  s.host="127.0.0.1";s.port=String(reflector.port);s.requestMode(.fusion)
  deadline=Date().addingTimeInterval(4)
  while s.switchingMode || !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.selectedMode,.fusion);XCTAssertEqual(s.canTransmit,true,s.log)
  s.requestMode(.nxdn)
  deadline=Date().addingTimeInterval(4)
  while s.switchingMode || !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.selectedMode,.nxdn);XCTAssertEqual(s.canTransmit,true,s.log)
  XCTAssertEqual(rates,[Packets.rate,Packets.rate,Packets.rate,Packets.rate])
  try await Task.sleep(nanoseconds:350_000_000);XCTAssertEqual(s.active,true)
  s.disconnect();deadline=Date().addingTimeInterval(2)
  while s.active,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.active,false)
 }
}
