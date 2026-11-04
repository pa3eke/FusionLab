import SwiftUI

struct TransmitTimeView:View {
 let transmitting:Bool,remaining:Int,limit:TransmitLimit
 private var warning:Bool {transmitting && (1...10).contains(remaining)}
 var body:some View {
  Group {
   if warning {
    TimelineView(.periodic(from:.now,by:0.5)){context in
     indicator(illuminated:context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:1)<0.5)
    }
   }else {indicator(illuminated:true)}
  }.accessibilityElement(children:.ignore)
   .accessibilityLabel(warning ? "Waarschuwing: nog \(remaining) seconden zenden":transmitting ? "Nog \(remaining) seconden zenden":"Maximale zendtijd \(limit.title)")
 }
 private func indicator(illuminated:Bool)->some View {
  HStack(spacing:6){
   Circle().fill(warning ? Color.red:Color.secondary.opacity(0.3))
    .opacity(warning && !illuminated ? 0.15:1).frame(width:10,height:10)
   Text(transmitting ? "Nog \(remaining) s":"Time-out · \(limit.title)")
    .font(.caption.monospacedDigit()).foregroundStyle(warning ? .red:.secondary)
  }
 }
}
