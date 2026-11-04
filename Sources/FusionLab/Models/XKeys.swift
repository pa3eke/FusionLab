import Foundation

enum XKeysAction:String,Codable,CaseIterable,Identifiable {
 case none,ptt,stopTX,connect,disconnect,volumeUp,volumeDown,preset1,preset2,preset3,preset4,preset5,preset6,preset7,preset8,agc,eqBypass,audioMute
 var id:String {rawValue}
 var title:String {
  switch self {
  case .none:return "Geen functie";case .ptt:return "PTT";case .stopTX:return "PTT OFF · direct stoppen"
  case .connect:return "Verbinden";case .disconnect:return "Ontkoppelen";case .volumeUp:return "Volume +";case .volumeDown:return "Volume −"
  case .audioMute:return "Audio mute aan/uit"
  case .agc:return "AGC aan/uit";case .eqBypass:return "EQ-bypass aan/uit"
  default:return "Voorkeuze \(presetIndex!+1)"
  }
 }
 var presetIndex:Int? {switch self {case .preset1:return 0;case .preset2:return 1;case .preset3:return 2;case .preset4:return 3;case .preset5:return 4;case .preset6:return 5;case .preset7:return 6;case .preset8:return 7;default:return nil}}
}
enum XKeysPTTMode:String,Codable,CaseIterable,Identifiable {
 case hold,toggle
 var id:String {rawValue}
 var title:String {self == .hold ? "Vasthouden":"Aan / uit"}
 var keyMode:PTTKeyMode {self == .hold ? .hold:.toggle}
}
struct XKeysBinding:Codable,Equatable {
 var action:XKeysAction = .none
 var mode:XKeysPTTMode = .hold
 var title:String {action == .ptt ? "PTT · \(mode.title)":action.title}
}
struct XKeysSettings:Codable,Equatable {
 var enabled=false
 var leds=true
 var bindings=Self.defaults
 static var defaults:[XKeysBinding] {
  var keys=Array(repeating:XKeysBinding(),count:24)
  keys[0]=XKeysBinding(action:.ptt);keys[1]=XKeysBinding(action:.stopTX)
  keys[6]=XKeysBinding(action:.connect);keys[7]=XKeysBinding(action:.disconnect)
  keys[12]=XKeysBinding(action:.volumeUp);keys[13]=XKeysBinding(action:.volumeDown)
  return keys
 }
 static func load(_ defaults:UserDefaults = .standard)->Self {
  guard let data=defaults.data(forKey:"xkeys.settings.v1"),data.count<16000,let value=try? JSONDecoder().decode(Self.self,from:data),value.bindings.count==24 else{return Self()}
  return value
 }
 func save(_ defaults:UserDefaults = .standard){guard bindings.count==24,let data=try? JSONEncoder().encode(self) else{return};defaults.set(data,forKey:"xkeys.settings.v1")}
}
struct XKeysDeviceInfo:Equatable {
 let source:String,productID:Int
 var firmware:Int?,mode:Int?
 var compatible:Bool
 var title:String {"XK-24 · PID \(String(format:"%04X",productID))"+(firmware.map{" · firmware \($0)"} ?? "")}
}
enum XKeysReport {
 static let vendor=1523,usagePage=12,usage=1
 static let softwarePIDs:Set<Int>=[1027,1029]
 static let hardwarePIDs:Set<Int>=[1028,1249]
 static func keys(_ data:Data,reportID:UInt32=0)->Set<Int>? {
  guard reportID==0 else{return nil}
  var bytes=[UInt8](data)
  if bytes.count==33,bytes[0]==0 {bytes.removeFirst()}
  guard bytes.count==32,bytes[1]&0xfc==0 else{return nil}
  var keys=Set<Int>()
  for column in 0..<4 {
   guard bytes[column+2]&0xc0==0 else{return nil}
   for row in 0..<6 where bytes[column+2]&(1<<row) != 0 {keys.insert(column*6+row)}
  }
  return keys
 }
 static func ledIndex(_ key:Int)->UInt8 {precondition((0..<24).contains(key));return UInt8((key/6)*8+key%6)}
 static func output(_ command:UInt8,_ a:UInt8=0,_ b:UInt8=0)->Data {Data([command,a,b])+Data(repeating:0,count:32)}
}
struct XKeysInputHandler {
 private var previous:Set<Int>?
 private var blocked=Set<Int>()
 mutating func reset(){previous=nil;blocked=[]}
 mutating func events(_ keys:Set<Int>)->[(key:Int,down:Bool)] {
  guard let old=previous else{previous=keys;blocked=keys;return []}
  blocked.formIntersection(keys)
  let events=old.symmetricDifference(keys).sorted().filter{!blocked.contains($0)}.map{(key:$0,down:keys.contains($0))}
  previous=keys
  return events
 }
}
struct XKeysLEDState:Equatable {var blue:UInt8=0,red:UInt8=0}
enum XKeysLEDController {
 static func frame(settings:XKeysSettings,transmitting:Bool,pressed:Set<Int>)->[XKeysLEDState] {
  settings.bindings.enumerated().map {key,binding in
   guard settings.leds,settings.enabled,binding.action != .none else{return XKeysLEDState()}
   if binding.action == .ptt,transmitting {return XKeysLEDState(red:1)}
   return XKeysLEDState(blue:pressed.contains(key) ? 2:1)
  }
 }
}
