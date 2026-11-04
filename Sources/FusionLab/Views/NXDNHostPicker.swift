import SwiftUI

struct NXDNHostPicker:View {
 @ObservedObject var catalog:NXDNHostCatalog
 let configuration:NXDNConfiguration
 let choose:(NXDNHost)->Void
 @Environment(\.dismiss) private var dismiss
 @State private var query=""
 @State private var selection:String?
 private var filtered:[NXDNHost] {catalog.hosts.filter{$0.matches(query)}}
 private var selected:NXDNHost? {filtered.first{$0.id==selection}}
 var body:some View {
  VStack(alignment:.leading,spacing:12){
   HStack {
    Text("NXDN-reflector kiezen").font(.title2.bold());Spacer()
    Button("Lijst bijwerken"){Task{await catalog.refresh()}}.disabled(catalog.isLoading)
   }
   HStack {
    TextField("Zoek TG-nummer of host",text:$query).textFieldStyle(.roundedBorder)
    Button("TG 204"){query="204"}
    Button("Alles"){query=""}
   }
   List(selection:$selection){
    ForEach(filtered){host in
     VStack(alignment:.leading,spacing:3){
      Text(host.title).fontWeight(.medium)
      Text("\(host.host):\(String(host.port))").font(.caption).foregroundStyle(.secondary)
     }.padding(.vertical,3).frame(maxWidth:.infinity,alignment:.leading)
      .contentShape(Rectangle()).tag(host.id)
      .onTapGesture(count:2){apply(host)}.onTapGesture{selection=host.id}
    }
   }.overlay{if filtered.isEmpty {Text("Geen reflectoren gevonden").foregroundStyle(.secondary)}}
   HStack {
    if catalog.isLoading {ProgressView().controlSize(.small)}
    Text(catalog.isLoading ? "Lijst ophalen…":catalog.status).font(.caption).foregroundStyle(.secondary)
    Spacer();Text("\(filtered.count) zichtbaar").font(.caption).foregroundStyle(.secondary)
   }
   HStack {
    Link("Pi-Star · gegevens van DVRef",destination:NXDNHostCatalog.source).font(.caption)
    Spacer()
    Button("Annuleren"){dismiss()}.keyboardShortcut(.cancelAction)
    Button("Kiezen"){if let host=selected {apply(host)}}.keyboardShortcut(.defaultAction).disabled(selected==nil)
   }
  }.padding(20).frame(width:660,height:500)
   .onAppear{selection=catalog.hosts.first{$0.matches(configuration)}?.id}
 }
 private func apply(_ host:NXDNHost){choose(host);dismiss()}
}
