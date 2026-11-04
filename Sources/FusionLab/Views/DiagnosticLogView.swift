import SwiftUI

// Audio meters refresh often. Re-render diagnostic text only when it changes.
struct DiagnosticLogView:View,Equatable {
 let text:String
 let onClear:()->Void
 @State private var expanded=false
 static func ==(lhs:Self,rhs:Self)->Bool {lhs.text==rhs.text}
 var body:some View {
  DisclosureGroup(isExpanded:$expanded){
   HStack{Text("Laatste 100 regels").font(.caption).foregroundStyle(.secondary);Spacer();Button("Wis log",action:onClear)}
   ScrollView {
    Text(text.isEmpty ? "Geen meldingen.":text)
     .font(.system(size:11,design:.monospaced)).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled).padding(8)
   }.background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:8)).frame(height:140)
  }label:{Text("Activiteitenlog").font(.headline)}
 }
}
