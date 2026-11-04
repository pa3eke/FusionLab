import AppKit
import SwiftUI

extension ProtocolTests {
 @MainActor func testRenderedPTTSize() async throws {
  _=NSApplication.shared
  let host=NSHostingView(rootView:PTTButton(title:"PTT · Zenden",enabled:true,transmitting:false,onPress:{},onRelease:{}).frame(width:165,height:48))
  let window=NSWindow(contentRect:NSRect(x:0,y:0,width:165,height:48),styleMask:.borderless,backing:.buffered,defer:false)
  window.isReleasedWhenClosed=false;window.contentView=host
  defer{window.contentView=nil;window.close()}
  host.frame=NSRect(x:0,y:0,width:165,height:48)
  func findButton(_ view:NSView)->TrackingPTTButton? {
   if let button=view as? TrackingPTTButton {return button}
   for child in view.subviews {if let result=findButton(child){return result}}
   return nil
  }
  for _ in 0..<10 {
   host.layoutSubtreeIfNeeded()
   if findButton(host) != nil {break}
   try await Task.sleep(nanoseconds:20_000_000)
  }
  guard let button=findButton(host) else{XCTAssertEqual(false,true,"Native PTT view not created");return}
  print("PTT actual native bounds: \(button.bounds.width) × \(button.bounds.height)")
  XCTAssertEqual(button.bounds.height,CGFloat(48),"The native button must fill the 48-point SwiftUI frame")
  XCTAssertEqual(button.cell is PTTButtonCell,true)
  button.transmitting=true;button.title="● ZENDEN"
  func render()->NSBitmapImageRep {
   let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:165,pixelsHigh:48,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   NSGraphicsContext.saveGraphicsState()
   NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
   // Exercise the native cell path as well as its full control bounds.
   button.cell!.draw(withFrame:NSRect(x:0,y:0,width:165,height:48),in:button)
   NSGraphicsContext.restoreGraphicsState()
   return rep
  }
  for _ in 0..<20 {
   let rep=render()
   for y in [8,40] {
    let color=rep.colorAt(x:82,y:y)!.usingColorSpace(.deviceRGB)!
    XCTAssertEqual(color.redComponent>color.greenComponent+0.2 && color.redComponent>color.blueComponent+0.2,true,"Red background must cover the full button height on every cell redraw")
   }
  }
  // The transceiver panel gives the same native tracking button a taller
  // frame. Verify the entire clickable control follows that proposal.
  host.rootView=PTTButton(title:"PTT · Zenden",enabled:true,transmitting:false,onPress:{},onRelease:{}).frame(width:145,height:86)
  window.setContentSize(NSSize(width:145,height:86))
  host.frame=NSRect(x:0,y:0,width:145,height:86)
  host.layoutSubtreeIfNeeded()
  try await Task.sleep(nanoseconds:20_000_000)
  host.layoutSubtreeIfNeeded()
  XCTAssertEqual(findButton(host)?.bounds.height,CGFloat(86),"The transceiver PTT must fill its taller clickable frame")
  XCTAssertEqual(findButton(host)?.bounds.width,CGFloat(145))
  try render().representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"/private/tmp/FusionLab-PTT-render.png"))
 }
}
