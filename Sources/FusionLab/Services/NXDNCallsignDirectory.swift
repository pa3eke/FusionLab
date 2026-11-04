import Foundation

// RadioID publishes a separate NXDN CSV directory. Only the numeric ID and
// callsign are retained; names, addresses and other columns are discarded.
actor NXDNCallsignDirectory:DMRCallsignLookup {
 static let source=URL(string:"https://radioid.net/static/nxdn.csv")!
 private struct Snapshot:Codable {let date:Date;let calls:[UInt32:String]}
 private var calls:[UInt32:String]=[:]
 private var nextRefresh=Date.distantPast
 private var refresh:Task<[UInt32:String],Error>?
 private let cacheURL:URL
 private let download:() async throws -> Data
 init(cacheURL:URL?=nil,download:(() async throws -> Data)?=nil){
  self.cacheURL=cacheURL ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("FusionLab/NXDNCallsigns.json")
  self.download=download ?? Self.fetch
  if let data=try? Data(contentsOf:self.cacheURL),data.count<2_000_000,
   let saved=try? JSONDecoder().decode(Snapshot.self,from:data),saved.calls.count<=65519 {
   calls=saved.calls.filter{(1...65519).contains($0.key) && Self.clean($0.value)==$0.value}
   nextRefresh=saved.date.addingTimeInterval(86400)
  }
 }
 func callsign(for id:UInt32) async ->String? {
  guard (1...65519).contains(id) else{return nil}
  if Date()<nextRefresh {return calls[id]}
  if refresh==nil {
   let download=download
   refresh=Task {
    let data=try await download()
    guard data.count<4_000_000,let text=String(data:data,encoding:.utf8) else{throw URLError(.cannotParseResponse)}
    let parsed=Self.parse(text)
    guard !parsed.isEmpty else{throw URLError(.cannotParseResponse)}
    return parsed
   }
  }
  let pending=refresh!
  do {
   let result=try await pending.value
   calls=result;nextRefresh=Date().addingTimeInterval(86400)
   if let data=try? JSONEncoder().encode(Snapshot(date:Date(),calls:result)) {
    try? FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)
    try? data.write(to:cacheURL,options:.atomic)
   }
  }catch {nextRefresh=Date().addingTimeInterval(900)}
  refresh=nil
  return calls[id]
 }
 static func parse(_ text:String)->[UInt32:String] {
  var result=[UInt32:String]()
  for line in text.split(whereSeparator:{$0.isNewline}) {
   // Only the first two CSV columns are needed. Both are validated scalar
   // fields; quoted commas/newlines in subsequent personal fields are ignored.
   let fields=line.split(separator:",",maxSplits:2,omittingEmptySubsequences:false)
   guard fields.count>=2,let id=UInt32(fields[0].trimmingCharacters(in:CharacterSet(charactersIn:"\" \t\u{feff}"))),
    (1...65519).contains(id),let call=clean(fields[1].trimmingCharacters(in:CharacterSet(charactersIn:"\""))) else{continue}
   result[id]=call
  }
  return result
 }
 private static func clean(_ value:String)->String? {
  let call=value.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
  guard (3...16).contains(call.count),call.utf8.allSatisfy({(65...90).contains($0)||(48...57).contains($0)||$0==47}),call.utf8.contains(where:{(65...90).contains($0)}),call.utf8.contains(where:{(48...57).contains($0)}) else{return nil}
  return call
 }
 private static func fetch() async throws ->Data {
  var request=URLRequest(url:source,timeoutInterval:15)
  request.setValue("FusionLab/0.6.1 (NXDN callsign display)",forHTTPHeaderField:"User-Agent")
  let (data,response)=try await URLSession.shared.data(for:request)
  guard let http=response as? HTTPURLResponse,http.statusCode==200 else{throw URLError(.badServerResponse)}
  return data
 }
}
