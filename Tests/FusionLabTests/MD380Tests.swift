import Foundation
import MD380Codec

extension ProtocolTests {
 func testFusionMD380BitOrder() throws {
  // External DVSI boundary vectors, rather than a codec self-round-trip.
  let vectors:[([UInt8],[UInt8])]=[
   ([0xf8,0xfe,0x14,0x39,0x8c,0x50,0x80],[0xbe,0x68,0x41,0xdb,0x4b,0xe0,0x00]),
   ([0x0b,0x30,0x55,0x7a,0x9f,0xc4,0x00],[0x2c,0xba,0xe6,0x4f,0x44,0x21,0x80]),
   ([0xff,0xff,0xff,0xff,0xff,0xff,0x80],[0xff,0xff,0xff,0xff,0xff,0xff,0x80]),
  ]
  for (native,dvsi) in vectors {
   XCTAssertEqual(try AMBE49BitOrder.toMD380(Data(dvsi)),Data(native))
   XCTAssertEqual(try AMBE49BitOrder.fromMD380(Data(native)),Data(dvsi))
  }
  // Existing independently generated DroidStar on-air fixture. The network
  // decoder deliberately returns DVSI order for the working AMBEserver path.
  let url=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/DroidStarTX.json")
  let fixture=try JSONDecoder().decode([String:String].self,from:Data(contentsOf:url))
  let hex=Array(fixture["voice-fn0"]!)
  let wire=Data(stride(from:0,to:hex.count,by:2).map{UInt8(String(hex[$0...$0+1]),radix:16)!})
  let frame=try Packets.receive(wire).frames[0]
  XCTAssertEqual(frame,Data([0x0b,0x30,0x55,0x7a,0x9f,0xc4,0x80]))
  XCTAssertEqual(try AMBE49BitOrder.toMD380(frame),Data([0x21,0x6e,0x9c,0xb3,0x11,0x5b,0x80]))
  // Bits outside the 49-bit frame are padding, not speech parameters.
  XCTAssertEqual(try AMBE49BitOrder.toMD380(Data([0,0,0,0,0,0,0x7f])),Data(repeating:0,count:7))
  XCTAssertThrowsError(try AMBE49BitOrder.toMD380(Data()))
 }
 func testMD380FEC(){
  for seed in 0..<100 {
   var raw=(0..<7).map{UInt8(($0*37+seed*11)&255)};raw[6] &= 0x80
   var coded=[UInt8](repeating:0,count:9),decoded=[UInt8](repeating:0,count:7)
   md380_fec_encode(raw,&coded);md380_fec_decode(coded,&decoded)
   XCTAssertEqual(decoded,raw,"MD380 49/72-bit mapping must round-trip")
  }
 }
 func testLocalMD380Codec() throws {
  guard FileManager.default.fileExists(atPath:MD380Vocoder.supportDirectory.appendingPathComponent("md380fw.img").path) else{print("SKIP: local MD380 runtime not installed");return}
  let codec=try MD380Vocoder()
  let pcm=(0..<160).map{Int16(5000*sin(2 * Double.pi * 440 * Double($0)/8000))}
  let raw=try codec.encode(pcm,bits:49)
  XCTAssertEqual(raw.map{String(format:"%02x",$0)}.joined(),"f8fe14398c5080","Matches the independent Python emulator probe")
  try codec.reset()
  var expected=[UInt8](repeating:0,count:9)
  md380_fec_encode([UInt8](raw),&expected)
  XCTAssertEqual(try codec.encode(pcm,bits:72),Data(expected))
  let began=ProcessInfo.processInfo.systemUptime
  var peak=0
  for index in 0..<120 {
   let bits:UInt8=index<60 ? 49:72
   let voice=try codec.encode(pcm,bits:bits)
   let decoded=try codec.decode(voice,bits:bits)
   XCTAssertEqual(decoded.count,160)
   peak=max(peak,decoded.map{abs(Int($0))}.max() ?? 0)
  }
  let elapsed=ProcessInfo.processInfo.systemUptime-began
  print("MD380 local encode/decode: 120 frames in \(elapsed) s; decoded peak \(peak)")
  XCTAssertEqual(peak>100,true,"The decoder must produce real audio")
  XCTAssertEqual(elapsed<2.4,true,"Round-trip processing must be faster than the corresponding 20-ms audio frames")
  XCTAssertThrowsError(try codec.encode([],bits:49))
  XCTAssertThrowsError(try codec.decode(Data(),bits:72))
 }
 @MainActor func testLocalMD380Protocol() async throws {
  guard FileManager.default.fileExists(atPath:MD380Vocoder.supportDirectory.appendingPathComponent("md380fw.img").path) else{return}
  for bits in [UInt8(49),UInt8(72)] {
   let queue=DispatchQueue(label:"FusionLabTests.md380Protocol")
   let link=VocoderTransport(queue:queue)
   var ready=false,encoded=0,decoded=0,errors=[String]()
   let reference=try MD380Vocoder()
   let toneSamples=(0..<160).map{Float(0.15*sin(2 * Double.pi * 440 * Double($0)/8000))}
   let tone=Packets.pcm(Packets.speech(toneSamples))!.map{Int16((Double($0)*32768).rounded())}
   var expectedAudio=[[Int16]]()
   for _ in 0..<20 {
    let native=try reference.encode(tone,bits:bits)
    expectedAudio.append(try reference.decode(native,bits:bits))
   }
   link.onError={errors.append($0)}
   link.onReady={link.send(Packets.control(0x33))}
   link.onData={data in
    guard let packet=Packets.dv3k(data) else{return}
    if packet.type==0 {
     switch packet.body.first! {
     case 0x39:link.send(Packets.control(0x30))
     case 0x30:link.send(bits==49 ? Packets.rate:VoiceProfile.dmrRate)
     case 0x0a:link.send(Data([0x61,0,3,0,0x15,0,1]))
     case 0x15:ready=true
     default:break
     }
    }else if packet.type==1 {
     XCTAssertEqual(Packets.encodedVoice(data,bits:bits)?.count,bits==49 ? 7:9)
     if bits==49,encoded==0 {
      // Independently encode native parameters, then check the DVSI boundary.
      let native=try! MD380Vocoder().encode(tone,bits:49)
      let actual=Packets.encodedVoice(data,bits:bits)!
      XCTAssertEqual(actual,try! AMBE49BitOrder.fromMD380(native))
      XCTAssertEqual(actual != native,true,"Fusion must not expose native MD380 order as DVSI")
     }
     encoded += 1;link.send(data)
    }else if packet.type==2 {
     let samples=Packets.pcm(data)!
     XCTAssertEqual(samples.count,160)
     let actual=samples.map{Int16((Double($0)*32768).rounded())}
     if decoded<expectedAudio.count {XCTAssertEqual(actual,expectedAudio[decoded],"DVSI input must decode identically to native MD380 parameters")}
     decoded += 1
    }
   }
   link.open(host:"unused.invalid",port:2460,backend:.md380)
   let deadline=Date().addingTimeInterval(3)
   while !queue.sync(execute:{ready}) && Date()<deadline {try await Task.sleep(nanoseconds:10_000_000)}
   XCTAssertEqual(queue.sync{ready},true)
   for _ in 0..<20 {link.send(Packets.speech((0..<160).map{Float(0.15*sin(2 * Double.pi * 440 * Double($0)/8000))}))}
   queue.sync{}
   XCTAssertEqual(queue.sync{encoded},20);XCTAssertEqual(queue.sync{decoded},20);XCTAssertEqual(queue.sync{errors},[])
   link.close();queue.sync{}
  }
 }
 @MainActor func testMD380RadioSession() async throws {
  guard FileManager.default.fileExists(atPath:MD380Vocoder.supportDirectory.appendingPathComponent("md380fw.img").path) else{return}
  let master=try MockUDP(),mic=StubMicrophone()
  try await master.start()
  var wire=[Data]()
  let peer:UInt32=2040001
  master.reply={data in
   let tag=String(decoding:data.prefix(4),as:UTF8.self)
   if tag=="RPTL" {return Data("RPTACK".utf8)+Data([1,2,3,4])}
   if tag=="RPTK" || data.count==302 {return Data("RPTACK".utf8)+DMRPackets.id(peer)}
   if data.prefix(7)==Data("RPTPING".utf8){return Data("MSTPONG".utf8)+DMRPackets.id(peer)}
   if tag=="YSFP" || data.prefix(5)==Data("NXDNP".utf8) {return data}
   if data.prefix(5)==Data("NXDND".utf8) {wire.append(data)}
   if tag=="DMRD" {wire.append(data)}
   return nil
  }
  let defaults=UserDefaults.standard
  let keys=["call","host","port","ambeHost","ambePort","digitalMode","dmrID","dmrSSID","dmrHost","dmrPort","dmrDestination","dmrSlot","dmrColorCode","dmrPrivateCall","rememberDMRPassword","vocoderBackend"]
  let nxdnSaved=NXDNConfiguration.load()
  let saved=keys.map{defaults.object(forKey:$0)}
  let session=RadioSession(microphone:mic,pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),nxdnCallsignDirectory:TestNXDNLookup(),vocoderBackend:.md380)
  defer{session.disconnect();nxdnSaved.save();master.stop();for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  session.selectMode(.dmr);session.call="PA0TEST";session.volume=0;session.rememberDMRPassword=false
  session.dmr=DMRConfiguration(radioID:"2040001",host:"127.0.0.1",port:String(master.port))
  session.dmrPassword="test-secret";session.ambeHost="unused.invalid";session.ambePort="invalid";session.exclusive=false
  session.connect()
  var deadline=Date().addingTimeInterval(5)
  while !session.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.canTransmit,true,session.log)
  session.selectVocoder(.ambeServer)
  XCTAssertEqual(session.selectedVocoder,.md380,"Backend cannot change during a connection")
  session.toggleTransmit()
  for _ in 0..<15 {
   mic.emit((0..<160).map{Float(0.15*sin(2 * Double.pi * 440 * Double($0)/8000))})
   try await Task.sleep(nanoseconds:20_000_000)
  }
  session.stopTransmit()
  deadline=Date().addingTimeInterval(3)
  while session.transmitting || wire.count<7,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.encodedFrames,15,session.log)
  XCTAssertEqual(wire.compactMap{DMRPackets.receive($0)?.kind},[0,1,1,1,1,1,2])
  let frames=wire.compactMap{DMRPackets.receive($0)}.flatMap{$0.frames}
  let echo=DMRVoiceSettings(source:9990,destination:peer,peer:peer,slot:2,colorCode:1,privateCall:true)
  var replies=[DMRPackets.transmit(settings:echo,sequence:0,stream:101,kind:0)]
  if frames.count==15 {for i in 0..<5 {replies.append(DMRPackets.transmit(settings:echo,sequence:i+1,stream:101,kind:1,voice:Array(frames[i*3..<i*3+3])))}}
  replies.append(DMRPackets.transmit(settings:echo,sequence:6,stream:101,kind:2))
  for packet in replies {master.clients.first?.send(content:packet,completion:.contentProcessed{_ in})}
  deadline=Date().addingTimeInterval(3)
  while session.pcmFrames<15,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.pcmFrames,15,session.log)
  XCTAssertEqual(session.station,"Echo · 9990")
  session.host="127.0.0.1";session.port=String(master.port)
  session.requestMode(.fusion)
  deadline=Date().addingTimeInterval(4)
  while (session.switchingMode || !session.canTransmit),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.selectedMode,.fusion);XCTAssertEqual(session.canTransmit,true,session.log)
  XCTAssertEqual(session.selectedVocoder,.md380);XCTAssertEqual(session.exclusive,false)
  try await Task.sleep(nanoseconds:350_000_000)
  XCTAssertEqual(session.active,true)
  session.requestMode(.dmr)
  deadline=Date().addingTimeInterval(4)
  while (session.switchingMode || !session.canTransmit),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.selectedMode,.dmr);XCTAssertEqual(session.canTransmit,true,session.log)
  XCTAssertEqual(session.selectedVocoder,.md380)
  try await Task.sleep(nanoseconds:350_000_000)
  XCTAssertEqual(session.active,true)
  session.nxdn=NXDNConfiguration(radioID:"41007",host:"127.0.0.1",port:String(master.port))
  session.requestMode(.nxdn)
  deadline=Date().addingTimeInterval(4)
  while session.switchingMode || !session.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.selectedMode,.nxdn);XCTAssertEqual(session.selectedVocoder,.md380)
  XCTAssertEqual(session.canTransmit,true,session.log)
  wire=[];session.toggleTransmit()
  for _ in 0..<8 {
   mic.emit((0..<160).map{Float(0.15*sin(2 * Double.pi * 440 * Double($0)/8000))})
   try await Task.sleep(nanoseconds:20_000_000)
  }
  session.stopTransmit();deadline=Date().addingTimeInterval(3)
  while session.transmitting || wire.count<4,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(wire.compactMap{NXDNPackets.receive($0)?.kind},[0,1,1,2])
  let nxdnEcho=NXDNVoiceSettings(source:12345,destination:204,ran:1)
  let groups=wire.compactMap{NXDNPackets.receive($0)}.filter{$0.kind==1}
  XCTAssertEqual(groups.count,2)
  for (i,group) in groups.enumerated() {
   master.clients.last?.send(content:NXDNPackets.transmit(settings:nxdnEcho,sequence:i+1,kind:1,voice:group.frames),completion:.contentProcessed{_ in})
  }
  deadline=Date().addingTimeInterval(3)
  while session.pcmFrames<8,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.pcmFrames,8,session.log)
 }
}
