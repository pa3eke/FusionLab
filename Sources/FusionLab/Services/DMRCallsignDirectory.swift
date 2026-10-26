import Foundation

protocol DMRCallsignLookup {
 func callsign(for id:UInt32) async -> String?
}

// Only look up stations actually heard. Keep ID/call pairs locally; never
// download or redistribute a bulk directory or retain other personal fields.
actor DMRCallsignDirectory:DMRCallsignLookup {
 private struct Entry:Codable {let call:String?;let date:Date}
 private struct Response:Decodable {
  struct User:Decodable {let id:UInt32;let callsign:String}
  let results:[User]
 }
 private var cache:[UInt32:Entry]=[:]
 private let cacheURL:URL
 private let download:(UInt32) async throws -> Data
 init(cacheURL:URL?=nil,download:((UInt32) async throws -> Data)?=nil){
  self.cacheURL=cacheURL ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("FusionLab/DMRCallsigns.json")
  self.download=download ?? Self.fetch
  if let data=try? Data(contentsOf:self.cacheURL),data.count<500_000,
     let saved=try? JSONDecoder().decode([UInt32:Entry].self,from:data),saved.count<=2000 {cache=saved}
 }
 func callsign(for id:UInt32) async -> String? {
  guard id>=1_000_000,id<=9_999_999 else{return nil}
  if let entry=cache[id],Date().timeIntervalSince(entry.date)<(entry.call==nil ? 3600:604800) {return entry.call}
  let stale=cache[id]?.call
  do {
   let data=try await download(id)
   guard !Task.isCancelled,data.count<100_000 else{return stale}
   let response=try JSONDecoder().decode(Response.self,from:data)
   let call=response.results.first(where:{$0.id==id}).flatMap{Self.clean($0.callsign)}
   cache[id]=Entry(call:call,date:Date());save()
   return call
  }catch {
   // Reuse an older known call offline; otherwise back off failed lookups.
   if !Task.isCancelled {cache[id]=Entry(call:stale,date:Date());save()}
   return stale
  }
 }
 private static func clean(_ value:String)->String? {
  let call=value.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
  guard (3...16).contains(call.count),call.utf8.allSatisfy({(65...90).contains($0)||(48...57).contains($0)||$0==47}),call.utf8.contains(where:{(65...90).contains($0)}),call.utf8.contains(where:{(48...57).contains($0)}) else{return nil}
  return call
 }
 private func save(){
  if cache.count>2000 {cache=Dictionary(uniqueKeysWithValues:cache.sorted{$0.value.date>$1.value.date}.prefix(2000).map{($0.key,$0.value)})}
  guard let data=try? JSONEncoder().encode(cache) else{return}
  try? FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)
  try? data.write(to:cacheURL,options:.atomic)
 }
 private static func fetch(_ id:UInt32) async throws -> Data {
  var parts=URLComponents(string:"https://database.radioid.net/api/users")!
  parts.queryItems=[URLQueryItem(name:"id",value:String(id))]
  var request=URLRequest(url:parts.url!,timeoutInterval:8)
  request.setValue("FusionLab/0.4.6 (PA3EKE; https://github.com/pa3eke/MacDV)",forHTTPHeaderField:"User-Agent")
  let (data,response)=try await URLSession.shared.data(for:request)
  guard let http=response as? HTTPURLResponse,http.statusCode==200 else{throw URLError(.badServerResponse)}
  return data
 }
}
