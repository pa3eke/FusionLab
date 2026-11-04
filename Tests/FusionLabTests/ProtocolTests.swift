import Foundation
import Darwin
import Network
import Combine
import YSFCodec


final class ProtocolTests {
 func testWireFormatsAndPCM() throws {
  XCTAssertEqual(String(decoding:Packets.poll("pa3eke"),as:UTF8.self),"YSFPPA3EKE    ")
  XCTAssertEqual(Packets.poll("PA3EKE",disconnect:true).prefix(4),Data("YSFU".utf8))
  XCTAssertEqual(Packets.rate,Data([0x61,0,13,0,10,4,49,7,84,0,0,0,0,0,0,112,49]))
  XCTAssertEqual(Packets.ambe(Data(repeating:0,count:7)).count,13)
  XCTAssertNil(Packets.dv3k(Data([0x61,0,9,1,1,49,0])))
  var pcm=Data([0x61,1,66,2,0,160]);pcm.append(Data(repeating:0,count:320))
  pcm[6]=0x80;pcm[8]=0x7f;pcm[9]=0xff
  XCTAssertEqual(Packets.pcm(pcm)![0],-1)
  XCTAssertEqual(Packets.pcm(pcm)![1],32767/32768,accuracy:0.00001)
  XCTAssertNil(Packets.pcm(pcm.dropLast()))
 }
 func testDNFramesAndRepetitionCorrection() throws {
  let ambe: [UInt8] = (0..<35).map { i in
   let value = UInt8((i * 37 + 11) & 255)
   let mask: UInt8 = i % 7 == 6 ? 0x80 : 0xff
   return value & mask
  }
  var payload=[UInt8](repeating:0,count:120)
  ysf_test_payload(ambe,&payload,1,2)
  var out=[UInt8](repeating:0,count:35),fi:UInt8=0,dt:UInt8=0
  XCTAssertEqual(ysf_decode_dn(payload,120,&out,&fi,&dt),5)
  XCTAssertEqual(out,ambe)
  // A single flipped repetition bit is corrected by majority voting.
  payload[35] ^= 0x80
  XCTAssertEqual(ysf_decode_dn(payload,120,&out,&fi,&dt),5)
  XCTAssertEqual(out,ambe)
  ysf_test_payload(ambe,&payload,0,2)
  XCTAssertEqual(ysf_decode_dn(payload,120,&out,&fi,&dt),0)
  ysf_test_payload(ambe,&payload,1,3)
  XCTAssertEqual(ysf_decode_dn(payload,120,&out,&fi,&dt),0)
  payload[0]=0
  XCTAssertEqual(ysf_decode_dn(payload,120,&out,&fi,&dt),-1)
  XCTAssertThrowsError(try Packets.receive(Data(repeating:0,count:155)))
 }
 @MainActor func testLocalEndToEndHandshakeAndReceive() async throws {
  let ambe=try MockUDP(),ysf=try MockUDP()
  try await ambe.start();try await ysf.start()
  var controls=[UInt8](), voices=0
  ambe.reply={d in
   let p=Packets.dv3k(d)!
   if p.type==0 {
    let f=p.body.first!;controls.append(f)
    if f==0x33{return Data([0x61,0,1,0,0x39])}
    if f==0x30{return Data([0x61,0,5,0,0x30,84,69,83,84])}
    return Data([0x61,0,2,0,f,0])
   }
   if p.type==1 {
    XCTAssertEqual(d.count,13);XCTAssertEqual(d[5],49);voices += 1
    return Data([0x61,1,66,2,0,160])+Data(repeating:0,count:320)
   }
   return nil
  }
  var payload=[UInt8](repeating:0,count:120)
  ysf_test_payload([UInt8](repeating:0,count:35),&payload,1,2)
  let network=Data("YSFDTEST      PA0TEST   ALL       ".utf8)+Data([0])+Data(payload)
  XCTAssertEqual(network.count,155)
  ysf.reply={d in d.prefix(4)==Data("YSFP".utf8) ? network:nil}
  let s=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore())
  let defaults=UserDefaults.standard
  let keys=["call","host","port","ambeHost","ambePort"]
  let saved=keys.map{defaults.object(forKey:$0)}
  defer {s.disconnect();ambe.stop();ysf.stop();for (k,v) in zip(keys,saved){if let v {defaults.set(v,forKey:k)}else{defaults.removeObject(forKey:k)}}}
  s.call="PA0TEST" // own-call echo must have the same RX hang time
  s.host="127.0.0.1";s.port=String(ysf.port);s.ambeHost="127.0.0.1";s.ambePort=String(ambe.port);s.exclusive=true;s.volume=0
  s.selectMode(.fusion);s.connect()
  let deadline=Date().addingTimeInterval(4)
  while s.pcmFrames<5 && Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(controls,[0x33,0x30,0x0a,0x15],s.log)
  XCTAssertEqual(s.station,"PA0TEST",s.log)
  XCTAssertEqual(s.voiceFrames,5,s.log)
  XCTAssertEqual(s.pcmFrames,5,s.log)
  XCTAssertEqual(voices,5)
  XCTAssertEqual(s.errors,0,s.log)
  XCTAssertEqual(s.canTransmit,false,"PTT must remain blocked across short RX packet gaps")
  try await Task.sleep(nanoseconds:450_000_000)
  XCTAssertEqual(s.canTransmit,true,"PTT becomes available once RX has ended")
 }
}

