import Foundation

private final class DelayedPasswordStore:DMRPasswordStorage {
 private let lock=NSLock()
 private var count=0
 var reads:Int {lock.lock();defer{lock.unlock()};return count}
 func read(for id:String)->String? {
  lock.lock();count += 1;lock.unlock()
  Thread.sleep(forTimeInterval:0.15)
  return "test-secret"
 }
 func save(_ password:String,for id:String)->Bool {false}
 func remove(for id:String){}
}

extension ProtocolTests {
 @MainActor func testPasswordRestoreDoesNotBlockStartup() async throws {
  let defaults=UserDefaults.standard,saved=defaults.object(forKey:"rememberDMRPassword")
  defaults.set(true,forKey:"rememberDMRPassword")
  defer{defaults.set(saved,forKey:"rememberDMRPassword")}
  let store=DelayedPasswordStore()
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:store)
  XCTAssertEqual(store.reads,0,"Session initialization must never wait for Keychain")
  session.dmr.radioID="2040001";session.dmrPassword=""
  session.restoreDMRPasswordIfNeeded()
  XCTAssertEqual(session.loadingDMRPassword,true)
  session.dmrPassword="typed-while-loading"
  var deadline=Date().addingTimeInterval(2)
  while session.loadingDMRPassword,Date()<deadline {try await Task.sleep(nanoseconds:10_000_000)}
  XCTAssertEqual(session.dmrPassword,"typed-while-loading","A delayed saved password must not overwrite typing")
  session.restoreDMRPasswordIfNeeded();XCTAssertEqual(store.reads,1,"Automatic restore runs once")
  session.dmrPassword="";session.loadDMRPassword()
  deadline=Date().addingTimeInterval(2)
  while session.loadingDMRPassword,Date()<deadline {try await Task.sleep(nanoseconds:10_000_000)}
  XCTAssertEqual(session.dmrPassword,"test-secret")
 }
 func testQuickPresetStorage() throws {
  let defaults=UserDefaults(suiteName:"FusionLab.PresetTests.\(UUID().uuidString)")!
  defer{defaults.removeObject(forKey:"quickPresetsV1.fusion");defaults.removeObject(forKey:"quickPresetsV1.dmr")}
  var slots=QuickPreset.load(.fusion,defaults:defaults)
  XCTAssertEqual(slots.count,8)
  slots[7] = .fusion(title:"Test acht",host:"127.0.0.1",port:42023)
  QuickPreset.save(slots,mode:.fusion,defaults:defaults)
  XCTAssertEqual(QuickPreset.load(.fusion,defaults:defaults),slots)
  var dmr=QuickPreset.load(.dmr,defaults:defaults)
  dmr[7] = .dmr(title:"Mijn TG",destination:91,privateCall:false)
  QuickPreset.save(dmr,mode:.dmr,defaults:defaults)
  XCTAssertEqual(QuickPreset.load(.fusion,defaults:defaults),slots,"Modes must not overwrite each other's slots")
  XCTAssertEqual(QuickPreset.load(.dmr,defaults:defaults),dmr)
  slots[7]=nil;QuickPreset.save(slots,mode:.fusion,defaults:defaults)
  XCTAssertNil(QuickPreset.load(.fusion,defaults:defaults)[7])
  let invalid:[QuickPreset?]=[.dmr(title:"Wrong mode",destination:91,privateCall:false),.fusion(title:"Invalid host",host:"bad host",port:42000)]
  defaults.set(try JSONEncoder().encode(invalid),forKey:"quickPresetsV1.fusion")
  XCTAssertEqual(QuickPreset.load(.fusion,defaults:defaults),Array(repeating:nil,count:8))
 }
 @MainActor func testDMRQuickSelection(){
  let defaults=UserDefaults.standard
  let keys=["quickPresetsV1.dmr","dmrDestination","dmrPrivateCall","dmrID","dmrSSID","dmrHost","dmrPort","dmrSlot","dmrColorCode"]
  let saved=keys.map{defaults.object(forKey:$0)}
  defer{for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore())
  session.selectMode(.dmr)
  session.dmr.destination="9990";session.dmr.privateCall=true
  session.saveCurrentPreset(at:7,title:"Mijn echo")
  session.setQuickPreset(.dmr(title:"Wereld",destination:91,privateCall:false),at:6)
  let host=session.dmr.host,slot=session.dmr.slot
  session.active=true;session.activatePreset(at:6)
  XCTAssertEqual(session.dmr.destination,"91");XCTAssertEqual(session.dmr.privateCall,false)
  XCTAssertEqual(session.dmr.host,host);XCTAssertEqual(session.dmr.slot,slot)
  XCTAssertEqual(session.transmitting,false);XCTAssertEqual(session.preparingTransmit,false)
  session.transmitting=true;session.activatePreset(at:7)
  XCTAssertEqual(session.dmr.destination,"91","Cannot change a transmit destination during PTT")
  session.transmitting=false;session.activatePreset(at:7)
  XCTAssertEqual(session.dmr.destination,"9990");XCTAssertEqual(session.dmr.privateCall,true)
  session.active=false
 }
 @MainActor func testLiveReflectorQuickSwitch() async throws {
  let ambe=try MockUDP(),first=try MockUDP(),second=try MockUDP()
  try await ambe.start();try await first.start();try await second.start()
  var resets=0,unlinks=0,polls=0,voice=0
  ambe.reply={data in
   guard let p=Packets.dv3k(data),p.type==0,let field=p.body.first else{return nil}
   if field==0x33 {resets += 1;return Data([0x61,0,1,0,0x39])}
   if field==0x30 {return Data([0x61,0,2,0,0x30,65])}
   return Data([0x61,0,2,0,field,0])
  }
  first.reply={data in
   if data.prefix(4)==Data("YSFU".utf8){unlinks += 1}
   if data.prefix(4)==Data("YSFD".utf8){voice += 1}
   return data.prefix(4)==Data("YSFP".utf8) ? data:nil
  }
  second.reply={data in
   if data.prefix(4)==Data("YSFD".utf8){voice += 1}
   if data.prefix(4)==Data("YSFP".utf8){polls += 1;return data}
   return nil
  }
  let defaults=UserDefaults.standard,keys=["call","host","port","ambeHost","ambePort","digitalMode","quickPresetsV1.fusion"]
  let saved=keys.map{defaults.object(forKey:$0)}
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore())
  defer{session.disconnect();ambe.stop();first.stop();second.stop();for(k,v)in zip(keys,saved){defaults.set(v,forKey:k)}}
  session.selectMode(.fusion);session.host="127.0.0.1";session.port=String(first.port)
  session.ambeHost="127.0.0.1";session.ambePort=String(ambe.port);session.volume=0;session.exclusive=true
  session.setQuickPreset(.fusion(title:"Tweede",host:"127.0.0.1",port:second.port),at:7)
  session.connect()
  var deadline=Date().addingTimeInterval(4)
  while !session.canTransmit,Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.canTransmit,true,session.log)
  session.transmitting=true;session.activatePreset(at:7)
  XCTAssertEqual(session.port,String(first.port),"Switching must be blocked during TX")
  session.transmitting=false;session.activatePreset(at:7)
  deadline=Date().addingTimeInterval(4)
  while (session.port != String(second.port) || !session.canTransmit || unlinks==0 || polls==0),Date()<deadline {try await Task.sleep(nanoseconds:20_000_000)}
  XCTAssertEqual(session.port,String(second.port),session.log)
  XCTAssertEqual(session.canTransmit,true,session.log)
  XCTAssertEqual(unlinks,1);XCTAssertEqual(polls>0,true)
  XCTAssertEqual(resets,1,"Reflector switch must preserve the existing vocoder connection")
  XCTAssertEqual(ambe.clients.count,1);XCTAssertEqual(voice,0,"Selecting a preset must never transmit speech")
 }
}
