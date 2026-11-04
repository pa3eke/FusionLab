import SwiftUI

struct ConsoleSettingsView:View {
 @ObservedObject var session:RadioSession
 @ObservedObject var hosts:YSFHostCatalog
 @ObservedObject var nxdnHosts:NXDNHostCatalog
 @Environment(\.dismiss) private var dismiss
 @State private var page=0
 var body:some View {
  VStack(alignment:.leading,spacing:14){
   HStack{Text("FusionLab · Setup").font(.title2.bold());Spacer();Button("Gereed"){dismiss()}.keyboardShortcut(.cancelAction)}
   Picker("Instellingen",selection:$page){Text("Radio").tag(0);Text("X-keys").tag(1)}.pickerStyle(.segmented)
   ScrollView{
    if page==1 {XKeysSettingsView(controller:session.xkeys)}else{
    ConnectionView(session:session,hosts:hosts,nxdnHosts:nxdnHosts)
    GroupBox("Audio en bediening"){
     VStack(alignment:.leading,spacing:12){
      Text("Microfoon, versterking, AGC, EQ, PTT-modus en maximale zendtijd staan op het radiopaneel. De vocoder en AMBEserver stel je hierboven in.").font(.callout)
      QuickPresetView(session:session,hosts:hosts,nxdnHosts:nxdnHosts).equatable()
     }.padding(8)
    }
    }
   }
  }.padding(20).frame(width:720,height:680).preferredColorScheme(.dark)
 }
}

struct EngineeringView:View {
 @ObservedObject var session:RadioSession
 @Environment(\.dismiss) private var dismiss
 var body:some View {
  VStack(alignment:.leading,spacing:16){
   HStack{Text("Engineering").font(.title2.bold());Spacer();Button("Gereed"){dismiss()}.keyboardShortcut(.cancelAction)}
   Text("Cumulatieve aantallen van de huidige verbinding").font(.caption).foregroundStyle(.secondary)
   HStack{
    counter(session.selectedMode.shortTitle,session.networkFrames)
    Spacer();counter("AMBE",session.voiceFrames);Spacer();counter("PCM",session.pcmFrames)
    Spacer();if session.selectedMode == .nxdn {VStack{Text("Verlies").font(.caption);Text("—").help("NXDN-pakketten hebben geen volgnummer")}}else{counter("Verlies",session.dropped)};Spacer();counter("Fouten",session.errors)
   }
   Text(session.receptionDetail.isEmpty ? "Nog geen ontvangststatistieken.":session.receptionDetail).font(.caption.monospaced()).textSelection(.enabled)
   Text("Microfoon \(session.microphoneFrames) → encoder \(session.encodedFrames) → netwerk \(session.transmittedFrames)").font(.caption.monospaced())
   Text(session.ysfStatus);Text(session.ambeStatus)
   DiagnosticLogView(text:session.log,onClear:{session.log=""}).equatable()
   Spacer()
  }.padding(20).frame(width:720,height:480).preferredColorScheme(.dark)
 }
 private func counter(_ title:String,_ value:Int)->some View {VStack(alignment:.leading){Text(title).font(.caption).foregroundStyle(.secondary);Text("\(value)").font(.title3.monospacedDigit())}}
}
