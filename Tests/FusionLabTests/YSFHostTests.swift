import Foundation

extension ProtocolTests {
 func testYSFHostParsingAndSearch(){
  let text="""
  \u{feff}# Source and attribution header
  00020;NL-NLCENTRAL;Dutch reflector;example.nl;42000;000;
  12345;US-XLX123;XLX test;192.0.2.10;42023;000;
  54321;Duplicate endpoint;Ignored;EXAMPLE.NL;42000;
  invalid;Wrong ID;No;bad.example;42000;
  11111;Bad port;No;bad.example;0;
  22222;Overflow port;No;bad.example;65536;
  33333;Bad host;No;https://example.nl;42000;
  44444;;Empty name;empty.example;42000;
  """
  let hosts=YSFHost.parse(text.replacingOccurrences(of:"\n",with:"\r\n"))
  XCTAssertEqual(hosts.count,2)
  XCTAssertEqual(hosts[0].number,"00020")
  XCTAssertEqual(hosts[0].matches("nl- Dutch"),true)
  XCTAssertEqual(hosts[0].matches("12345"),false)
  XCTAssertEqual(hosts[1].matches("xlx 12345"),true)
  XCTAssertEqual(hosts[1].port,42023)
  XCTAssertEqual(hosts[0].matches(host:" EXAMPLE.NL ",port:"42000"),true)
  XCTAssertEqual(hosts[0].matches(host:"example.nl",port:"42001"),false)
  XCTAssertEqual(YSFHost.parse("<html>Service unavailable</html>"),[])
 }
 @MainActor func testYSFHostCacheRefreshAndSelection() async throws {
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let cache=directory.appendingPathComponent("YSFHosts.txt")
  defer{try? FileManager.default.removeItem(at:directory)}
  let seed="00020;NL-TEST;Dutch;seed.example;42000;"
  let fresh="# Attribution preserved\n12345;XLX-TEST;YSF entrance;xlx.example;42023;"
  var downloaded=Data(fresh.utf8),fetches=0
  let catalog=YSFHostCatalog(seedText:seed,cacheURL:cache,download:{fetches += 1;return downloaded})
  XCTAssertEqual(catalog.hosts.count,2);XCTAssertEqual(catalog.hosts[0],.echo)
  await catalog.refresh()
  XCTAssertEqual(fetches,1);XCTAssertEqual(catalog.hosts[1].host,"xlx.example")
  XCTAssertEqual(try String(contentsOf:cache,encoding:.utf8),fresh)
  let offline=YSFHostCatalog(seedText:seed,cacheURL:cache,download:{throw URLError(.notConnectedToInternet)})
  XCTAssertEqual(offline.hosts,catalog.hosts)
  await offline.refresh()
  XCTAssertEqual(offline.hosts,catalog.hosts);XCTAssertEqual(offline.isLoading,false)
  downloaded=Data("<html>Server error</html>".utf8)
  await catalog.refresh()
  XCTAssertEqual(catalog.hosts,offline.hosts)
  XCTAssertEqual(try String(contentsOf:cache,encoding:.utf8),fresh)
  // A corrupt local cache falls back to the bundled seed plus the echo host.
  try downloaded.write(to:cache)
  let fallback=YSFHostCatalog(seedText:seed,cacheURL:cache)
  XCTAssertEqual(fallback.hosts[1].host,"seed.example")

  let defaults=UserDefaults.standard,oldHost=defaults.object(forKey:"host"),oldPort=defaults.object(forKey:"port")
  defer{defaults.set(oldHost,forKey:"host");defaults.set(oldPort,forKey:"port")}
  let session=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore()),entry=offline.hosts[1]
  session.selectReflector(entry)
  XCTAssertEqual(session.host,"xlx.example");XCTAssertEqual(session.port,"42023")
  XCTAssertEqual(defaults.string(forKey:"port"),"42023")
  XCTAssertEqual(session.active,false,"Choosing a host must not connect or transmit")
  session.active=true;session.selectReflector(.echo)
  XCTAssertEqual(session.host,"xlx.example","A connected session must keep its endpoint")
  session.active=false
 }
}
