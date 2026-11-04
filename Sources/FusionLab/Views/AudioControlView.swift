import SwiftUI

struct AudioControlView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 private var bindings:SessionBindings {SessionBindings(session:session)}
 init(session s:RadioSession){
  session=s
  renderState=ConsoleRenderState(values:[s.volume,s.receiveMuted,s.receiveAGCEnabled,s.receiveEQ.low,s.receiveEQ.mid,s.receiveEQ.high,s.receiveEQBypassed])
 }
 var body:some View {
  VStack(alignment:.leading,spacing:12){
   HStack{
    Button{session.receiveMuted.toggle()}label:{
     Image(systemName:session.receiveMuted ? "speaker.slash.fill":"speaker.wave.2.fill")
      .foregroundStyle(session.receiveMuted ? Color.orange:Color.primary)
      .frame(width:24,height:24).contentShape(Rectangle())
    }.buttonStyle(.plain)
     .accessibilityLabel(session.receiveMuted ? "Ontvangstaudio inschakelen":"Ontvangstaudio dempen")
     .accessibilityValue(session.receiveMuted ? "Gedempt":"Aan")
     .help(session.receiveMuted ? "Ontvangstaudio gedempt · klik om weer te horen":"Klik om ontvangst te dempen; het volume blijft bewaard")
    Slider(value:bindings.volume,in:0...1).accessibilityLabel("Ontvangstvolume");Text("\(Int(session.volume*100))%").font(.caption.monospacedDigit()).frame(width:35)}
   Toggle("AGC · automatisch volume",isOn:bindings.receiveAGCEnabled).font(.caption)
   Divider()
   ReceiveEQView(session:session).equatable()
  }
 }
}
