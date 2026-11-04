import SwiftUI

struct ContentView:View {
 @ObservedObject var session:RadioSession
 @StateObject private var hosts=YSFHostCatalog()
 @StateObject private var nxdnHosts=NXDNHostCatalog()
 @State private var setup=false
 @State private var engineering=false
 var body:some View {
  GeometryReader {geometry in
   let centerWidth=max(1,geometry.size.width-323)
   ScrollView(.vertical){
    VStack(spacing:6){
     header
     HStack(alignment:.top,spacing:12){
      modeRail.frame(width:80)
      VStack(spacing:6){
       ReceiverDisplayView(session:session,hosts:hosts).equatable()
       DestinationControlView(session:session,hosts:hosts,nxdnHosts:nxdnHosts).equatable()
       ConsolePanel(title:""){QuickPresetView(session:session,hosts:hosts,nxdnHosts:nxdnHosts).equatable()}
       HStack(alignment:.top,spacing:12){
        ConsolePanel(title:"Audio"){AudioControlView(session:session).equatable()}.frame(width:(centerWidth-12)/2)
        ConsolePanel(title:"Microfoon"){MicrophoneControlView(session:session).equatable()}.frame(width:(centerWidth-12)/2)
       }
      }.frame(width:centerWidth)
      VStack(spacing:14){
       ConsolePanel(title:"Geheugen / select"){PresetSelectionView(session:session).equatable()}
       ConsolePanel(title:""){PTTControlView(session:session).equatable()}
      }.frame(width:195)
     }
     footer
    }.padding(12)
   }.scrollBounceBehavior(.basedOnSize)
  }
  .background(ConsolePalette.background).preferredColorScheme(.dark)
  .sheet(isPresented:$setup){ConsoleSettingsView(session:session,hosts:hosts,nxdnHosts:nxdnHosts)}
  .sheet(isPresented:$engineering){EngineeringView(session:session)}
  .onAppear{session.restoreDMRPasswordIfNeeded();session.startXKeys()}
  .onExitCommand{session.stopTransmit()}
  .onReceive(NotificationCenter.default.publisher(for:NSApplication.willResignActiveNotification)){_ in session.handleFocusLoss()}
  .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)){_ in session.stopXKeys();session.disconnect()}
  .onReceive(NotificationCenter.default.publisher(for:NSWindow.willCloseNotification)){note in
   if let window=note.object as? NSWindow,window.title.hasPrefix("FusionLab ·") {session.stopXKeys();session.disconnect()}
  }
 }
 private var header:some View {
  HStack{
   (Text("Fusion").foregroundColor(.white)+Text("Lab").foregroundColor(.cyan)).font(.system(size:27,weight:.bold,design:.rounded)).italic()
   Text(session.call).font(.headline.monospaced()).foregroundStyle(.secondary)
   Spacer()
   Text("0.7.3").font(.caption).foregroundStyle(.secondary)
   Button("Engineering",systemImage:"waveform.path.ecg"){engineering=true}
   Button("Setup",systemImage:"gearshape.fill"){setup=true}
  }.padding(.horizontal,6)
 }
 private var modeRail:some View {
  VStack(spacing:10){
   modeButton("DMR",mode:.dmr)
   Button("D-STAR"){}.buttonStyle(ConsoleButtonStyle()).disabled(true).opacity(0.35).help("D-STAR is nog niet beschikbaar in FusionLab")
   modeButton("C4FM",mode:.fusion)
   modeButton("NXDN",mode:.nxdn)
   Button{setup=true}label:{VStack(spacing:6){Image(systemName:"gearshape.fill").font(.title2);Text("SETUP").font(.caption)}}.buttonStyle(ConsoleButtonStyle())
  }
 }
 private func modeButton(_ title:String,mode:DigitalMode)->some View {
  Button(title){session.requestMode(mode);if !session.connectionError.isEmpty {setup=true}}.buttonStyle(ConsoleButtonStyle(selected:session.selectedMode==mode)).disabled(!session.canSwitchMode).help(session.active ? "Wissel automatisch naar \(title) met dezelfde vocoder":title)
 }
 private var footer:some View {
  HStack(spacing:8){
   Circle().fill(session.readyToTransmit ? Color.green:Color.secondary).frame(width:9,height:9)
   Text(session.modeSwitchTarget.map{"Wisselen naar \($0.title)…"} ?? session.ysfStatus).lineLimit(1)
   Spacer()
   Text(session.ambeStatus).lineLimit(1).foregroundStyle(.secondary)
   Button(session.switchingMode ? "Annuleren":session.active ? "Ontkoppelen":"Verbinden"){
    if session.active || session.switchingMode {session.disconnect()}else{session.connect();if !session.connectionError.isEmpty {setup=true}}
   }.buttonStyle(.borderedProminent)
    .disabled(!session.active && !session.switchingMode && session.selectedVocoder == .ambeServer && !session.exclusive)
    .keyboardShortcut(.return,modifiers:.command)
  }.font(.caption).padding(10).background(Color.white.opacity(0.04),in:RoundedRectangle(cornerRadius:8))
 }
}
