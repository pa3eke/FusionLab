import Foundation

struct TestNXDNLookup:DMRCallsignLookup {
 func callsign(for id:UInt32) async ->String? {id==12345 ? "PA0NX":nil}
}
private struct DelayedNXDNLookup:DMRCallsignLookup {
 func callsign(for id:UInt32) async ->String? {
  try? await Task.sleep(nanoseconds:id==12345 ? 120_000_000:10_000_000)
  return id==12345 ? "PA0OLD":"PA0NEW"
 }
}
private actor NXDNFetchProbe {
 var count=0
 func fetch() async throws ->Data {
  count += 1
  try await Task.sleep(nanoseconds:20_000_000)
  return Data("RADIO_ID,CALLSIGN,FIRST_NAME\n12345,pa0nx,Private field\n12346,PA0NEW,Other\n".utf8)
 }
}
extension ProtocolTests {
 @MainActor func testNXDNCallsignLookupAndDisplay() async throws {
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer{try? FileManager.default.removeItem(at:folder)}
  let cache=folder.appendingPathComponent("calls.json"),probe=NXDNFetchProbe()
  let directory=NXDNCallsignDirectory(cacheURL:cache,download:{try await probe.fetch()})
  async let first=directory.callsign(for:12345)
  async let second=directory.callsign(for:12346)
  let pair=await(first,second)
  XCTAssertEqual(pair.0,"PA0NX");XCTAssertEqual(pair.1,"PA0NEW")
  XCTAssertEqual(await probe.count,1,"Concurrent station lookups share one directory download")
  XCTAssertNil(await directory.callsign(for:65520))
  XCTAssertNil(await directory.callsign(for:2041007))
  XCTAssertNil(await directory.callsign(for:12347));XCTAssertNil(await directory.callsign(for:12347))
  XCTAssertEqual(await probe.count,1,"Unknown IDs must not repeatedly download the directory")
  let saved=try String(contentsOf:cache,encoding:.utf8)
  XCTAssertEqual(saved.contains("Private field"),false,"Only ID and callsign may be cached")
  let offline=NXDNCallsignDirectory(cacheURL:cache,download:{throw URLError(.notConnectedToInternet)})
  XCTAssertEqual(await offline.callsign(for:12345),"PA0NX")
  var stale=try JSONSerialization.jsonObject(with:Data(contentsOf:cache)) as! [String:Any]
  stale["date"]=0
  try JSONSerialization.data(withJSONObject:stale).write(to:cache)
  let broken=NXDNCallsignDirectory(cacheURL:cache,download:{Data("<html>unavailable</html>".utf8)})
  XCTAssertEqual(await broken.callsign(for:12345),"PA0NX","A failed refresh preserves older known calls")
  XCTAssertEqual(NXDNCallsignDirectory.parse("\"12345\",\"pa0nx\",\"A, B\"\n0,PA0BAD\n65520,PA0BAD\n12346,<script>\n12347,NOLETTERSDIGITS\n"),[12345:"PA0NX"])
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),nxdnCallsignDirectory:DelayedNXDNLookup())
  session.selectMode(.nxdn);session.active=true
  session.updateNXDNStation(12345);XCTAssertEqual(session.station,"12345")
  session.updateNXDNStation(12346)
  try await Task.sleep(nanoseconds:160_000_000)
  XCTAssertEqual(session.station,"PA0NEW · 12346","An older station lookup cannot replace the current speaker")
  XCTAssertEqual(session.receivedStationQRZURL?.absoluteString,"https://www.qrz.com/db/PA0NEW")
  session.updateNXDNStation(12345);session.disconnect()
  try await Task.sleep(nanoseconds:160_000_000)
  XCTAssertEqual(session.station,"12345","No late callsign update after disconnect")
 }
}
