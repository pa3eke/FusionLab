import Foundation

struct NXDNVoiceSettings:Equatable {
 let source:UInt16,destination:UInt16
 let ran:UInt8
}
struct NXDNConfiguration:Equatable {
 var radioID="",host="nxdn.repeaters-haaglanden.nl",port="41400",destination="204"
 var ran=1
 static func load(_ defaults:UserDefaults = .standard)->Self {
  var s=Self()
  s.radioID=defaults.string(forKey:"nxdnID") ?? ""
  s.host=defaults.string(forKey:"nxdnHost") ?? s.host
  s.port=defaults.string(forKey:"nxdnPort") ?? s.port
  s.destination=defaults.string(forKey:"nxdnDestination") ?? s.destination
  if defaults.object(forKey:"nxdnRAN") != nil {s.ran=defaults.integer(forKey:"nxdnRAN")}
  return s
 }
 func save(_ defaults:UserDefaults = .standard){
  for (key,value) in [("nxdnID",radioID),("nxdnHost",host),("nxdnPort",port),("nxdnDestination",destination)] {defaults.set(value,forKey:key)}
  defaults.set(ran,forKey:"nxdnRAN")
 }
 func validated()->NXDNVoiceSettings? {
  guard let id=UInt16(radioID),(1...65519).contains(id),let target=UInt16(destination),target>0,
   !host.isEmpty,host.count<=253,host.unicodeScalars.allSatisfy({Self.hostCharacters.contains($0)}),
   let port=UInt16(port),port>0,(0...63).contains(ran) else{return nil}
  return NXDNVoiceSettings(source:id,destination:target,ran:UInt8(ran))
 }
 static let hostCharacters=CharacterSet(charactersIn:"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:")
}
