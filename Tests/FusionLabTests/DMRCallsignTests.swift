import Foundation

private actor CallsignFetchProbe {
 var requests=0
 func fetch(_ id:UInt32)->Data {
  requests += 1
  if id==2040002 {return Data(#"{"results":[{"id":2040002,"callsign":"pa0test"}]}"#.utf8)}
  if id==2040003 {return Data(#"{"results":[{"id":2040004,"callsign":"PA0WRONG"}]}"#.utf8)}
  return Data(#"{"results":[]}"#.utf8)
 }
}
private struct DelayedCallsignLookup:DMRCallsignLookup {
 func callsign(for id:UInt32) async ->String? {
  try? await Task.sleep(nanoseconds:id==2040002 ? 100_000_000:10_000_000)
  return id==2040002 ? "PA0OLD":"PA0NEW"
 }
}
extension ProtocolTests {
 @MainActor func testDMRCallsignLookupAndDisplay() async throws {
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let url=folder.appendingPathComponent("calls.json"),probe=CallsignFetchProbe()
  defer{try? FileManager.default.removeItem(at:folder)}
  let directory=DMRCallsignDirectory(cacheURL:url,download:{await probe.fetch($0)})
  XCTAssertEqual(await directory.callsign(for:2040002),"PA0TEST")
  XCTAssertEqual(await directory.callsign(for:2040002),"PA0TEST")
  XCTAssertEqual(await probe.requests,1,"A known station must be served from cache")
  XCTAssertNil(await directory.callsign(for:2040003)) // mismatched response ID
  XCTAssertNil(await directory.callsign(for:2040004)) // unknown ID
  XCTAssertNil(await directory.callsign(for:2040004)) // negative cache
  XCTAssertNil(await directory.callsign(for:9990))
  XCTAssertEqual(await probe.requests,3)
  let offline=DMRCallsignDirectory(cacheURL:url,download:{_ in throw URLError(.notConnectedToInternet)})
  XCTAssertEqual(await offline.callsign(for:2040002),"PA0TEST","Known calls survive app restart offline")
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),callsignDirectory:DelayedCallsignLookup())
  session.selectMode(.dmr);session.active=true
  session.updateDMRStation(2040002)
  XCTAssertEqual(session.station,"2040002","The source ID must appear immediately")
  session.updateDMRStation(2040003)
  try await Task.sleep(nanoseconds:150_000_000)
  XCTAssertEqual(session.station,"PA0NEW · 2040003","A delayed older lookup must not overwrite the current speaker")
  session.updateDMRStation(9990);XCTAssertEqual(session.station,"Echo · 9990")
  session.updateDMRStation(2040002);session.disconnect()
  try await Task.sleep(nanoseconds:150_000_000)
  XCTAssertEqual(session.station,"2040002","No late UI update after disconnect")
 }
}
