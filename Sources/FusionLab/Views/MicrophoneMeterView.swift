import SwiftUI

struct MicrophoneMeterView:View {
 let rms:Float
 let peak:Float
 let clipped:Bool
 var body:some View {
  VStack(spacing:3){
   meter("Gem.",rms,color:.green)
   meter("Piek",peak,color:clipped ? .red:peak>0.5 ? .orange:.green)
  }.accessibilityElement(children:.combine)
 }
 private func meter(_ title:String,_ level:Float,color:Color)->some View {
  let db=level>0 ? max(-60,20*log10(Double(level))):-60
  return HStack(spacing:6){
   Text(title).frame(width:30,alignment:.leading)
   ProgressView(value:(db+60)/60).tint(color)
   Text(level>0 ? String(format:"%.0f dBFS",db):"−∞ dBFS").monospacedDigit().frame(width:65,alignment:.trailing)
  }.font(.caption2)
 }
}
