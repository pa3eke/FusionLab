import Foundation

enum QuickPreset:Codable,Equatable {
 case fusion(title:String,host:String,port:UInt16)
 case dmr(title:String,destination:UInt32,privateCall:Bool)
 case nxdn(title:String,host:String,port:UInt16,destination:UInt16,ran:UInt8)
 var title:String {switch self {case .fusion(let title,_,_),.dmr(let title,_,_),.nxdn(let title,_,_,_,_):return title}}
 var mode:DigitalMode {switch self {case .fusion:return .fusion;case .dmr:return .dmr;case .nxdn:return .nxdn}}
 var detail:String {
  switch self {
  case .fusion(_,let host,let port):return "\(host):\(port)"
  case .dmr(_,let target,let isPrivate):return "\(isPrivate ? "Privé":"TG") \(target)"
  case .nxdn(_,let host,let port,let target,let ran):return "TG \(target) · \(host):\(port) · RAN \(ran)"
  }
 }
 var valid:Bool {
  guard !title.isEmpty,title.count<=40,!title.contains(where:{$0.isNewline}) else{return false}
  switch self {
  case .fusion(_,let host,let port):
   let allowed=CharacterSet(charactersIn:"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:")
   return !host.isEmpty && host.count<=253 && host.unicodeScalars.allSatisfy{allowed.contains($0)} && port>0
  case .dmr(_,let target,_):return (1...0xffffff).contains(target)
  case .nxdn(_,let host,let port,let target,let ran):return !host.isEmpty && host.count<=253 && host.unicodeScalars.allSatisfy{NXDNConfiguration.hostCharacters.contains($0)} && port>0 && target>0 && ran<64
  }
 }
 func renamed(_ name:String)->Self {
  let title=String(name.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"\n",with:" ").prefix(40))
  switch self {
  case .fusion(_,let host,let port):return .fusion(title:title,host:host,port:port)
  case .dmr(_,let target,let isPrivate):return .dmr(title:title,destination:target,privateCall:isPrivate)
  case .nxdn(_,let host,let port,let target,let ran):return .nxdn(title:title,host:host,port:port,destination:target,ran:ran)
  }
 }
 private static func key(_ mode:DigitalMode)->String {"quickPresetsV1.\(mode.rawValue)"}
 static func load(_ mode:DigitalMode,defaults:UserDefaults = .standard)->[Self?] {
  if let data=defaults.data(forKey:key(mode)),data.count<16_000,let saved=try? JSONDecoder().decode([Self?].self,from:data){
   let valid=saved.prefix(8).map{entry in entry.flatMap{$0.valid && $0.mode==mode ? $0:nil}}
   return valid+Array(repeating:nil,count:8-valid.count)
  }
  if mode == .nxdn {return [.nxdn(title:"TG 204",host:"nxdn.repeaters-haaglanden.nl",port:41400,destination:204,ran:1)]+Array(repeating:nil,count:7)}
  if mode == .fusion {return [.fusion(title:YSFHost.echo.name,host:YSFHost.echo.host,port:YSFHost.echo.port)]+Array(repeating:nil,count:7)}
  return [.dmr(title:"TG 204",destination:204,privateCall:false),.dmr(title:"TG 91",destination:91,privateCall:false),.dmr(title:"Echo 9990",destination:9990,privateCall:true)]+Array(repeating:nil,count:5)
 }
 static func save(_ presets:[Self?],mode:DigitalMode,defaults:UserDefaults = .standard){
  let limited=presets.prefix(8).map{entry in entry.flatMap{$0.valid && $0.mode==mode ? $0:nil}}
  let slots=limited+Array(repeating:nil,count:8-limited.count)
  if let data=try? JSONEncoder().encode(slots){defaults.set(data,forKey:key(mode))}
 }
}
