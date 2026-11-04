import SwiftUI

struct DestinationControlView:ConsoleRegionView {
 let session:RadioSession
 let renderState:ConsoleRenderState
 private var bindings:SessionBindings {SessionBindings(session:session)}
 @ObservedObject var hosts:YSFHostCatalog
 @ObservedObject var nxdnHosts:NXDNHostCatalog
 @State private var choosing=false
 @State private var choosingNXDN=false
 init(session s:RadioSession,hosts:YSFHostCatalog,nxdnHosts:NXDNHostCatalog){
  session=s
  self.hosts=hosts
  self.nxdnHosts=nxdnHosts
  renderState=ConsoleRenderState(values:[s.selectedMode.rawValue,s.nxdn.host,s.nxdn.port,s.nxdn.destination,s.nxdn.ran,s.dmr.destination,s.dmr.privateCall,s.canChoosePreset,s.active])
 }
 var body:some View {
  HStack{
   if session.selectedMode == .dmr {
    Text("Bestemming").font(.caption)
    TextField("TG / DMR-ID",text:bindings.dmr.destination).textFieldStyle(.roundedBorder).frame(maxWidth:130)
    Toggle("Privé",isOn:bindings.dmr.privateCall).font(.caption)
    Spacer()
    Button("Echo 9990"){session.dmr.destination="9990";session.dmr.privateCall=true}.font(.caption)
   }else if session.selectedMode == .nxdn {
    Text("NXDN · TG \(session.nxdn.destination)").font(.caption)
    Text(session.nxdn.host).font(.caption).foregroundStyle(.secondary).lineLimit(1)
    Spacer()
    Button("Reflector kiezen…"){choosingNXDN=true}
   }else {
    Text("YSF-reflector").font(.caption)
    Spacer()
    Button("Kiezen uit lijst…"){choosing=true}.disabled(session.active)
   }
  }.disabled(!session.canChoosePreset)
   .sheet(isPresented:$choosing){YSFHostPicker(catalog:hosts,currentHost:session.host,currentPort:session.port){entry in
    // The catalogue edits a disconnected endpoint; live switching uses
    // the existing quick-preset path. No user memory is overwritten.
    if !session.active {session.selectReflector(entry)}
   }}
   .sheet(isPresented:$choosingNXDN){NXDNHostPicker(catalog:nxdnHosts,configuration:session.nxdn){session.selectNXDNReflector($0)}}
   .help(session.selectedMode == .fusion && session.active ? "Gebruik een voorkeuzetoets voor wisselen tijdens een verbinding; ontkoppel om een nieuwe reflector uit de lijst te kiezen.":"Bestemming voor de volgende PTT")
 }
}
