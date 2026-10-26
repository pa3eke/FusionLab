import SwiftUI

struct YSFHostPicker:View {
 @ObservedObject var catalog:YSFHostCatalog
 let currentHost:String,currentPort:String
 let choose:(YSFHost)->Void
 @Environment(\.dismiss) private var dismiss
 @State private var query=""
 @State private var selection:String?
 private var filtered:[YSFHost] {catalog.hosts.filter{$0.matches(query)}}
 private var selected:YSFHost? {filtered.first{$0.id==selection}}
 var body:some View {
  VStack(alignment:.leading,spacing:12){
   HStack {
    Text("YSF-reflector kiezen").font(.title2.bold());Spacer()
    Button("Lijst bijwerken"){Task{await catalog.refresh()}}.disabled(catalog.isLoading)
   }
   HStack {
    TextField("Zoek naam, nummer, omschrijving of host",text:$query).textFieldStyle(.roundedBorder)
    Button("Nederland"){query="NL-"}
    Button("Alles"){query=""}
   }
   List(selection:$selection){
    ForEach(filtered){host in
     VStack(alignment:.leading,spacing:3){
      Text(host.title).fontWeight(.medium)
      Text("\(host.description) · \(host.host):\(String(host.port))").font(.caption).foregroundStyle(.secondary)
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
    Link("Pi-Star · gegevens van DVRef",destination:YSFHostCatalog.source).font(.caption)
    Spacer()
    Button("Annuleren"){dismiss()}.keyboardShortcut(.cancelAction)
    Button("Kiezen"){if let host=selected {apply(host)}}.keyboardShortcut(.defaultAction).disabled(selected==nil)
   }
  }.padding(20).frame(width:660,height:500)
   .onAppear{selection=catalog.hosts.first{$0.matches(host:currentHost,port:currentPort)}?.id}
 }
 private func apply(_ host:YSFHost){choose(host);dismiss()}
}
