import Foundation

final class StubPTTKey:PTTKeyRegistration {
 var registered=false,failed=false
 var onKey:((Bool)->Void)?
 func setActive(_ active:Bool){registered=active && !failed}
 func emit(_ pressed:Bool){if registered {onKey?(pressed)}}
}

extension ProtocolTests {
 func testSelectedTransmitLimits() throws {
  let dmr=DMRVoiceSettings(source:2040001,destination:9990,peer:2040001,slot:2,colorCode:1,privateCall:true)
  let base=Date(timeIntervalSince1970:1000)
  for profile in [VoiceProfile.fusion,.dmr(dmr),.nxdn(NXDNVoiceSettings(source:41007,destination:204,ran:1))] {
   for limit in TransmitLimit.allCases {
    let tx=FusionTransmitter()
    var wire=[Data](),inputs=0
    tx.onNetwork={wire.append($0)};tx.onAMBE={_ in inputs += 1}
    tx.start(call:"PA0TEST",profile:profile,limit:limit,now:base,uptime:1000)
    XCTAssertEqual(tx.remainingSeconds(at:1000),limit.rawValue)
    tx.append(Array(repeating:0.1,count:160));tx.tick(now:base,uptime:1000)
    // A second start must not extend an already active two-minute stream.
    tx.start(call:"PA0TEST",profile:profile,limit:.threeMinutes,now:base,uptime:1100)
    let end=1000+Double(limit.rawValue)
    XCTAssertEqual(tx.remainingSeconds(at:end-10),10)
    tx.stop(now:base)
    tx.tick(now:base,uptime:end-0.001)
    XCTAssertEqual(tx.phase,.draining);XCTAssertEqual(tx.remainingSeconds(at:end-0.001),1)
    let before=inputs
    tx.tick(now:base.addingTimeInterval(-86400),uptime:end)
    XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(tx.timedOut,true)
    XCTAssertEqual(tx.remainingSeconds(at:end),0);XCTAssertEqual(inputs,before)
    XCTAssertEqual(wire.count,2,"Deadline sends one header and one terminator, no late buffered audio")
    if case .fusion=profile {XCTAssertEqual(try wire.map{try Packets.receive($0).fi},[0,2])}
    else if case .dmr=profile {XCTAssertEqual(wire.compactMap{DMRPackets.receive($0)?.kind},[0,2])}
    else {XCTAssertEqual(wire.compactMap{NXDNPackets.receive($0)?.kind},[0,2])}
   }
  }
 }
 func testPTTKeyModesAndDeadline() throws {
  var key=PTTKeyState()
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:true,engaged:false),.start)
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:true,engaged:true),.none)
  XCTAssertEqual(key.event(pressed:false,mode:.hold,canStart:false,engaged:true),.stop)
  XCTAssertEqual(key.event(pressed:true,mode:.toggle,canStart:true,engaged:false),.start)
  XCTAssertEqual(key.event(pressed:false,mode:.toggle,canStart:false,engaged:true),.none)
  XCTAssertEqual(key.event(pressed:true,mode:.toggle,canStart:false,engaged:true),.stop)
  key.reset()
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:false,engaged:false),.none)
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:true,engaged:false),.none)
  _=key.event(pressed:false,mode:.hold,canStart:true,engaged:false)
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:true,engaged:false),.start)
  key.transmissionEnded() // timeout while the physical key remains held
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:true,engaged:false),.none)
  XCTAssertEqual(key.event(pressed:false,mode:.hold,canStart:true,engaged:false),.none)
  XCTAssertEqual(key.event(pressed:true,mode:.hold,canStart:true,engaged:false),.start)
  key.reset()
  XCTAssertEqual(key.event(pressed:true,mode:.off,canStart:true,engaged:false),.none)

  let tx=FusionTransmitter(),base=Date(timeIntervalSince1970:1000)
  var wire=[Data](),inputs=0,errors=[String]()
  tx.onNetwork={wire.append($0)};tx.onAMBE={_ in inputs += 1};tx.onError={errors.append($0)}
  tx.start(call:"PA3EKE",now:base,uptime:1000)
  for _ in 0..<25 {tx.append([Float](repeating:0.1,count:160))}
  tx.tick(now:base,uptime:1000)
  XCTAssertEqual(tx.remainingSeconds(at:1000),180)
  XCTAssertEqual(tx.remainingSeconds(at:1179.9),1)
  // Move the wall clock backwards while draining with unanswered AMBE input.
  tx.stop(now:base)
  let before=inputs
  tx.tick(now:base.addingTimeInterval(-86400),uptime:1180)
  XCTAssertEqual(tx.phase,.idle);XCTAssertEqual(tx.timedOut,true)
  XCTAssertEqual(inputs,before);XCTAssertEqual(errors,[])
  XCTAssertEqual(try wire.map{try Packets.receive($0).fi},[0,2])
  tx.receive(Packets.ambe(Data(repeating:0,count:7)))
  tx.tick(now:base,uptime:1200);XCTAssertEqual(wire.count,2)
 }

 @MainActor func testGlobalPTTLifecycle() async throws {
  let ambe=try MockUDP(),ysf=try MockUDP(),mic=StubMicrophone(),key=StubPTTKey()
  try await ambe.start();try await ysf.start()
  ambe.reply={d in
   guard let p=Packets.dv3k(d) else{return nil}
   if p.type==2 {return Packets.ambe(Data(repeating:0,count:7))}
   guard p.type==0,let field=p.body.first else{return nil}
   if field==0x33{return Data([0x61,0,1,0,0x39])}
   if field==0x30{return Data([0x61,0,2,0,0x30,65])}
   return Data([0x61,0,2,0,field,0])
  }
  ysf.reply={d in d.prefix(4)==Data("YSFP".utf8) ? d:nil}
  let defaults=UserDefaults.standard,keys=["call","host","port","ambeHost","ambePort","pttKeyMode","pttButtonToggle"]
  let saved=keys.map{defaults.object(forKey:$0)}
  let session=RadioSession(microphone:mic,pttKey:key,passwordStore:MemoryDMRPasswordStore())
  defer{session.disconnect();ambe.stop();ysf.stop();for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  session.pttKeyMode = .hold;session.pttButtonToggle=false;session.host="127.0.0.1";session.port=String(ysf.port)
  session.ambeHost="127.0.0.1";session.ambePort=String(ambe.port);session.exclusive=true;session.volume=0
  session.selectMode(.fusion);session.connect()
  var deadline=Date().addingTimeInterval(4)
  while !key.registered,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(key.registered,true,session.log)
  mic.deferPermission=true;key.emit(true)
  XCTAssertEqual(session.preparingTransmit,true)
  key.emit(false);mic.permissionReply?(true)
  XCTAssertEqual(session.preparingTransmit,false);XCTAssertEqual(session.transmitting,false)
  mic.deferPermission=false;mic.granted=true
  key.emit(true);XCTAssertEqual(session.transmitting,true,session.log)
  session.handleFocusLoss();key.emit(true)
  XCTAssertEqual(session.transmitting,true)
  key.emit(false)
  deadline=Date().addingTimeInterval(2)
  while session.transmitting,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.transmitting,false)
  // The UI switch alone changes keypad 0 too: no second keyboard mode.
  session.pttButtonToggle=true
  XCTAssertEqual(session.pttKeyMode,.hold)
  XCTAssertEqual(session.transmitting,false)
  key.emit(true)
  for _ in 0..<25 {key.emit(true)}
  XCTAssertEqual(session.transmitting,true,"Repeated key-down events must not toggle TX off")
  key.emit(false);session.handleFocusLoss()
  XCTAssertEqual(session.transmitting,true)
  key.emit(true);key.emit(false)
  deadline=Date().addingTimeInterval(2)
  while session.transmitting,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.transmitting,false)
  XCTAssertEqual(session.log.contains("numerieke 0 opnieuw ingedrukt"),true,"The stop reason must identify a toggle gesture")
  session.pttButtonToggle=false
  key.emit(true);XCTAssertEqual(session.transmitting,true)
  key.emit(false)
  deadline=Date().addingTimeInterval(2)
  while session.transmitting,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.transmitting,false,"Switching back must restore keypad hold/release")
  session.setPTT(true);session.setPTT(true)
  XCTAssertEqual(session.transmitting,true)
  session.setPTT(false)
  deadline=Date().addingTimeInterval(2)
  while session.transmitting,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.transmitting,false)
  for toggle in [false,true] {
   session.pttButtonToggle=toggle
   XCTAssertEqual(session.transmitting,false,"Changing button mode must not transmit")
   session.handlePTTButton(pressed:true)
   XCTAssertEqual(session.transmitting,true)
   session.handlePTTButton(pressed:false)
   if toggle {
    XCTAssertEqual(session.transmitting,true,"Toggle must remain on after release")
    session.handlePTTButton(pressed:true);session.handlePTTButton(pressed:false)
   }
   deadline=Date().addingTimeInterval(2)
   while session.transmitting,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
   XCTAssertEqual(session.transmitting,false,"Button must stop on release or second press")
  }
  session.pttKeyMode = .off;XCTAssertEqual(key.registered,false)
  session.disconnect();XCTAssertEqual(key.registered,false)
 }
}
