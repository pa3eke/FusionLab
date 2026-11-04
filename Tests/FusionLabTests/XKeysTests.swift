import Foundation

final class StubXKeys:XKeysTransport {
 let source="xkeys:fixture"
 var onDevice:((XKeysDeviceInfo,String)->Void)?
 var onRemoval:((String)->Void)?
 var onReport:((String,Data,UInt32)->Void)?
 var onError:((String?,String)->Void)?
 var frame=[XKeysLEDState](),current=Set<Int>(),started=false
 func start(){started=true;onDevice?(XKeysDeviceInfo(source:source,productID:1029,firmware:38,mode:2,compatible:true),"Verbonden");requestState()}
 func stop(){if started {started=false;onRemoval?(source)}}
 func requestState(){if started {emit(current)}}
 func setLEDs(_ frame:[XKeysLEDState]){self.frame=frame}
 func emit(_ keys:Set<Int>){current=keys;onReport?(source,Self.report(keys),0)}
 static func report(_ keys:Set<Int>)->Data {var bytes=[UInt8](repeating:0,count:32);for key in keys {bytes[2+key/6] |= 1<<(key%6)};return Data(bytes)}
}
extension ProtocolTests {
 func testXKeysReportsAndPTTRequests(){
  XCTAssertEqual(XKeysReport.keys(Data([1,2,0,0,0,0])+Data(repeating:0,count:26)),[])
  for key in 0..<24 {
   XCTAssertEqual(XKeysReport.keys(StubXKeys.report([key])),[key])
   XCTAssertEqual(XKeysReport.ledIndex(key),UInt8((key/6)*8+key%6))
   var input=XKeysInputHandler()
   XCTAssertEqual(input.events([]).count,0)
   XCTAssertEqual(input.events([key]).count,1)
   XCTAssertEqual(input.events([key]).count,0)
   XCTAssertEqual(input.events([]).first?.down,false)
   input.reset();XCTAssertEqual(input.events([key]).count,0)
   XCTAssertEqual(input.events([key]).count,0)
   _=input.events([]);XCTAssertEqual(input.events([key]).first?.down,true)
  }
  XCTAssertEqual(XKeysReport.keys(StubXKeys.report(Set(0..<24))),Set(0..<24))
  for length in [0,1,31,34] {XCTAssertNil(XKeysReport.keys(Data(repeating:0,count:length)))}
  XCTAssertNil(XKeysReport.keys(StubXKeys.report([]),reportID:1))
  var bad=StubXKeys.report([]);bad[1]=214;XCTAssertNil(XKeysReport.keys(bad));bad[1]=224;XCTAssertNil(XKeysReport.keys(bad))
  bad[1]=0;bad[2]=0x80;XCTAssertNil(XKeysReport.keys(bad))
  XCTAssertEqual(XKeysReport.keys(Data([0])+StubXKeys.report([23])),[23])
  XCTAssertEqual(XKeysReport.output(181,61,1).count,35)
  var requests=PTTRequests()
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.hold,canStart:true,engaged:false),.start)
  XCTAssertEqual(requests.event(source:"keyboard",pressed:true,mode:.hold,canStart:true,engaged:true),.none)
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:false,mode:.hold,canStart:false,engaged:true),.none)
  XCTAssertEqual(requests.sources,["keyboard"])
  XCTAssertEqual(requests.event(source:"keyboard",pressed:false,mode:.hold,canStart:false,engaged:true),.stop)
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.toggle,canStart:true,engaged:false),.start)
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.toggle,canStart:true,engaged:true),.none)
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:false,mode:.toggle,canStart:false,engaged:true),.none)
  XCTAssertEqual(requests.event(source:"xkeys:b",pressed:true,mode:.toggle,canStart:true,engaged:true),.none)
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.toggle,canStart:true,engaged:true),.none)
  XCTAssertEqual(requests.sources,["xkeys:b"])
  XCTAssertEqual(requests.release(prefix:"xkeys:",engaged:true),.stop)
  XCTAssertEqual(requests.hasHeld,false,"Removed devices cannot leave a permanent held-key mode interlock")
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.hold,canStart:true,engaged:false),.start)
  requests.transmissionEnded()
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.hold,canStart:true,engaged:false),.none,"Timeout cannot restart a held key")
  _=requests.event(source:"xkeys:a",pressed:false,mode:.hold,canStart:true,engaged:false)
  XCTAssertEqual(requests.event(source:"xkeys:a",pressed:true,mode:.hold,canStart:true,engaged:false),.start)
 }
 @MainActor func testXKeysControllerAndStorage() throws {
  let name="FusionLab.XKeysTests.\(UUID())",defaults=UserDefaults(suiteName:name)!
  defer{defaults.removePersistentDomain(forName:name)}
  var settings=XKeysSettings();settings.enabled=true;settings.bindings[23]=XKeysBinding(action:.ptt,mode:.toggle);settings.save(defaults)
  XCTAssertEqual(XKeysSettings.load(defaults),settings)
  let hid=StubXKeys(),controller=XKeysController(transport:hid,defaults:defaults)
  var actions=[(String,Int,Bool)](),releases=[String]()
  controller.onAction={source,key,_,down in actions.append((source,key,down))};controller.onRelease={releases.append($0)}
  controller.start();XCTAssertEqual(controller.connected,true)
  hid.emit([23]);hid.emit([23]);hid.emit([])
  XCTAssertEqual(actions.count,2);XCTAssertEqual(actions.first?.1,23);XCTAssertEqual(controller.lastKey,23)
  XCTAssertEqual(controller.pressed,[]);XCTAssertEqual(controller.eventCount,2)
  controller.setTransmitting(true)
  XCTAssertEqual(hid.frame[23],XKeysLEDState(red:1));XCTAssertEqual(hid.frame[0],XKeysLEDState(red:1));XCTAssertEqual(hid.frame[20],XKeysLEDState())
  controller.setTransmitting(false);XCTAssertEqual(hid.frame[23],XKeysLEDState(blue:1))
  controller.testMode=true;let before=actions.count
  hid.emit([0]);hid.emit([]);XCTAssertEqual(actions.count,before);XCTAssertEqual(controller.eventCount,4)
  controller.testMode=false
  controller.setSuspended(true);hid.emit([0]);XCTAssertEqual(actions.count,before)
  controller.setSuspended(false);hid.emit([0]);XCTAssertEqual(actions.count,before,"A key held at wake is baseline only")
  hid.emit([]);hid.emit([0]);XCTAssertEqual(actions.last?.2,true)
  hid.onReport?(hid.source,Data([1]),0)
  XCTAssertEqual(controller.status.contains("Ongeldig"),true);XCTAssertEqual(releases.last,hid.source+":")
  controller.settings.enabled=false;XCTAssertEqual(controller.connected,false);XCTAssertEqual(releases.contains("xkeys:"),true)
  XCTAssertEqual(XKeysSettings.load(defaults).enabled,false)
  controller.restoreDefaults();XCTAssertEqual(controller.settings.bindings,XKeysSettings.defaults)
  controller.stop()
 }
 @MainActor func testXKeysCentralPTTLifecycle() async throws {
  let hid=StubXKeys(),key=StubPTTKey(),mic=StubMicrophone(),ambe=try MockUDP(),ysf=try MockUDP()
  try await ambe.start();try await ysf.start()
  ambe.reply={data in
   guard let p=Packets.dv3k(data) else{return nil}
   if p.type==2 {return Packets.ambe(Data(repeating:0,count:7))}
   guard p.type==0,let field=p.body.first else{return nil}
   if field==0x33 {return Data([0x61,0,1,0,0x39])}
   if field==0x30 {return Data([0x61,0,2,0,0x30,65])}
   return Data([0x61,0,2,0,field,0])
  }
  ysf.reply={data in data.prefix(4)==Data("YSFP".utf8) ? data:nil}
  let defaults=UserDefaults.standard,keys=["call","host","port","ambeHost","ambePort","digitalMode","pttKeyMode","pttButtonToggle","xkeys.settings.v1"]
  let saved=keys.map{defaults.object(forKey:$0)}
  let s=RadioSession(microphone:mic,pttKey:key,passwordStore:MemoryDMRPasswordStore(),xkeysTransport:hid)
  defer{s.stopXKeys();s.disconnect();ambe.stop();ysf.stop();for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  s.volume=0;s.selectMode(.fusion);s.host="127.0.0.1";s.port=String(ysf.port);s.ambeHost="127.0.0.1";s.ambePort=String(ambe.port);s.exclusive=true
  s.pttKeyMode = .hold;s.pttButtonToggle=false
  var settings=XKeysSettings();settings.enabled=true;settings.bindings[1]=XKeysBinding(action:.ptt,mode:.toggle);settings.bindings[2]=XKeysBinding(action:.stopTX)
  s.xkeys.settings=settings;s.startXKeys()
  hid.emit([0]);XCTAssertEqual(s.transmitting,false,"HID cannot start TX on an unready connection");hid.emit([])
  s.connect()
  var deadline=Date().addingTimeInterval(4)
  while !s.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(s.canTransmit,true,s.log)
  func settle() async throws {
   let end=Date().addingTimeInterval(2)
   while s.transmitting || s.preparingTransmit,Date()<end {try await Task.sleep(nanoseconds:20_000_000)}
  }
  // Hold + existing keypad + GUI share one central stream and independent ownership.
  hid.emit([0]);XCTAssertEqual(s.transmitting,true,s.log)
  for _ in 0..<4 {mic.emit(Array(repeating:0.1,count:160));try await Task.sleep(nanoseconds:20_000_000)}
  s.handleFocusLoss();XCTAssertEqual(s.transmitting,true,"HID PTT survives app focus loss")
  key.emit(true);hid.emit([]);XCTAssertEqual(s.transmitting,true,"HID release must not stop an active keypad request")
  s.handlePTTButton(pressed:true);key.emit(false);XCTAssertEqual(s.transmitting,true)
  s.handlePTTButton(pressed:false);try await settle();XCTAssertEqual(s.transmitting,false)
  // A latched HID request survives key-up; repeats do not switch it off.
  hid.emit([1]);hid.emit([1]);hid.emit([]);XCTAssertEqual(s.transmitting,true)
  key.emit(true);hid.stop();XCTAssertEqual(s.transmitting,true,"USB removal releases only HID sources")
  key.emit(false);try await settle();XCTAssertEqual(s.transmitting,false)
  XCTAssertEqual(s.canSwitchMode,true)
  // Reconnect with a held PTT key never resumes TX; release/fresh press required.
  hid.current=[0];hid.start();hid.emit([0]);XCTAssertEqual(s.transmitting,false)
  hid.emit([]);hid.emit([0]);XCTAssertEqual(s.transmitting,true)
  s.xkeys.settings.enabled=false;try await settle();XCTAssertEqual(s.transmitting,false)
  s.xkeys.settings.enabled=true;hid.emit([])
  hid.emit([1]);hid.emit([]);XCTAssertEqual(s.transmitting,true)
  // Lock/sleep inhibits every TX source and requires new physical input afterwards.
  s.setPTTInputInhibited(true);try await settle();XCTAssertEqual(s.transmitting,false)
  hid.emit([0]);XCTAssertEqual(s.transmitting,false)
  s.setPTTInputInhibited(false);hid.emit([0]);XCTAssertEqual(s.transmitting,false)
  hid.emit([]);hid.emit([0]);XCTAssertEqual(s.transmitting,true)
  hid.emit([0,2]);try await settle();XCTAssertEqual(s.transmitting,false,"Emergency stop clears all requests")
  hid.emit([])
  let volume=s.volume
  hid.emit([12]);hid.emit([12]);hid.emit([])
  XCTAssertEqual(s.volume,volume+0.05)
  hid.emit([0,2]);XCTAssertEqual(s.transmitting,false,"Emergency stop wins over PTT in the same HID report");hid.emit([])
  // Invalid input while latched fails closed, without changing network state.
  hid.emit([1]);hid.emit([]);XCTAssertEqual(s.transmitting,true)
  hid.onReport?(hid.source,Data([1,2]),0);try await settle()
  XCTAssertEqual(s.transmitting,false);XCTAssertEqual(s.active,true)
  s.disconnect();deadline=Date().addingTimeInterval(2)
  while s.active,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
 }
}
