import SwiftUI

@main
struct FusionLabApp: App {
 @StateObject private var session=RadioSession(vocoderBackend:VocoderBackend.load())
 var body: some Scene {
  WindowGroup("FusionLab · PA3EKE") {
   ContentView(session:session).frame(minWidth:940,minHeight:640)
  }.defaultSize(width:1120,height:740)
  .commands {
   CommandGroup(replacing:.newItem){}
   CommandMenu("Radio"){
    Button("PTT aan/uit"){session.toggleTransmit()}.keyboardShortcut("t",modifiers:.command)
     .disabled(session.drainingTransmit || (!session.canTransmit && !session.transmitting && !session.preparingTransmit))
   }
  }
  Settings {XKeysSettingsView(controller:session.xkeys).padding(20).frame(width:720,height:660).preferredColorScheme(.dark).onAppear{session.startXKeys()}}
 }
}
