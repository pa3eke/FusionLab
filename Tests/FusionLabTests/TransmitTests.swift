import Foundation
import AVFoundation
import YSFCodec

extension ProtocolTests {
 func testMicrophoneResampling() throws {
  for rate in [44100.0,48000.0] {
   let format=AVAudioFormat(standardFormatWithSampleRate:rate,channels:2)!
   let converter=try MicrophoneResampler(source:format)
   var frames=[[Float]]()
   for _ in 0..<20 {
    let count=AVAudioFrameCount(rate/50)
    let input=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:count)!
    input.frameLength=count
    for channel in 0..<2 {for i in 0..<Int(count){input.floatChannelData![channel][i]=0.2}}
    frames.append(contentsOf:try converter.convert(input))
   }
   XCTAssertEqual(frames.count>=19 && frames.count<=20,true,"Resampling \(rate): \(frames.count) frames")
   XCTAssertEqual(frames.allSatisfy{$0.count==160},true)
   XCTAssertEqual(frames.last!.reduce(0,+)/160,0.2,accuracy:0.02)
  }
 }

 func testSeparateMicrophoneChannels() throws {
  let format=AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)!
  for channel in 0...1 {
   let converter=try MicrophoneResampler(source:format,channel:channel)
   var frames=[[Float]]()
   for _ in 0..<10 {
    let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:960)!;buffer.frameLength=960
    for i in 0..<960 {buffer.floatChannelData![0][i]=0.05;buffer.floatChannelData![1][i]=0.4}
    frames.append(contentsOf:try converter.convert(buffer))
   }
   XCTAssertEqual(frames.last!.reduce(0,+)/160,channel==0 ? 0.05:0.4,accuracy:0.01)
  }
 }
 func testTransmitVectors() throws {
  let url=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/DroidStarTX.json")
  let golden=try JSONDecoder().decode([String:String].self,from:Data(contentsOf:url))
  let raw:[UInt8]=(0..<35).map{i in
   let b=UInt8((i*37+11)&255),mask:UInt8=i%7==6 ? 0x80:0xff
   return b&mask
  }
  let voices=stride(from:0,to:35,by:7).map{Data(raw[$0..<$0+7])}
  let cases:[(String,Int,UInt8)]=[("header",0,0),("voice-fn0",1,1),("voice-fn1",2,1),("voice-wrap",128,1),("end",3,2)]
  for (label,seq,fi) in cases {
   let d=Packets.transmit(call:"PA3EKE",sequence:seq,fi:fi,voice:voices)
   XCTAssertEqual(d.map{String(format:"%02x",$0)}.joined(),golden[label]!,label)
   let r=try Packets.receive(d)
   XCTAssertEqual(r.source,"PA3EKE");XCTAssertEqual(r.fi,fi);XCTAssertEqual(r.mode,2)
   if fi==1 {XCTAssertEqual(r.frames,voices)}
  }
  // Actual AMBE3000R reply observed locally: CHAND plus CHANMODE.
  let hardware=Data([0x61,0,12,1,1,49,0xde,0xba,3,1,0xa6,0xe6,0,2,0,2])
  XCTAssertEqual(Packets.encodedVoice(hardware),Data([0xde,0xba,3,1,0xa6,0xe6,0]))
  XCTAssertNil(Packets.encodedVoice(hardware.dropLast()))
  var bad=hardware;bad[13]=3;XCTAssertNil(Packets.encodedVoice(bad))
  let samples:[Float]=[-2,-1,0,0.5,1,2,.nan]+[Float](repeating:0,count:153)
  let speech=Packets.speech(samples)
  let decoded=Packets.pcm(speech)!
  XCTAssertEqual(decoded[0],-1);XCTAssertEqual(decoded[3],0.5)
  XCTAssertEqual(decoded[4],32767/32768,accuracy:0.00001);XCTAssertEqual(decoded[6],0)
 }
 func testTransmitPacingAndStop() throws {
  let tx=FusionTransmitter(),base=Date(timeIntervalSince1970:1000)
  var wire=[Data](),inputs=0,current=base
  tx.onNetwork={wire.append($0)}
  tx.onAMBE={d in
   XCTAssertEqual(d.count,326);XCTAssertEqual(d.prefix(6),Data([0x61,1,66,2,0,160]))
   inputs += 1
   tx.receive(Packets.ambe(Data(repeating:0,count:7)),now:current)
  }
  tx.start(call:"PA3EKE",now:base)
  for _ in 0..<7{tx.append([Float](repeating:0.1,count:160))}
  for i in 0..<7 {current=base.addingTimeInterval(Double(i)*0.021);tx.tick(now:current)}
  tx.stop(now:current)
  for i in 7..<35 {current=base.addingTimeInterval(Double(i)*0.021);tx.tick(now:current)}
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(inputs,10)
  XCTAssertEqual(wire.count,4) // header, 2 voice frames, terminator
  XCTAssertEqual(wire.map{$0[34]},[0,2,4,7])
  XCTAssertEqual(try wire.map{try Packets.receive($0).fi},[0,1,1,2])
  XCTAssertEqual(tx.inputCount,10);XCTAssertEqual(tx.encodedCount,10)
  let count=wire.count
  tx.append([Float](repeating:0,count:160));tx.tick(now:base.addingTimeInterval(2))
  XCTAssertEqual(wire.count,count)
 }
 func testTransmitTimeoutAndCancel() throws {
  let base=Date(timeIntervalSince1970:1000)
  let tx=FusionTransmitter();var wire=[Data](),errors=[String]()
  tx.onNetwork={wire.append($0)};tx.onError={errors.append($0)}
  tx.start(call:"PA3EKE",now:base);tx.append([Float](repeating:0,count:160));tx.tick(now:base)
  tx.tick(now:base.addingTimeInterval(1.1))
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(errors.count,1)
  XCTAssertEqual(try Packets.receive(wire.last!).fi,2)
  wire=[];tx.start(call:"PA3EKE",now:base);tx.cancel();tx.cancel()
  XCTAssertEqual(wire.count,2)
  wire=[];tx.start(call:"PA3EKE",now:base);tx.tick(now:base.addingTimeInterval(181))
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(try Packets.receive(wire.last!).fi,2)
 }
 @MainActor func testLocalPTTAndPermissionFailures() async throws {
  let ambe=try MockUDP(),ysf=try MockUDP(),mic=StubMicrophone()
  try await ambe.start();try await ysf.start()
  var transmitted=[Data](),encodeRequests=0,disconnects=0,resetRequests=0
  var malformedNext=false
  ambe.reply={d in
   guard let p=Packets.dv3k(d) else{return nil}
   if p.type==0 {
    let f=p.body.first!
    if f==0x33{resetRequests += 1;return Data([0x61,0,1,0,0x39])}
    if f==0x30{return Data([0x61,0,5,0,0x30,84,69,83,84])}
    return Data([0x61,0,2,0,f,0])
   }
   if p.type==2 {
    XCTAssertEqual(Packets.pcm(d)?.count,160);encodeRequests += 1
    if encodeRequests<=7 {XCTAssertEqual(Packets.pcm(d)![0],0.199526,accuracy:0.0001)}
    if malformedNext {malformedNext=false;return Data([0x61,0,2,1,0xff,0])}
    return Data([0x61,0,12,1,1,49])+Data(repeating:0,count:7)+Data([2,0,2])
   }
   return nil
  }
  ysf.reply={d in
   if d.prefix(4)==Data("YSFU".utf8){disconnects += 1}
   if d.prefix(4)==Data("YSFD".utf8){transmitted.append(d)}
   return d.prefix(4)==Data("YSFP".utf8) ? d:nil
  }
  let defaults=UserDefaults.standard,keys=["call","host","port","ambeHost","ambePort","microphoneGainDB"]
  let saved=keys.map{defaults.object(forKey:$0)}
  let session=RadioSession(microphone:mic,pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore())
  defer {session.disconnect();ambe.stop();ysf.stop();for(k,v)in zip(keys,saved){if let v {defaults.set(v,forKey:k)}else{defaults.removeObject(forKey:k)}}}
  session.volume=0;session.microphoneGainDB=6;session.host="127.0.0.1";session.port=String(ysf.port);session.ambeHost="127.0.0.1";session.ambePort=String(ambe.port);session.exclusive=true
  session.toggleTransmit();XCTAssertEqual(session.transmitting,false)
  session.selectMode(.fusion);session.connect()
  var deadline=Date().addingTimeInterval(4)
  while !session.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.canTransmit,true,session.log)
  mic.granted=false;session.toggleTransmit()
  XCTAssertEqual(session.transmitting,false);XCTAssertEqual(transmitted.count,0)
  mic.granted=true;mic.deferPermission=true;session.toggleTransmit();session.stopTransmit();mic.permissionReply?(true)
  XCTAssertEqual(session.transmitting,false);XCTAssertEqual(transmitted.count,0)
  mic.deferPermission=false
  session.toggleMicrophoneTest();mic.emit([Float](repeating:0.1,count:160))
  try await Task.sleep(nanoseconds:50_000_000)
  XCTAssertEqual(session.microphoneTesting,true);XCTAssertEqual(session.microphoneLevel,0.199526,accuracy:0.001)
  session.toggleMicrophoneTest();XCTAssertEqual(transmitted.count,0)
  session.toggleTransmit();XCTAssertEqual(session.transmitting,true,session.log)
  for _ in 0..<7 {
   mic.emit([Float](repeating:0.1,count:160))
   try await Task.sleep(nanoseconds:20_000_000)
  }
  session.stopTransmit()
  deadline=Date().addingTimeInterval(3)
  while (session.transmitting || transmitted.count<4),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.transmitting,false,session.log)
  XCTAssertEqual(encodeRequests,10,session.log)
  XCTAssertEqual(transmitted.count,4,session.log)
  XCTAssertEqual(try transmitted.map{try Packets.receive($0).fi},[0,1,1,2])
  XCTAssertEqual(session.encodedFrames,10)
  XCTAssertEqual(mic.running,false)
  // Model a real tap callback delivering 400 ms of audio at once.
  transmitted=[];let beforeBurst=encodeRequests
  session.toggleTransmit()
  for _ in 0..<20 {mic.emit([Float](repeating:0.1,count:160))}
  deadline=Date().addingTimeInterval(2)
  while encodeRequests<beforeBurst+20,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.transmitting,true,session.log)
  session.stopTransmit()
  deadline=Date().addingTimeInterval(2)
  while (session.transmitting || transmitted.count<6),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(encodeRequests,beforeBurst+20,session.log)
  XCTAssertEqual(session.active,true,session.log);XCTAssertEqual(disconnects,0)
  XCTAssertEqual(try transmitted.map{try Packets.receive($0).fi},[0,1,1,1,1,2])
  // A real encoder failure ends TX and resets only the AMBE device.
  transmitted=[];malformedNext=true
  session.toggleTransmit();mic.emit([Float](repeating:0.1,count:160))
  deadline=Date().addingTimeInterval(2)
  while (resetRequests<2 || !session.canTransmit),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(resetRequests,2,session.log)
  XCTAssertEqual(session.active,true,session.log);XCTAssertEqual(session.canTransmit,true,session.log)
  XCTAssertEqual(session.transmitting,false);XCTAssertEqual(disconnects,0)
  XCTAssertEqual(ysf.clients.count,1,"YSF socket must remain unchanged during AMBE recovery")
  XCTAssertEqual(try transmitted.map{try Packets.receive($0).fi},[0,2])
  // A capture engine may start successfully but never deliver its first tap.
  // Retry only that microphone, keeping the stream and AMBE connection intact.
  transmitted=[]
  let startsBefore=mic.startCount,resetsBefore=resetRequests
  session.toggleTransmit()
  let staleCapture=mic.samples
  deadline=Date().addingTimeInterval(1.8)
  while mic.startCount<startsBefore+2,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(mic.startCount,startsBefore+2,session.log)
  XCTAssertEqual(session.transmitting,true,session.log)
  XCTAssertEqual(resetRequests,resetsBefore,"A missing microphone tap must not reset the vocoder during retry")
  staleCapture?([Float](repeating:0.9,count:160))
  for _ in 0..<10 {mic.emit([Float](repeating:0.1,count:160))}
  deadline=Date().addingTimeInterval(1)
  while session.encodedFrames<10,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.encodedFrames,10,"Callbacks from the stopped first capture must be ignored")
  session.stopTransmit()
  deadline=Date().addingTimeInterval(2)
  while session.transmitting || transmitted.count<4,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(try transmitted.map{try Packets.receive($0).fi},[0,1,1,2],"Retry must not create a new stream header")
  // A second silent startup still ends at the original deadline, with no loop.
  let silentStarts=mic.startCount
  session.toggleTransmit()
  deadline=Date().addingTimeInterval(3)
  while session.transmitting || !session.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(mic.startCount,silentStarts+2,"Only one microphone retry is allowed")
  XCTAssertEqual(session.transmitting,false,session.log)
  XCTAssertEqual(session.active,true,session.log)
  XCTAssertEqual(session.log.contains("Geen microfoonaudio ontvangen"),true)
  // Disconnect during PTT emits exactly one terminator and stops capture.
  let startsAtDisconnect=mic.startCount
  transmitted=[];session.toggleTransmit();session.disconnect()
  try await Task.sleep(nanoseconds:1_200_000_000)
  XCTAssertEqual(mic.startCount,startsAtDisconnect+1,"Disconnect must cancel the pending microphone retry")
  XCTAssertEqual(session.active,false);XCTAssertEqual(session.transmitting,false);XCTAssertEqual(mic.running,false)
  XCTAssertEqual(try transmitted.map{try Packets.receive($0).fi},[0,2])
 }
}

final class StubMicrophone:MicrophoneSource {
 var granted=true,deferPermission=false,running=false
 var startCount=0
 var permissionReply:((Bool)->Void)?
 var samples:(([Float])->Void)?
 func requestAccess(_ completion:@escaping(Bool)->Void){if deferPermission {permissionReply=completion}else{completion(granted)}}
 func start(onSamples:@escaping([Float])->Void,onError:@escaping(String)->Void)throws{startCount += 1;running=true;samples=onSamples}
 func emit(_ frame:[Float]){if running{samples?(frame)}}
 func stop(){running=false;samples=nil}
}
