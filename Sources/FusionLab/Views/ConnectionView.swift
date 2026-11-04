import SwiftUI

struct ConnectionView:View {
 @ObservedObject var session:RadioSession
 @ObservedObject var hosts:YSFHostCatalog
 @ObservedObject var nxdnHosts:NXDNHostCatalog
 @State private var choosingHost=false
 @State private var choosingNXDN=false
 private var reflectorTitle:String {hosts.hosts.first{$0.matches(host:session.host,port:session.port)}?.title ?? "Eigen host / IP"}
 var body:some View {
  GroupBox("Verbindingen") {
   VStack(alignment:.leading,spacing:12){
    Picker("Mode",selection:Binding(get:{session.selectedMode},set:{session.requestMode($0)})){
     ForEach(DigitalMode.allCases){Text($0.title).tag($0)}
    }.pickerStyle(.segmented).disabled(!session.canSwitchMode)
    Picker("Vocoder",selection:Binding(get:{session.selectedVocoder},set:{session.selectVocoder($0)})){
     ForEach(VocoderBackend.allCases){Text($0.title).tag($0)}
    }.disabled(session.active)
    Grid(alignment:.leading,horizontalSpacing:12,verticalSpacing:10){
     GridRow{Text("Mijn call");TextField("PA3EKE",text:$session.call);Text("");Text("")}
     if session.selectedMode == .fusion {
     GridRow{
      Text("YSF-reflector")
      Button{choosingHost=true}label:{HStack{Text(reflectorTitle).lineLimit(1);Spacer();Image(systemName:"chevron.up.chevron.down").font(.caption)}}
       .accessibilityLabel("YSF-reflector kiezen").gridCellColumns(3)
     }
     GridRow{Text("YSF-host");TextField("Hostnaam of IP",text:$session.host);Text("Poort");TextField("42000",text:$session.port).frame(width:68)}
     }
     if session.selectedVocoder == .ambeServer {
      GridRow{Text("AMBEserver");TextField("IP-adres",text:$session.ambeHost);Text("Poort");TextField("2460",text:$session.ambePort).frame(width:68)}
     }
    }.textFieldStyle(.roundedBorder).disabled(session.active)
    if session.selectedMode == .dmr {DMRConnectionView(session:session)}
    if session.selectedMode == .nxdn {
     GroupBox("NXDN · 4800 · groepsspraak"){
      Grid(alignment:.leading,horizontalSpacing:12,verticalSpacing:10){
       GridRow{Text("NXDN-ID");TextField("Apart NXDN-ID",text:$session.nxdn.radioID);Text("RAN");Stepper("\(session.nxdn.ran)",value:$session.nxdn.ran,in:0...63)}
       GridRow{Text("Reflector");Button("TG \(session.nxdn.destination) · kiezen…"){choosingNXDN=true}.gridCellColumns(3)}
       GridRow{Text("Host");TextField("Hostnaam of IP",text:$session.nxdn.host);Text("Poort");TextField("41400",text:$session.nxdn.port).frame(width:68)}
       GridRow{Text("Talkgroup");TextField("204",text:$session.nxdn.destination);Text("");Text("")}
      }.textFieldStyle(.roundedBorder).padding(6).disabled(session.active)
     }
    }
    if session.selectedVocoder == .ambeServer {
     Toggle("MacDV en andere clients zijn losgekoppeld van de AMBEserver",isOn:$session.exclusive).font(.caption).disabled(session.active)
    }else{Text("MD380 verwerkt de spraak lokaal op deze Mac; geen AMBEserver nodig.").font(.caption).foregroundStyle(.secondary)}
    HStack {
     Text(session.selectedMode == .fusion ? "YSF-ingang van een reflector of XLX. Alleen Fusion DN V/D2.":session.selectedMode == .nxdn ? "NXDNReflector · 4800 · AMBE49 · apart NXDN-ID vereist.":"BrandMeister · DMR via \(session.selectedVocoder.title)").font(.caption).foregroundStyle(.secondary)
     Spacer()
     Button(session.switchingMode ? "Annuleren":session.active ? "Ontkoppelen":"Verbinden") {if session.active || session.switchingMode{session.disconnect()}else{session.connect()}}
      .buttonStyle(.borderedProminent).disabled(!session.active && !session.switchingMode && session.selectedVocoder == .ambeServer && !session.exclusive)
    }
    if !session.connectionError.isEmpty {
     Label(session.connectionError,systemImage:"exclamationmark.triangle.fill")
      .font(.caption).foregroundStyle(.red).fixedSize(horizontal:false,vertical:true)
    }
   }.padding(6)
  }
  .sheet(isPresented:$choosingHost){YSFHostPicker(catalog:hosts,currentHost:session.host,currentPort:session.port){session.selectReflector($0)}}
  .sheet(isPresented:$choosingNXDN){NXDNHostPicker(catalog:nxdnHosts,configuration:session.nxdn){session.selectNXDNReflector($0)}}
 }
}
