import Foundation

struct DMRConfiguration {
 var radioID="",ssid="",host="2041.master.brandmeister.network",port="62031",destination="9990"
 var slot=2,colorCode=1,privateCall=true
 static func load(_ defaults:UserDefaults = .standard)->Self {
  var value=Self()
  value.radioID=defaults.string(forKey:"dmrID") ?? ""
  value.ssid=defaults.string(forKey:"dmrSSID") ?? ""
  value.host=defaults.string(forKey:"dmrHost") ?? value.host
  value.port=defaults.string(forKey:"dmrPort") ?? value.port
  value.destination=defaults.string(forKey:"dmrDestination") ?? value.destination
  if defaults.object(forKey:"dmrSlot") != nil {value.slot=defaults.integer(forKey:"dmrSlot")}
  if defaults.object(forKey:"dmrColorCode") != nil {value.colorCode=defaults.integer(forKey:"dmrColorCode")}
  if defaults.object(forKey:"dmrPrivateCall") != nil {value.privateCall=defaults.bool(forKey:"dmrPrivateCall")}
  return value
 }
 func save(_ defaults:UserDefaults = .standard){
  for (key,value) in [("dmrID",radioID),("dmrSSID",ssid),("dmrHost",host),("dmrPort",port),("dmrDestination",destination)] {defaults.set(value,forKey:key)}
  defaults.set(slot,forKey:"dmrSlot");defaults.set(colorCode,forKey:"dmrColorCode");defaults.set(privateCall,forKey:"dmrPrivateCall")
 }
 func validated()->DMRVoiceSettings? {
  guard radioID.count==7,let source=UInt32(radioID),(1_000_000...9_999_999).contains(source),
   let target=UInt32(destination),(1...0xffffff).contains(target),
   (1...2).contains(slot),(0...15).contains(colorCode),
   !host.isEmpty,!host.contains(where:{$0.isWhitespace}),let port=UInt16(port),port>0 else{return nil}
  var peer=source
  if !ssid.isEmpty {
   guard ssid.count<=2,ssid.utf8.allSatisfy({(48...57).contains($0)}),let suffix=UInt32(ssid),suffix<=99 else{return nil}
   peer=source*100+suffix
  }
  return DMRVoiceSettings(source:source,destination:target,peer:peer,slot:UInt8(slot),colorCode:UInt8(colorCode),privateCall:privateCall)
 }
}
