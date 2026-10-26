import SwiftUI

@main
struct FusionLabApp: App {
 @StateObject private var session=RadioSession()
 var body: some Scene {
  WindowGroup("FusionLab · PA3EKE") {
   ContentView(session:session).frame(minWidth:660,minHeight:760)
  }.defaultSize(width:760,height:820)
  .commands {
   CommandGroup(replacing:.newItem){}
   CommandMenu("Radio"){
    Button("PTT aan/uit"){session.toggleTransmit()}.keyboardShortcut("t",modifiers:.command)
     .disabled(session.drainingTransmit || (!session.canTransmit && !session.transmitting && !session.preparingTransmit))
   }
  }
 }
}
