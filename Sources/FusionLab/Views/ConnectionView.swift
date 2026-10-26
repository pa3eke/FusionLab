import SwiftUI

struct ConnectionView:View {
 @ObservedObject var session:RadioSession
 @ObservedObject var hosts:YSFHostCatalog
 @State private var choosingHost=false
 private var reflectorTitle:String {hosts.hosts.first{$0.matches(host:session.host,port:session.port)}?.title ?? "Eigen host / IP"}
 var body:some View {
  GroupBox("Verbindingen") {
   VStack(alignment:.leading,spacing:12){
    Picker("Mode",selection:Binding(get:{session.selectedMode},set:{session.selectMode($0)})){
     ForEach(DigitalMode.allCases){Text($0.title).tag($0)}
    }.pickerStyle(.segmented).disabled(session.active)
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
     GridRow{Text("AMBEserver");TextField("IP-adres",text:$session.ambeHost);Text("Poort");TextField("2460",text:$session.ambePort).frame(width:68)}
    }.textFieldStyle(.roundedBorder).disabled(session.active)
    if session.selectedMode == .dmr {DMRConnectionView(session:session)}
    Toggle("MacDV en andere clients zijn losgekoppeld van de AMBEserver",isOn:$session.exclusive).font(.caption).disabled(session.active)
    HStack {
     Text(session.selectedMode == .fusion ? "YSF-ingang van een reflector of XLX. Alleen Fusion DN V/D2.":"BrandMeister · DMR via AMBEserver").font(.caption).foregroundStyle(.secondary)
     Spacer()
     Button(session.active ? "Ontkoppelen":"Verbinden") {if session.active{session.disconnect()}else{session.connect()}}
      .buttonStyle(.borderedProminent).disabled(!session.active && !session.exclusive).keyboardShortcut(.return,modifiers:.command)
    }
    if !session.connectionError.isEmpty {
     Label(session.connectionError,systemImage:"exclamationmark.triangle.fill")
      .font(.caption).foregroundStyle(.red).fixedSize(horizontal:false,vertical:true)
    }
   }.padding(6)
  }
  .sheet(isPresented:$choosingHost){YSFHostPicker(catalog:hosts,currentHost:session.host,currentPort:session.port){session.selectReflector($0)}}
 }
}
