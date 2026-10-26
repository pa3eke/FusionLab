import SwiftUI

struct TransmitView:View {
 @ObservedObject var session:RadioSession
 var body:some View {
  HStack(spacing:16){
   VStack(alignment:.leading,spacing:5){
    HStack{Label("Microfoon",systemImage:"mic.fill");Spacer();Text(session.microphoneClipping ? "CLIP":"8 kHz").font(.caption).foregroundStyle(session.microphoneClipping ? .red:.secondary)}
    HStack {
     Picker("Ingang",selection:$session.selectedInputUID){
      Text("macOS-standaard").tag("")
      ForEach(session.inputDevices){device in Text(device.name).tag(device.id)}
     }.labelsHidden()
     Picker("Kanaal",selection:$session.inputChannel){Text("Kanaal 1").tag(0);Text("Kanaal 2").tag(1)}.labelsHidden().frame(width:100)
     Button(action:{session.refreshInputDevices()}){Image(systemName:"arrow.clockwise")}.help("Ingangen vernieuwen")
    }.disabled(session.transmitting || session.preparingTransmit || session.microphoneTesting)
    HStack {
     Text("Versterking").font(.caption)
     Slider(value:$session.microphoneGainDB,in:-12...36,step:1).accessibilityLabel("Microfoonversterking in dB")
     Text(String(format:"%+.0f dB",session.microphoneGainDB)).font(.caption.monospacedDigit()).frame(width:50,alignment:.trailing)
     Button("0 dB"){session.microphoneGainDB=0}.font(.caption)
    }
    MicrophoneMeterView(rms:session.microphoneLevel,peak:session.microphonePeak,clipped:session.microphoneClipping)
    HStack{
     Button(session.microphoneTesting ? "Stop microfoontest":"Microfoon testen"){session.toggleMicrophoneTest()}
      .disabled(session.transmitting || session.preparingTransmit)
     Text(session.microphoneTesting ? "\(session.microphoneTestFrames) blokken · geen uitzending":"Mic \(session.microphoneFrames) → AMBE \(session.encodedFrames) → YSF \(session.transmittedFrames)")
      .font(.caption).foregroundStyle(.secondary).monospacedDigit()
    }
    Toggle("Numerieke 0 in alle programma’s",isOn:Binding(get:{session.pttKeyMode != .off},set:{session.pttKeyMode=$0 ? .hold:.off}))
     .font(.caption).disabled(session.transmitting || session.preparingTransmit)
    Text(session.pttKeyStatus).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
   }
   VStack(spacing:4){
    PTTButton(title:session.drainingTransmit ? "Afronden…":session.preparingTransmit ? "Microfoon…":session.transmitting ? "● ZENDEN":"PTT · Zenden",
     enabled:!session.drainingTransmit && (session.canTransmit || session.transmitting || session.preparingTransmit),transmitting:session.transmitting,
     onPress:{session.handlePTTButton(pressed:true)},onRelease:{session.handlePTTButton(pressed:false)})
     .frame(width:165,height:48)
     .disabled(session.drainingTransmit || (!session.canTransmit && !session.transmitting && !session.preparingTransmit))
    Toggle("Aan/uit-modus",isOn:$session.pttButtonToggle)
     .toggleStyle(.switch).disabled(session.transmitting || session.preparingTransmit)
     .help("Geldt voor de PTT-knop én de numerieke 0")
    Text(session.pttButtonToggle ? "Klik aan · klik uit":"Ingedrukt houden")
     .font(.caption2).foregroundStyle(.secondary)
    Text("Knop én numerieke 0").font(.caption2).foregroundStyle(.secondary)
    Text(session.transmitting ? "Nog \(session.pttSecondsRemaining) s":"Time-out · 180 s").font(.caption.monospacedDigit()).foregroundStyle(session.transmitting ? .red:.secondary)
   }
  }.padding(10).background(.quaternary.opacity(0.35),in:RoundedRectangle(cornerRadius:8))
 }
}
