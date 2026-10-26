import Foundation

extension ProtocolTests {
 func testMicrophoneGainAndClipping() {
  let unity=MicrophoneGain.process([0.1,-0.2,0],decibels:0)
  XCTAssertEqual(unity.samples,[0.1,-0.2,0]);XCTAssertEqual(unity.peak,0.2)
  let boost=MicrophoneGain.process([0.1,-0.2],decibels:20)
  XCTAssertEqual(boost.samples[0],Float(32767)/32768,accuracy:0.00001)
  XCTAssertEqual(boost.samples[1],-1);XCTAssertEqual(boost.clipped,true)
  let six=MicrophoneGain.process([0.1,-0.1],decibels:6)
  XCTAssertEqual(six.peak,0.199526,accuracy:0.00001)
  XCTAssertEqual(six.rms,0.199526,accuracy:0.00001)
  XCTAssertEqual(six.clipped,false)
  let quiet=MicrophoneGain.process([0.5],decibels:-6)
  XCTAssertEqual(quiet.peak,0.250594,accuracy:0.00001)
  XCTAssertEqual(MicrophoneGain.process([],decibels:12).rms,0)
  XCTAssertEqual(MicrophoneGain.process([.nan,.infinity],decibels:.nan).samples,[0,0])
  let pcm=Packets.speech(six.samples+[Float](repeating:0,count:158))
  XCTAssertEqual(Packets.pcm(pcm)![0],six.samples[0],accuracy:0.00004)
 }
}
