import Foundation

struct YSFHost:Identifiable,Equatable {
 let number:String,name:String,description:String,host:String,port:UInt16
 var id:String {"\(host.lowercased()):\(port)"}
 var title:String {number.isEmpty ? name:"\(name) · \(number)"}
 func matches(_ query:String)->Bool {
  let terms=query.split(whereSeparator:{$0.isWhitespace})
  let text="\(number) \(name) \(description) \(host)"
  return terms.allSatisfy{text.localizedStandardContains(String($0))}
 }
 func matches(host:String,port:String)->Bool {
  self.host.caseInsensitiveCompare(host.trimmingCharacters(in:.whitespacesAndNewlines)) == .orderedSame && UInt16(port)==self.port
 }
 static let echo=YSFHost(number:"",name:"Echo · PA7LIM",description:"Werkende FusionLab-testhost",host:"c4fm.pa7lim.nl",port:42000)
 static func parse(_ text:String)->[YSFHost] {
  var seen=Set<String>(),result=[YSFHost]()
  let allowed=CharacterSet.alphanumerics.union(CharacterSet(charactersIn:".-_:"))
  for raw in text.replacingOccurrences(of:"\u{feff}",with:"").split(whereSeparator:{$0.isNewline}) {
   let row=raw.trimmingCharacters(in:.whitespaces)
   if row.hasPrefix("#"){continue}
   let fields=row.components(separatedBy:";").map{$0.trimmingCharacters(in:.whitespaces)}
   guard fields.count>=5,fields[0].count==5,fields[0].utf8.allSatisfy({(48...57).contains($0)}),
    !fields[1].isEmpty,!fields[3].isEmpty,fields[3].unicodeScalars.allSatisfy({allowed.contains($0)}),
    let port=UInt16(fields[4]),port>0 else{continue}
   let entry=YSFHost(number:fields[0],name:fields[1],description:fields[2],host:fields[3],port:port)
   if seen.insert(entry.id).inserted {result.append(entry)}
  }
  return result.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
 }
}
