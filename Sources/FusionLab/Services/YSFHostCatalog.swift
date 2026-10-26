import Foundation
import Combine

@MainActor final class YSFHostCatalog:ObservableObject {
 static let source=URL(string:"https://www.pistar.uk/downloads/YSF_Hosts.txt")!
 @Published private(set) var hosts=[YSFHost.echo]
 @Published private(set) var isLoading=false
 @Published private(set) var status=""
 private let cacheURL:URL
 private let download:() async throws -> Data
 init(seedText:String?=nil,cacheURL:URL?=nil,download:(() async throws -> Data)?=nil){
  self.cacheURL=cacheURL ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("FusionLab/YSFHosts.txt")
  self.download=download ?? Self.fetch
  var seed=seedText ?? ""
  if seedText==nil {
   #if SWIFT_PACKAGE
   // Our installed .app keeps resources in Contents/Resources. SwiftPM's
   // command-line accessor otherwise falls back to an absolute build path.
   let installed=Bundle.main.url(forResource:"FusionLab_FusionLab",withExtension:"bundle").flatMap{Bundle(url:$0)}
   if let url=(installed ?? Bundle.module).url(forResource:"YSFHosts",withExtension:"txt") {seed=(try? String(contentsOf:url,encoding:.utf8)) ?? ""}
   #endif
  }
  let cached=(try? String(contentsOf:self.cacheURL,encoding:.utf8)) ?? ""
  let entries=YSFHost.parse(cached)
  install(entries.isEmpty ? YSFHost.parse(seed):entries)
  status=entries.isEmpty ? "Meegeleverde lijst · \(hosts.count) reflectoren":"Bewaarde lijst · \(hosts.count) reflectoren"
 }
 func refresh() async {
  guard !isLoading else{return};isLoading=true
  defer{isLoading=false}
  do {
   let data=try await download()
   guard data.count<=2_000_000,let text=String(data:data,encoding:.utf8) else{throw CatalogError.invalid}
   let entries=YSFHost.parse(text)
   guard !entries.isEmpty else{throw CatalogError.invalid}
   // Keep attribution and the complete original file in the offline cache.
   try FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)
   try data.write(to:cacheURL,options:.atomic)
   install(entries)
   status="Bijgewerkt · \(hosts.count) reflectoren"
  }catch {
   status="Bijwerken mislukt; bestaande lijst blijft beschikbaar."
  }
 }
 private func install(_ entries:[YSFHost]){
  hosts=[.echo]+entries.filter{$0.id != YSFHost.echo.id}
 }
 private static func fetch() async throws -> Data {
  var request=URLRequest(url:source,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:20)
  request.setValue("FusionLab/0.3.0 (YSF reflector selector)",forHTTPHeaderField:"User-Agent")
  let (data,response)=try await URLSession.shared.data(for:request)
  guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else{throw CatalogError.invalid}
  return data
 }
 private enum CatalogError:Error {case invalid}
}
