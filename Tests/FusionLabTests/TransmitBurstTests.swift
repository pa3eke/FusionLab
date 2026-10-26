import Foundation

extension ProtocolTests {
 func testBatchedMicrophoneAudio() throws {
  let tx=FusionTransmitter(),base=Date(timeIntervalSince1970:1000)
  var wire=[Data](),messages=[String](),current=base
  tx.onNetwork={wire.append($0)};tx.onError={messages.append($0)}
  tx.onAMBE={_ in tx.receive(Packets.ambe(Data(repeating:0,count:7)),now:current)}
  tx.start(call:"PA3EKE",now:base)
  // A single large audio tap produces more than the old ten-frame capacity.
  for _ in 0..<20 {tx.append([Float](repeating:0.1,count:160))}
  XCTAssertEqual(tx.phase,.recording);XCTAssertEqual(messages,[])
  XCTAssertEqual(tx.inputHighWaterMark,20)
  for i in 0..<24 {current=base.addingTimeInterval(Double(i)*0.021);tx.tick(now:current)}
  tx.stop(now:current)
  for i in 24..<55 {current=base.addingTimeInterval(Double(i)*0.021);tx.tick(now:current)}
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(tx.encodedCount,20)
  XCTAssertEqual(tx.droppedInputCount,0);XCTAssertEqual(messages,[])
  XCTAssertEqual(try wire.map{try Packets.receive($0).fi},[0,1,1,1,1,2])
  // An abnormally large burst is bounded and counted; it must not disconnect.
  wire=[];tx.start(call:"PA3EKE",now:base)
  for _ in 0..<100 {tx.append([Float](repeating:0.1,count:160))}
  XCTAssertEqual(tx.phase,.recording)
  XCTAssertEqual(tx.inputHighWaterMark,FusionTransmitter.maximumBufferedFrames)
  XCTAssertEqual(tx.droppedInputCount,100-FusionTransmitter.maximumBufferedFrames)
  tx.stop(now:base)
  for i in 0..<65 {current=base.addingTimeInterval(Double(i)*0.021);tx.tick(now:current)}
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(messages,[])
  XCTAssertEqual(tx.encodedCount,FusionTransmitter.maximumBufferedFrames)
  XCTAssertEqual(try Packets.receive(wire.last!).fi,2)
 }
}
