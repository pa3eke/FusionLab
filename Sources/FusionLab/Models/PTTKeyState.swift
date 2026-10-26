import Foundation

enum PTTKeyMode:String,CaseIterable,Identifiable {
 case off,hold,toggle
 var id:String {rawValue}
 var title:String {switch self {case .off:return "Uit";case .hold:return "Vasthouden";case .toggle:return "Aan / uit"}}
}

// Keep the pressed latch through a timeout: a held/repeating key must never
// start a second transmission until it has actually been released.
struct PTTKeyState {
 enum Action {case none,start,stop}
 private(set) var held=false,ownsTransmission=false
 mutating func event(pressed:Bool,mode:PTTKeyMode,canStart:Bool,engaged:Bool)->Action {
  if !pressed {
   held=false
   if mode == .hold,ownsTransmission {ownsTransmission=false;return .stop}
   return .none
  }
  guard mode != .off,!held else{return .none}
  held=true
  if mode == .toggle,engaged {ownsTransmission=false;return .stop}
  guard !engaged,canStart else{return .none}
  ownsTransmission=true;return .start
 }
 mutating func transmissionEnded(){ownsTransmission=false}
 mutating func reset(){held=false;ownsTransmission=false}
}
