import SwiftUI

struct ReceiveEQView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 init(session s:RadioSession){
  session=s
  renderState=ConsoleRenderState(values:[s.receiveEQ.low,s.receiveEQ.mid,s.receiveEQ.high,s.receiveEQBypassed])
 }
 private var bindings:SessionBindings {SessionBindings(session:session)}
 var body:some View {
  VStack(alignment:.leading,spacing:4){
   HStack {
    Label("Ontvangst EQ",systemImage:"slider.horizontal.3").font(.caption)
    Spacer()
    Toggle("Bypass",isOn:bindings.receiveEQBypassed).font(.caption)
     .help("Sla de EQ over met behoud van je instellingen. De ontvangst-AGC blijft apart instelbaar.")
    Button("Neutraal"){session.receiveEQ = .init()}.font(.caption)
     .disabled(session.receiveEQBypassed)
   }
   HStack(spacing:16){
    band("Laag",gain:bindings.receiveEQ.low)
    band("Midden",gain:bindings.receiveEQ.mid)
    band("Hoog",gain:bindings.receiveEQ.high)
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
