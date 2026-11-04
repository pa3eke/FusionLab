import Foundation

enum VocoderBackend:String,CaseIterable,Identifiable {
 case ambeServer,md380
 var id:String {rawValue}
 var title:String {self == .ambeServer ? "AMBEserver":"MD380 · lokaal"}
 static func load()->Self {Self(rawValue:UserDefaults.standard.string(forKey:"vocoderBackend") ?? "") ?? .ambeServer}
}
