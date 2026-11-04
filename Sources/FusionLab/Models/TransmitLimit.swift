import Foundation

enum TransmitLimit:Int,CaseIterable,Identifiable {
 case twoMinutes=120,threeMinutes=180
 var id:Int {rawValue}
 var title:String {self == .twoMinutes ? "2 min":"3 min"}
 static func load()->Self {Self(rawValue:UserDefaults.standard.integer(forKey:"transmitLimitSeconds")) ?? .threeMinutes}
}