final class MockUDP {
 let listener:NWListener
 var port:UInt16{listener.port!.rawValue}
 var reply:((Data)->Data?)?
 var clients=[NWConnection]()
 private var readyContinuation:CheckedContinuation<Void,Error>?
 init() throws{listener=try NWListener(using:.udp,on:.any)}
 @MainActor func start() async throws {
  try await withCheckedThrowingContinuation{(c:CheckedContinuation<Void,Error>) in
   readyContinuation=c
   listener.stateUpdateHandler={[weak self] state in
    guard let self, let continuation=self.readyContinuation else{return}
    if case .ready=state {self.readyContinuation=nil;continuation.resume()}
    if case .failed(let e)=state {self.readyContinuation=nil;continuation.resume(throwing:e)}
   }
   listener.newConnectionHandler={[weak self] connection in
    self?.clients.append(connection);connection.start(queue:.main);self?.read(connection)
   }
   listener.start(queue:.main)
  }
 }
 func read(_ c:NWConnection){
  c.receiveMessage{[weak self] d,_,_,e in
   guard let self,e==nil else{return}
   if let d,let response=self.reply?(d){c.send(content:response,completion:.contentProcessed{_ in})}
   self.read(c)
  }
 }
 func stop(){listener.cancel();clients.forEach{$0.cancel()};clients=[]}
}

private var failures=[String]()
func XCTAssertEqual<T:Equatable>(_ a:T,_ b:T,_ message:String="",file:StaticString=#filePath,line:UInt=#line){if a != b {failures.append("\(file):\(line) \(a) != \(b) \(message)")}}
func XCTAssertEqual(_ a:Float,_ b:Float,accuracy:Float,file:StaticString=#filePath,line:UInt=#line){if abs(a-b)>accuracy {failures.append("\(file):\(line) float mismatch")}}
func XCTAssertNil<T>(_ a:T?,file:StaticString=#filePath,line:UInt=#line){if a != nil {failures.append("\(file):\(line) expected nil")}}
func XCTAssertThrowsError<T>(_ expression:@autoclosure () throws -> T,file:StaticString=#filePath,line:UInt=#line){do{_ = try expression();failures.append("\(file):\(line) expected error")}catch{}}
@main struct SelfTest {
 @MainActor static func main() async {
  let suite=ProtocolTests()
  do {
   suite.testRadioLCDPresentationAndMeter()
   try await suite.testRenderedRadioLCD()
   try suite.testReceiveMuteAndXKeys()
   suite.testReceiveMuteOutputGain()
   suite.testXKeysReportsAndPTTRequests()
   try suite.testXKeysControllerAndStorage()
   try await suite.testXKeysCentralPTTLifecycle()
   try await suite.testNXDNCallsignLookupAndDisplay()
   try suite.testNXDNWireAndClock()
   try await suite.testNXDNHostsAndPresets()
   try await suite.testNXDNLocalAudioAndModeSwitch()
   suite.testMicrophoneGainAndClipping()
   suite.testReceiveAGC()
   suite.testReceiveEQ()
   try suite.testQuickPresetStorage()
   try await suite.testPasswordRestoreDoesNotBlockStartup()
   suite.testDMRQuickSelection()
   try await suite.testLiveReflectorQuickSwitch()
   try suite.testFusionMD380BitOrder()
   suite.testMD380FEC()
   try suite.testLocalMD380Codec()
   try await suite.testLocalMD380Protocol()
   try await suite.testMD380RadioSession()
   try await suite.testBrandMeisterHeartbeatWithoutUI()
   suite.testBoundedActivityLog()
   try await suite.testDMRCallsignLookupAndDisplay()
   try suite.testDMRWireAndReferenceFrames()
   suite.testBrandMeisterHandshakeAndTimeout()
   try suite.testDMRTransmitClockAndPadding()
   try await suite.testDMRReceiveFilteringAndSequenceWrap()
   try await suite.testLocalBrandMeisterAudioAndModeSwitch()
   try await suite.testRenderedPTTSize()
   try suite.testPTTKeyModesAndDeadline()
   try suite.testSelectedTransmitLimits()
   try await suite.testGlobalPTTLifecycle()
   suite.testYSFHostParsingAndSearch()
   try await suite.testYSFHostCacheRefreshAndSelection()
   try suite.testWireFormatsAndPCM()
   try suite.testDNFramesAndRepetitionCorrection()
   try suite.testMicrophoneResampling()
   try suite.testSeparateMicrophoneChannels()
   try suite.testTransmitVectors()
   try suite.testBatchedMicrophoneAudio()
   try suite.testTransmitPacingAndStop()
   try suite.testTransmitTimeoutAndCancel()
   try await suite.testAudioTimingWhileInterfaceIsBlocked()
   try await suite.testEchoBurstPreservesSpeech()
   try await suite.testLocalEndToEndHandshakeAndReceive()
   try await suite.testLocalPTTAndPermissionFailures()
  }catch{failures.append(error.localizedDescription)}
  if failures.isEmpty {print("PASS: LCD presentation/dBFS/native rendering, XK-24 parsing/edges/storage/LEDs, central PTT ownership/USB loss/reconnect/inhibition/emergency, Fusion, DMR and NXDN reference vectors, NXDN host cache/presets, NXDN RX/TX/80ms timing and both vocoders, BrandMeister authentication/RX/TX/mode switch, receive filtering, PCM, FICH, local UDP, PTT hold/toggle, 180s deadline, microphone permission, pacing, padding and timeout")}
  else {failures.forEach{print("FAIL: \($0)")};exit(1)}
 }
}
