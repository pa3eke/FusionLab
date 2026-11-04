import Foundation
import Darwin

extension ProtocolTests {
 @MainActor func testBrandMeisterHeartbeatWithoutUI() async throws {
  let queue=DispatchQueue(label:"FusionLabTests.heartbeat")
  let began=ProcessInfo.processInfo.systemUptime
  // Accelerated monotonic clock: one wall second represents fifty protocol
  // seconds. A UI pause exceeds the normal 20-second timeout in this clock.
  let connection=BrandMeisterConnection(queue:queue,interval:0.02,clock:{Date(timeIntervalSince1970:(ProcessInfo.processInfo.systemUptime-began)*50)})
  let peer:UInt32=204000101
  var pings=0,ready=false,errors=[String](),respond=true
  connection.onReady={ready=true};connection.onError={errors.append($0)}
  connection.onSend={data in
   if data.prefix(7)==Data("RPTPING".utf8){
    pings += 1
    if respond {connection.receive(Data("MSTPONG".utf8)+DMRPackets.id(peer))}
   }else if data.prefix(4)==Data("RPTL".utf8){connection.receive(Data("RPTACK".utf8)+Data([1,2,3,4]))}
   else if data.prefix(4)==Data("RPTK".utf8) || data.count==302 {connection.receive(Data("RPTACK".utf8)+DMRPackets.id(peer))}
  }
  defer{connection.reset();queue.sync{}}
  connection.start(peer:peer,call:"PA0TEST",password:"test-secret")
  let deadline=Date().addingTimeInterval(2)
  while !ready,Date()<deadline {try await Task.sleep(nanoseconds:10_000_000)}
  XCTAssertEqual(ready,true)
  usleep(1_000_000) // Deliberately block the main/UI thread.
  XCTAssertEqual(queue.sync{pings>=7},true,"Keepalives must continue while the UI is blocked")
  try await Task.sleep(nanoseconds:20_000_000)
  XCTAssertEqual(errors,[])
  // Genuine lost responses still stop the connection; no indefinite masking.
  queue.sync{respond=false}
  try await Task.sleep(nanoseconds:600_000_000)
  XCTAssertEqual(errors.count,1)
  XCTAssertEqual(errors.first?.contains("keepalive"),true)
  let atFailure=queue.sync{pings}
  try await Task.sleep(nanoseconds:150_000_000)
  XCTAssertEqual(queue.sync{pings},atFailure,"Timer must stop after connection failure")
 }
 @MainActor func testBoundedActivityLog(){
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore())
  for i in 0..<5000 {session.note("Bericht \(i)")}
  let lines=session.log.split(separator:"\n")
  XCTAssertEqual(lines.count,100)
  XCTAssertEqual(lines.first?.contains("Bericht 4900"),true)
  XCTAssertEqual(lines.last?.contains("Bericht 4999"),true)
  session.note(String(repeating:"x",count:20_000))
  XCTAssertEqual(session.log.split(separator:"\n").last!.count<550,true,"Individual entries must remain bounded")
  session.active=true;session.log="";session.note("Na wissen")
  XCTAssertEqual(session.active,true,"Clearing the log must not disconnect")
  XCTAssertEqual(session.log.split(separator:"\n").count,1)
  session.active=false
 }
}
