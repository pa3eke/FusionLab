import SwiftUI
import AppKit

struct PresetSelectionView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 private var bindings:SessionBindings {SessionBindings(session:session)}
 @State private var position=0
 init(session s:RadioSession){
  session=s
  renderState=ConsoleRenderState(values:[s.selectedMode.rawValue,s.canChoosePreset],presets:s.quickPresets)
 }
 var body:some View {
  VStack(spacing:10){
   ZStack{
    Circle().fill(AngularGradient(colors:[Color(white:0.65),Color(white:0.15),Color(white:0.5),Color(white:0.1),Color(white:0.65)],center:.center))
    ForEach(0..<40,id:\.self){i in Capsule().fill(Color.black.opacity(0.75)).frame(width:3,height:7).offset(y:-65).rotationEffect(.degrees(Double(i)*9))}
    Circle().fill(LinearGradient(colors:[Color(white:0.24),Color(white:0.08),Color(white:0.2)],startPoint:.topLeading,endPoint:.bottomTrailing)).padding(10)
     .overlay(Circle().stroke(Color.white.opacity(0.4),lineWidth:1).padding(10))
    Capsule().fill(Color.white).frame(width:4,height:17).offset(y:-46).rotationEffect(.degrees(Double(position)*40-140))
    WheelInput(onStep:{step($0)}).allowsHitTesting(session.canChoosePreset)
   }.frame(width:145,height:145)
    .contentShape(Circle())
    .accessibilityElement(children:.ignore).accessibilityLabel("Geheugenpositie")
    .accessibilityValue("\(position+1), \(session.quickPresets[position]?.title ?? "leeg")")
    .accessibilityAdjustableAction{direction in if direction == .increment {step(1)}else if direction == .decrement {step(-1)}}
   HStack{
    Button{step(-1)}label:{Image(systemName:"minus")}.accessibilityLabel("Vorige geheugenpositie")
    Text("MEM \(position+1)").font(.caption.monospaced().bold()).frame(maxWidth:.infinity)
    Button{step(1)}label:{Image(systemName:"plus")}.accessibilityLabel("Volgende geheugenpositie")
   }.disabled(!session.canChoosePreset)
   Text(session.quickPresets[position]?.title ?? "Lege positie").font(.caption).lineLimit(1)
   Button("Kiezen"){session.activatePreset(at:position)}.buttonStyle(.borderedProminent)
    .disabled(!session.canChoosePreset || session.quickPresets[position]==nil)
   Text("Draaien selecteert · Kiezen past toe").font(.system(size:10)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
  }
 }
 private func step(_ delta:Int){guard session.canChoosePreset else{return};position=min(7,max(0,position+delta))}
}

// Only wheel events cross into AppKit; the selection remains SwiftUI state.
private struct WheelInput:NSViewRepresentable {
 let onStep:(Int)->Void
 func makeNSView(context:Context)->PresetWheelView {PresetWheelView()}
 func updateNSView(_ view:PresetWheelView,context:Context){view.onStep=onStep}
}
private final class PresetWheelView:NSView {
 var onStep:((Int)->Void)?
 private var accumulated:CGFloat=0
 private var dragPoint:NSPoint?
 override func mouseDown(with event:NSEvent){dragPoint=event.locationInWindow}
 override func mouseDragged(with event:NSEvent){
  guard let origin=dragPoint else{return}
  let current=event.locationInWindow
  let delta=current.x-origin.x+current.y-origin.y
  if abs(delta)>=20 {onStep?(delta>0 ? 1:-1);dragPoint=current}
 }
 override func mouseUp(with event:NSEvent){dragPoint=nil}
 override func scrollWheel(with event:NSEvent){
  guard !event.momentumPhase.contains(.changed) else{return}
  let delta=event.scrollingDeltaY
  if event.hasPreciseScrollingDeltas {
   if event.phase.contains(.began){accumulated=0}
   accumulated+=delta
   if abs(accumulated)>=16 {onStep?(accumulated>0 ? -1:1);accumulated=0}
  }else if delta != 0 {onStep?(delta>0 ? -1:1)}
 }
}
