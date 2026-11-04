import SwiftUI
import AppKit

// NSButton owns mouse tracking until release, including release outside its
// bounds. SwiftUI's click action alone cannot express momentary PTT.
struct PTTButton:NSViewRepresentable {
 let title:String,enabled:Bool,transmitting:Bool
 let onPress:()->Void,onRelease:()->Void
 func makeNSView(context:Context)->TrackingPTTButton {
  let button=TrackingPTTButton()
  button.cell=PTTButtonCell(textCell:"")
  button.bezelStyle = .regularSquare;button.font = .boldSystemFont(ofSize:16)
  return button
 }
 func sizeThatFits(_ proposal:ProposedViewSize,nsView:TrackingPTTButton,context:Context)->CGSize? {
  CGSize(width:proposal.width ?? 165,height:proposal.height ?? 48)
 }
 func updateNSView(_ button:TrackingPTTButton,context:Context){
  // Audio meters/counters publish frequently. Do not invalidate the native
  // button or its cell unless the actual PTT appearance changes.
  var changed=false
  if button.title != title {button.title=title;changed=true}
  if button.isEnabled != enabled {button.isEnabled=enabled;changed=true}
  if button.transmitting != transmitting {button.transmitting=transmitting;changed=true}
  if changed {button.needsDisplay=true}
  button.onPress=onPress;button.onRelease=onRelease
 }
}

final class TrackingPTTButton:NSButton {
 override var intrinsicContentSize:NSSize {NSSize(width:165,height:48)}
 override var alignmentRectInsets:NSEdgeInsets {NSEdgeInsets(top:0,left:0,bottom:0,right:0)}
 var transmitting=false
 var onPress:(()->Void)?,onRelease:(()->Void)?
 override func mouseDown(with event:NSEvent){
  guard isEnabled else{return}
  onPress?()
  defer{onRelease?()}
  super.mouseDown(with:event)
 }
}

// NSButton redraws its cell directly when enabled/highlight changes. Drawing
// only the NSView allowed the standard rounded bezel to overwrite our fill.
// Both normal display and direct cell redraws now use this same renderer.
final class PTTButtonCell:NSButtonCell {
 override func drawBezel(withFrame frame:NSRect,in controlView:NSView){
  let transmitting=(controlView as? TrackingPTTButton)?.transmitting ?? false
  var fill:NSColor=transmitting ? .systemRed:isEnabled ? NSColor(white:0.12,alpha:1):NSColor(white:0.09,alpha:1)
  if isHighlighted {fill=fill.blended(withFraction:0.15,of:.black) ?? fill}
  fill.setFill()
  let bezel=NSBezierPath(roundedRect:frame.insetBy(dx:1,dy:1),xRadius:8,yRadius:8)
  bezel.fill()
  (transmitting ? NSColor.systemRed:isEnabled ? NSColor.systemOrange:NSColor.darkGray).setStroke()
  bezel.lineWidth=2;bezel.stroke()
 }
 override func drawInterior(withFrame frame:NSRect,in controlView:NSView){
  let style=NSMutableParagraphStyle();style.alignment = .center
  let attributes:[NSAttributedString.Key:Any]=[.font:font ?? NSFont.boldSystemFont(ofSize:16),.foregroundColor:NSColor.white,.paragraphStyle:style]
  let text=title as NSString,height=text.size(withAttributes:attributes).height
  text.draw(in:NSRect(x:frame.minX+4,y:frame.midY-height/2,width:frame.width-8,height:height),withAttributes:attributes)
 }
}
