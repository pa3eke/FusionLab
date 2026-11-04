import Foundation

extension ProtocolTests {
 func testReceiveMuteOutputGain(){
  let output=AudioOutput(queue:DispatchQueue(label:"FusionLab.mute-test"))
  output.volume=0.62
  XCTAssertEqual(abs(output.outputGain-0.62)<0.001,true)
  output.setMuted(true);XCTAssertEqual(output.outputGain,0)
  output.volume=0.35;XCTAssertEqual(output.outputGain,0,"Volume changes must not unmute playback")
  output.resetPlayback();XCTAssertEqual(output.outputGain,0,"Reset must preserve mute")
  output.setMuted(false);XCTAssertEqual(abs(output.outputGain-0.35)<0.001,true,"Unmute restores the chosen gain")
  output.setMuted(true);output.stop();XCTAssertEqual(output.outputGain,0)
  output.setMuted(false);XCTAssertEqual(abs(output.outputGain-0.35)<0.001,true)
 }
 @MainActor func testReceiveMuteAndXKeys() throws {
  let defaults=UserDefaults.standard,saved=defaults.object(forKey:"xkeys.settings.v1"),savedMode=defaults.object(forKey:"digitalMode")
  let hid=StubXKeys(),s=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),xkeysTransport:hid)
  defer{s.stopXKeys();defaults.set(saved,forKey:"xkeys.settings.v1");defaults.set(savedMode,forKey:"digitalMode")}
  var settings=XKeysSettings();settings.enabled=true;settings.bindings[3]=XKeysBinding(action:.audioMute)
  let restored=try JSONDecoder().decode(XKeysSettings.self,from:JSONEncoder().encode(settings))
  XCTAssertEqual(restored.bindings[3].action,.audioMute)
  XCTAssertEqual(restored.bindings[0].action,.ptt,"Existing mappings remain valid")
  s.xkeys.settings=restored;s.startXKeys();s.volume=0.62
  XCTAssertEqual(s.receiveMuted,false)
  hid.emit([3]);XCTAssertEqual(s.receiveMuted,true)
  hid.emit([3]);hid.emit([]);XCTAssertEqual(s.receiveMuted,true,"Held/released key must not toggle a second time")
  XCTAssertEqual(s.volume,0.62)
  s.volume=0.35;hid.emit([3]);hid.emit([])
  XCTAssertEqual(s.receiveMuted,false);XCTAssertEqual(s.volume,0.35)
  s.receiveMuted=true;s.selectMode(.dmr);XCTAssertEqual(s.receiveMuted,true,"Mode selection preserves mute")
  s.receiveMuted=false;XCTAssertEqual(s.volume,0.35)
  XCTAssertEqual(s.active,false);XCTAssertEqual(s.transmitting,false,"Mute never starts a radio stream")
 }
}
