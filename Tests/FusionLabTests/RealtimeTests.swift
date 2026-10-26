import Foundation
import Darwin

extension ProtocolTests {
 @MainActor func testEchoBurstPreservesSpeech() async throws {
  let queue=DispatchQueue(label:"FusionLabTests.echoBurst")
  let loop=TransmissionLoop(queue:queue)
  var expected=[Data](),decoded=[Data](),times=[Date]()
  var stats=TransmissionLoop.ReceptionMetrics()
  loop.onReception={stats=$0}
  loop.onAMBE={packet in
   decoded.append(Data(packet.suffix(7)));times.append(Date())
   loop.receivePCM(Data([0x61,1,66,2,0,160])+Data(repeating:0,count:320))
  }
  loop.setEnabled(true)
  loop.receiveNetworkAudio(Packets.transmit(call:"PA3EKE",sequence:0,fi:0))
  // A 6.3-second echo delivered as one network burst. The previous one-second
  // buffer silently removed most of these frames before the decoder saw them.
  for packet in 0..<63 {
   let frames=(0..<5).map { offset -> Data in
    let value=packet*5+offset
    return Data([UInt8(value>>8),UInt8(value&255),0x31,0x45,0x67,0x89,0x80])
   }
   expected.append(contentsOf:frames)
   loop.receiveNetworkAudio(Packets.transmit(call:"PA3EKE",sequence:packet+1,fi:1,voice:frames))
  }
  loop.receiveNetworkAudio(Packets.transmit(call:"PA3EKE",sequence:64,fi:2))
  let deadline=Date().addingTimeInterval(9)
  while stats.decoded<315,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  let result=queue.sync{(decoded,times)}
  XCTAssertEqual(result.0,expected,"A fast echo must preserve every block in its original order")
  XCTAssertEqual(stats.received,315);XCTAssertEqual(stats.submitted,315);XCTAssertEqual(stats.decoded,315)
  XCTAssertEqual(stats.discarded,0);XCTAssertEqual(stats.buffered,0);XCTAssertEqual(stats.busy,false)
  XCTAssertEqual(stats.highWater>=310,true)
  if let first=result.1.first,let last=result.1.last {
   XCTAssertEqual(last.timeIntervalSince(first)>6,true,"Burst must be decoded at 20 ms per block")
  }
  loop.reset();queue.sync{}
 }
 @MainActor func testAudioTimingWhileInterfaceIsBlocked() async throws {
  let queue=DispatchQueue(label:"FusionLabTests.realtime")
  let loop=TransmissionLoop(queue:queue),token=UUID()
  var packets=[Data](),finish:TransmissionLoop.Metrics?,messages=[String]()
  var played=0
  loop.onAMBE={packet in
   if packet[3]==2 {loop.receiveEncoded(Packets.ambe(Data(repeating:0,count:7)))}
   else {loop.receivePCM(Data([0x61,1,66,2,0,160])+Data(repeating:0,count:320))}
  }
  loop.onNetwork={packets.append($0)}
  loop.onFinished={finish=$0}
  loop.onError={messages.append($0)}
  loop.onPCM={_ in played += 1}
  loop.setEnabled(true);loop.prepareCapture(token:token,gain:0,forTX:true);loop.start(call:"PA3EKE")
  // Actual PUC2 tap delivery is 4800 samples/48kHz: 5 frames every 100 ms.
  for batch in 0..<20 {
   queue.asyncAfter(deadline:.now()+Double(batch)*0.1,execute:DispatchWorkItem{
    for _ in 0..<5 {loop.appendMicrophone([Float](repeating:0.1,count:160),token:token)}
   })
  }
  queue.asyncAfter(deadline:.now()+2.05,execute:DispatchWorkItem{loop.stop()})
  // A blocked UI must not stall input, vocoder replies, packet timing or playout.
  usleep(650_000)
  let earlyCount=queue.sync{packets.count}
  XCTAssertEqual(earlyCount>=5,true,"Audio stopped while the UI was busy: \(earlyCount) packets")
  let deadline=Date().addingTimeInterval(3)
  while finish==nil,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(finish?.inputCount,100)
  XCTAssertEqual(finish?.encodedCount,100)
  XCTAssertEqual(finish?.droppedInputCount,0)
  XCTAssertEqual(finish?.networkCount,22)
  XCTAssertEqual(messages,[])
  let wire=queue.sync{packets}
  XCTAssertEqual(wire.count,22)
  XCTAssertEqual(try Packets.receive(wire.last!).fi,2)
  // Actual echo packets, AMBE decoding and PCM delivery also continue with
  // the UI blocked, not just playback of already-decoded audio.
  loop.receiveNetworkAudio(Packets.transmit(call:"PA3EKE",sequence:0,fi:0))
  for batch in 0..<10 {
   queue.asyncAfter(deadline:.now()+Double(batch)*0.1,execute:DispatchWorkItem{
    loop.receiveNetworkAudio(Packets.transmit(call:"PA3EKE",sequence:batch+1,fi:1,voice:Array(repeating:Data(repeating:0,count:7),count:5)))
   })
  }
  usleep(650_000)
  XCTAssertEqual(queue.sync{played}>=20,true,"Echo decoding stopped while UI was blocked")
  let rxDeadline=Date().addingTimeInterval(2)
  while queue.sync(execute:{played})<50,Date()<rxDeadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(queue.sync{played},50)
  loop.setEnabled(false);loop.reset();queue.sync{}
 }
}
