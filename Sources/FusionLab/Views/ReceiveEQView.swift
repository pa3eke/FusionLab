import SwiftUI

struct ReceiveEQView:View {
 @ObservedObject var session:RadioSession
 var body:some View {
  VStack(alignment:.leading,spacing:4){
   HStack {
    Label("Ontvangst EQ",systemImage:"slider.horizontal.3").font(.caption)
    Spacer()
    Toggle("Bypass",isOn:$session.receiveEQBypassed).font(.caption)
     .help("Sla de EQ over met behoud van je instellingen. De ontvangst-AGC blijft apart instelbaar.")
    Button("Neutraal"){session.receiveEQ = .init()}.font(.caption)
     .disabled(session.receiveEQBypassed)
   }
   HStack(spacing:16){
    band("Laag",gain:$session.receiveEQ.low)
    band("Midden",gain:$session.receiveEQ.mid)
    band("Hoog",gain:$session.receiveEQ.high)
   }.disabled(session.receiveEQBypassed)
  }.help("Toonregeling voor ontvangst · −12 tot +12 dB per band. Neutraal zet alle banden op 0 dB.")
 }
 private func band(_ label:String,gain:Binding<Double>)->some View {
  VStack(spacing:2){
   HStack{Text(label);Spacer();Text(String(format:"%+.0f dB",gain.wrappedValue)).monospacedDigit()}.font(.caption)
   Slider(value:gain,in:-12...12,step:1).accessibilityLabel("Ontvangst EQ \(label)")
  }.frame(maxWidth:.infinity)
 }
}
