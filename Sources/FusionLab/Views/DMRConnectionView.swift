import SwiftUI

struct DMRConnectionView:View {
 @ObservedObject var session:RadioSession
 var body:some View {
  VStack(alignment:.leading,spacing:10){
   Grid(alignment:.leading,horizontalSpacing:12,verticalSpacing:10){
    GridRow {
     Text("BrandMeister")
     Picker("Master",selection:$session.dmr.host){
      Text("Nederland · 2041").tag("2041.master.brandmeister.network")
      Text("België · 2061").tag("2061.master.brandmeister.network")
      Text("Duitsland · 2621").tag("2621.master.brandmeister.network")
      if !["2041.master.brandmeister.network","2061.master.brandmeister.network","2621.master.brandmeister.network"].contains(session.dmr.host){Text("Eigen master").tag(session.dmr.host)}
     }.labelsHidden().gridCellColumns(3)
    }
    GridRow{Text("Master-host");TextField("Hostnaam",text:$session.dmr.host);Text("Poort");TextField("62031",text:$session.dmr.port).frame(width:68)}
    GridRow{Text("DMR-ID");TextField("7 cijfers",text:$session.dmr.radioID);Text("SSID");TextField("Optioneel",text:$session.dmr.ssid).frame(width:68)}
    GridRow{
     Text("Tijdslot")
     Picker("Tijdslot",selection:$session.dmr.slot){Text("TS1").tag(1);Text("TS2").tag(2)}.labelsHidden()
     Text("");Text("")
    }
    GridRow{
     Text("Hotspot Security")
     SecureField("Hotspotwachtwoord",text:$session.dmrPassword)
     Text("Color code")
     Picker("Color code",selection:$session.dmr.colorCode){ForEach(0..<16){Text(String($0)).tag($0)}}.labelsHidden().frame(width:68)
    }
   }.textFieldStyle(.roundedBorder).disabled(session.active)
   HStack {
    Text("Bestemming")
    TextField("Talkgroup of DMR-ID",text:$session.dmr.destination).textFieldStyle(.roundedBorder)
    Toggle("Privé",isOn:$session.dmr.privateCall)
    Button("Echo 9990"){session.dmr.destination="9990";session.dmr.privateCall=true}
   }.disabled(session.transmitting || session.preparingTransmit)
   HStack {
    Toggle("Bewaar wachtwoord in Sleutelhanger",isOn:$session.rememberDMRPassword).font(.caption)
    Button("Ophalen"){session.loadDMRPassword()}.font(.caption)
    Spacer()
   }.disabled(session.active)
   Text("Je eigen 7-cijferige DMR-ID en het Hotspot Security-wachtwoord uit BrandMeister SelfCare. Een talkgroup wordt actief na jouw PTT; kies Privé voor een individuele oproep of echo.")
    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
  }
 }
}
