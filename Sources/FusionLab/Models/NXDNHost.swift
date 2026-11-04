import Foundation

struct NXDNHost:Identifiable,Equatable {
 let number:UInt16
 let host:String
 let port:UInt16
 var id:String {"\(number)|\(host.lowercased())|\(port)"}
 var title:String {"TG \(number)"}
 func matches(_ query:String)->Bool {query.isEmpty || "\(number) \(host)".localizedCaseInsensitiveContains(query)}
 func matches(_ config:NXDNConfiguration)->Bool {number==UInt16(config.destination) && port==UInt16(config.port) && host.caseInsensitiveCompare(config.host) == .orderedSame}
 static let seeds=[NXDNHost(number:204,host:"nxdn.repeaters-haaglanden.nl",port:41400),NXDNHost(number:205,host:"87.106.80.104",port:42400),NXDNHost(number:711,host:"94.72.113.36",port:41400)]
 static func parse(_ text:String)->[Self] {
  var seen=Set<String>()
  return text.replacingOccurrences(of:"\u{feff}",with:"").split(whereSeparator:{$0.isNewline}).compactMap {line in
   let fields=line.split(separator:"#",maxSplits:1,omittingEmptySubsequences:false)[0].split(whereSeparator:{$0.isWhitespace})
   guard fields.count>=3,let number=UInt16(fields[0]),number>0,let port=UInt16(fields[2]),port>0 else{return nil}
   let host=String(fields[1])
   guard !host.isEmpty,host.count<=253,host.unicodeScalars.allSatisfy({NXDNConfiguration.hostCharacters.contains($0)}) else{return nil}
   let entry=Self(number:number,host:host,port:port)
   guard seen.insert(entry.id).inserted else{return nil}
   return entry
  }.sorted{($0.number,$0.host)<($1.number,$1.host)}
 }
}
