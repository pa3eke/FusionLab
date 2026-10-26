import Foundation

extension ProtocolTests {
 func testReceiveEQ(){
  func tone(_ frequency:Double)->[Float] {
   (0..<160).map{Float(0.05*sin(2 * Double.pi * frequency * Double($0)/8000))}
  }
  func rms(_ values:[Float])->Double {sqrt(values.reduce(0){$0+Double($1)*Double($1)}/Double(values.count))}
  func response(_ settings:ReceiveEQSettings,_ frequency:Double)->Double {
   var eq=ReceiveEQ();eq.configure(settings)
   let input=tone(frequency)
   var output=input
   for _ in 0..<50 {output=eq.process(input)}
   return 20*log10(rms(output)/rms(input))
  }
  var flat=ReceiveEQ()
  let original=tone(1000)
  XCTAssertEqual(flat.process(original),original,"Neutral EQ must be sample-exact")
  for gain in [-6.0,6.0] {
   XCTAssertEqual(abs(response(.init(low:gain),100)-gain)<0.3,true,"Low shelf gain at 100 Hz")
   XCTAssertEqual(abs(response(.init(low:gain),3200))<0.1,true,"Low shelf must leave high frequencies alone")
   XCTAssertEqual(abs(response(.init(mid:gain),1000)-gain)<0.1,true,"Mid peak gain at 1 kHz")
   XCTAssertEqual(abs(response(.init(mid:gain),100))<0.2,true,"Mid band must leave low frequencies alone")
   XCTAssertEqual(abs(response(.init(high:gain),3200)-gain)<0.4,true,"High shelf gain at 3.2 kHz")
   XCTAssertEqual(abs(response(.init(high:gain),100))<0.1,true,"High shelf must leave low frequencies alone")
  }
  // Filter state and crossfade must remain finite during repeated live edits.
  var eq=ReceiveEQ(),agc=ReceiveAGC()
  for i in 0..<200 {
   let gain=i%2==0 ? 12.0:-12.0
   eq.configure(.init(low:gain,mid:-gain,high:gain))
   let shaped=eq.process(original)
   XCTAssertEqual(shaped.allSatisfy{$0.isFinite},true)
   XCTAssertEqual(agc.process(shaped).allSatisfy{abs($0)<=0.85001},true)
  }
  eq.configure(.init());_ = eq.process(original)
  XCTAssertEqual(eq.process(original),original,"Reset to neutral must remove all coloration after the fade")
  eq.reset();XCTAssertEqual(eq.process(original),original)
  XCTAssertEqual(ReceiveEQSettings(low:.nan,mid:99,high:-99).normalized,.init(low:0,mid:12,high:-12))
  let defaults=UserDefaults(suiteName:"FusionLab.EQTests.\(UUID().uuidString)")!
  let settings=ReceiveEQSettings(low:-3,mid:2,high:4)
  settings.save(defaults);XCTAssertEqual(ReceiveEQSettings.load(defaults),settings)
  for key in ["receiveEQLow","receiveEQMid","receiveEQHigh"]{defaults.removeObject(forKey:key)}
 }
}
