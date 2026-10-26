import Foundation

extension ProtocolTests {
 func testReceiveAGC(){
  func tone(_ amplitude:Float)->[Float] {(0..<160).map{amplitude*sin(2 * .pi * 400 * Float($0)/8000)}}
  func rms(_ samples:[Float])->Float {sqrt(samples.reduce(0){$0+$1*$1}/Float(samples.count))}
  var soft=ReceiveAGC(),loud=ReceiveAGC()
  var quietOutput=[Float](),loudOutput=[Float]()
  for _ in 0..<200 {
   quietOutput=soft.process(tone(0.04));loudOutput=loud.process(tone(0.4))
  }
  XCTAssertEqual(rms(quietOutput),0.14,accuracy:0.005)
  XCTAssertEqual(rms(loudOutput),0.14,accuracy:0.005)
  // A suddenly loud station after gain has risen must be safe immediately.
  let sudden=soft.process(tone(1))
  XCTAssertEqual(sudden.allSatisfy{abs($0)<=0.85001},true)
  for _ in 0..<15 {_=soft.process(tone(1))}
  XCTAssertEqual(rms(soft.process(tone(1))),0.14,accuracy:0.005)
  // No escalating background hiss or upward gain search during pauses.
  let gainBefore=loud.gain
  for _ in 0..<200 {_=loud.process(tone(0.001))}
  XCTAssertEqual(loud.gain,gainBefore,accuracy:0.00001)
  var silence=ReceiveAGC()
  for _ in 0..<100 {XCTAssertEqual(silence.process(Array(repeating:0,count:160)),Array(repeating:Float(0),count:160))}
  XCTAssertEqual(silence.gain,1)
  XCTAssertEqual(silence.process([.nan,.infinity,-.infinity]),[0,0,0])
  XCTAssertEqual(silence.process([]),[])
  var capped=ReceiveAGC()
  for _ in 0..<300 {_=capped.process(tone(0.005))}
  XCTAssertEqual(capped.gain<=8,true)
  capped.reset();XCTAssertEqual(capped.gain,1)
 }
}
