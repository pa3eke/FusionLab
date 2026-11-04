import SwiftUI

struct TransmitView:View {
 @ObservedObject var session:RadioSession
 var body:some View { HStack(spacing:16){ MicrophoneControlView(session:session).equatable(); PTTControlView(session:session).equatable() } }
}

struct MicrophoneControlView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 private var bindings:SessionBindings {SessionBindings(session:session)}
 init(session s:RadioSession){
  session=s
  renderState=ConsoleRenderState(values:[s.selectedInputUID,s.inputChannel,s.transmitting,s.preparingTransmit,s.microphoneTesting,s.microphoneGainDB,s.microphoneClipping,s.microphoneLevel,s.microphonePeak,s.microphoneTestFrames,s.microphoneFrames,s.encodedFrames,s.transmittedFrames,s.pttKeyMode.rawValue,s.pttKeyStatus,s.selectedMode.rawValue],devices:s.inputDevices)
 }
 var body:some View {
   VStack(alignment:.leading,spacing:5){
    if session.microphoneClipping {Text("CLIP · verlaag de versterking").font(.caption.bold()).foregroundStyle(.red)}
    HStack {
     Picker("Ingang",selection:bindings.selectedInputUID){
      Text("macOS-standaard").tag("")
      ForEach(session.inputDevices){device in Text(device.name).tag(device.id)}
     }.labelsHidden()
     Picker("Kanaal",selection:bindings.inputChannel){Text("Kanaal 1").tag(0);Text("Kanaal 2").tag(1)}.labelsHidden().frame(width:100)
     Button(action:{session.refreshInputDevices()}){Image(systemName:"arrow.clockwise")}.help("Ingangen vernieuwen")
    }.disabled(session.transmitting || session.preparingTransmit || session.microphoneTesting)
    HStack {
     Text("Versterking").font(.caption)
     Slider(value:bindings.microphoneGainDB,in:-12...36,step:1).accessibilityLabel("Microfoonversterking in dB")
     Text(String(format:"%+.0f dB",session.microphoneGainDB)).font(.caption.monospacedDigit()).frame(width:50,alignment:.trailing)
     Button("0 dB"){session.microphoneGainDB=0}.font(.caption)
    }
    MicrophoneMeterView(rms:session.microphoneLevel,peak:session.microphonePeak,clipped:session.microphoneClipping)
    HStack{
     Button(session.microphoneTesting ? "Stop microfoontest":"Microfoon testen"){session.toggleMicrophoneTest()}
      .disabled(session.transmitting || session.preparingTransmit)
     Text(session.microphoneTesting ? "\(session.microphoneTestFrames) blokken · geen uitzending":"Mic \(session.microphoneFrames) → AMBE \(session.encodedFrames) → \(session.selectedMode.shortTitle) \(session.transmittedFrames)")
      .font(.caption).foregroundStyle(.secondary).monospacedDigit()
    }
    Toggle("Numerieke 0 in alle programma’s",isOn:Binding(get:{session.pttKeyMode != .off},set:{session.pttKeyMode=$0 ? .hold:.off}))
     .font(.caption).disabled(session.transmitting || session.preparingTransmit)
    Text(session.pttKeyStatus).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true).lineLimit(2).help(session.pttKeyStatus)
   }

 }
}

struct PTTControlView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 private var bindings:SessionBindings {SessionBindings(session:session)}
 init(session s:RadioSession){
  session=s
  renderState=ConsoleRenderState(values:[s.drainingTransmit,s.preparingTransmit,s.transmitting,s.canTransmit,s.pttButtonToggle,s.transmitLimit.rawValue,s.pttSecondsRemaining])
 }
 var body:some View {
   VStack(spacing:4){
    PTTButton(title:session.drainingTransmit ? "Afronden…":session.preparingTransmit ? "Microfoon…":session.transmitting ? "● ZENDEN":"PTT · Zenden",
     enabled:!session.drainingTransmit && (session.canTransmit || session.transmitting || session.preparingTransmit),transmitting:session.transmitting,
     onPress:{session.handlePTTButton(pressed:true)},onRelease:{session.handlePTTButton(pressed:false)})
     .frame(width:145,height:86)
     .padding(8).background(session.transmitting ? Color.red.opacity(0.3):Color.orange.opacity(0.12),in:RoundedRectangle(cornerRadius:12))
     .overlay(RoundedRectangle(cornerRadius:12).stroke(session.transmitting ? Color.red:Color.orange.opacity(0.7),lineWidth:2))
     .opacity(session.drainingTransmit || (!session.canTransmit && !session.transmitting && !session.preparingTransmit) ? 0.45:1)
     .disabled(session.drainingTransmit || (!session.canTransmit && !session.transmitting && !session.preparingTransmit))
    Toggle("Aan/uit-modus",isOn:bindings.pttButtonToggle)
     .toggleStyle(.switch).disabled(session.transmitting || session.preparingTransmit)
     .help("Geldt voor de PTT-knop én de numerieke 0")
    Text(session.pttButtonToggle ? "Klik aan · klik uit":"Ingedrukt houden")
     .font(.caption2).foregroundStyle(.secondary)
    Text("Knop én numerieke 0").font(.caption2).foregroundStyle(.secondary)
    Text("Max. zendtijd").font(.caption2).foregroundStyle(.secondary)
    Picker("Maximale zendtijd",selection:bindings.transmitLimit){
     ForEach(TransmitLimit.allCases){Text($0.title).tag($0)}
    }.pickerStyle(.segmented).labelsHidden().frame(width:165)
     .disabled(session.transmitting || session.preparingTransmit || session.drainingTransmit)
    TransmitTimeView(transmitting:session.transmitting,remaining:session.pttSecondsRemaining,limit:session.transmitLimit)
   }

 }
}
