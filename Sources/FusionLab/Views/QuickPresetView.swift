import SwiftUI

struct QuickPresetView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 private var bindings:SessionBindings {SessionBindings(session:session)}
 @ObservedObject var hosts:YSFHostCatalog
 @ObservedObject var nxdnHosts:NXDNHostCatalog
 @State private var choosingSlot:Int?
 @State private var renamingSlot=0
 @State private var renaming=false
 @State private var name=""
 private var currentTitle:String? {
  session.selectedMode == .fusion ? hosts.hosts.first{$0.matches(host:session.host,port:session.port)}?.title:session.selectedMode == .nxdn ? nxdnHosts.hosts.first{$0.matches(session.nxdn)}?.title:nil
 }
 init(session s:RadioSession,hosts:YSFHostCatalog,nxdnHosts:NXDNHostCatalog){
  session=s
  self.hosts=hosts
  self.nxdnHosts=nxdnHosts
  renderState=ConsoleRenderState(values:[s.selectedMode.rawValue,s.nxdn.host,s.nxdn.port,s.nxdn.destination,s.nxdn.ran,s.canChoosePreset,s.host,s.port,s.dmr.destination,s.dmr.privateCall],presets:s.quickPresets)
 }
 var body:some View {
  VStack(alignment:.leading,spacing:6){
   HStack {
    Text(session.selectedMode == .fusion ? "Reflectorvoorkeuzes":session.selectedMode == .nxdn ? "NXDN-voorkeuzes":"DMR-voorkeuzes").font(.caption.bold())
    Spacer()
    Menu("Bewaar huidige"){
     ForEach(0..<8,id:\.self){i in Button("Toets \(i+1) · \(session.quickPresets[i]?.title ?? "leeg")"){session.saveCurrentPreset(at:i,title:currentTitle)}}
    }.font(.caption).fixedSize()
   }
   LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:4),spacing:6){
    ForEach(0..<8,id:\.self){i in
     let preset=session.quickPresets[i]
     Button {
      if preset != nil {session.activatePreset(at:i)}
      else {session.saveCurrentPreset(at:i,title:currentTitle)}
     }label:{
      HStack(spacing:5){
       Text("\(i+1)").font(.caption2).foregroundStyle(.secondary)
       Text(preset?.title ?? "Bewaar huidig").font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
      }.frame(maxWidth:.infinity)
     }.buttonStyle(ConsoleButtonStyle(selected:preset.map{session.presetIsSelected($0)} == true))
      .help(preset.map{"\($0.title) · \($0.detail). Klik om te kiezen; rechtsklik om te wijzigen."} ?? "Lege toets: klik om de huidige keuze te bewaren.")
      .accessibilityLabel("Voorkeuze \(i+1): \(preset?.title ?? "leeg, huidige keuze bewaren")")
      .contextMenu {
       Button("Huidige keuze hier bewaren"){session.saveCurrentPreset(at:i,title:currentTitle)}
       if session.selectedMode != .dmr {Button("Reflector uit lijst kiezen…"){choosingSlot=i}}
       if let preset {
        Button("Naam wijzigen…"){name=preset.title;renamingSlot=i;renaming=true}
        Button("Wissen",role:.destructive){session.setQuickPreset(nil,at:i)}
       }
      }
    }
   }.disabled(!session.canChoosePreset)
  }
  .sheet(isPresented:Binding(get:{choosingSlot != nil},set:{if !$0 {choosingSlot=nil}})){
   if session.selectedMode == .nxdn {
    NXDNHostPicker(catalog:nxdnHosts,configuration:session.nxdn){entry in
     if let i=choosingSlot {session.setQuickPreset(.nxdn(title:entry.title,host:entry.host,port:entry.port,destination:entry.number,ran:UInt8(clamping:session.nxdn.ran)),at:i)}
     choosingSlot=nil
    }
   }else {
   YSFHostPicker(catalog:hosts,currentHost:session.host,currentPort:session.port){entry in
    if let i=choosingSlot {session.setQuickPreset(.fusion(title:String(entry.title.prefix(40)),host:entry.host,port:entry.port),at:i)}
    choosingSlot=nil
   }
   }
  }
  .alert("Naam voorkeuze",isPresented:$renaming){
   TextField("Naam",text:$name)
   Button("Bewaren"){
    if let preset=session.quickPresets[renamingSlot] {session.setQuickPreset(preset.renamed(name),at:renamingSlot)}
   }
   Button("Annuleren",role:.cancel){}
  }
 }
}
