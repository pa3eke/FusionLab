import SwiftUI

enum ConsolePalette {
 static let background=Color(red:16/255,green:18/255,blue:20/255)
 static let panel=Color(red:27/255,green:29/255,blue:32/255)
 static let edge=Color(red:58/255,green:61/255,blue:66/255)
 static let active=Color(red:0,green:124/255,blue:189/255)
}

struct ConsolePanel<Content:View>:View {
 let title:String
 @ViewBuilder var content:Content
 var body:some View {
  VStack(alignment:.leading,spacing:10){
   if !title.isEmpty {Text(title.uppercased()).font(.caption.bold()).foregroundStyle(.orange)}
   content
  }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
   .background(LinearGradient(colors:[ConsolePalette.panel,Color(red:17/255,green:19/255,blue:21/255)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:12))
   .overlay(RoundedRectangle(cornerRadius:12).stroke(ConsolePalette.edge))
 }
}

struct ConsoleButtonStyle:ButtonStyle {
 var selected=false
 func makeBody(configuration:Configuration)->some View {
  configuration.label.font(.headline).padding(.vertical,12).frame(maxWidth:.infinity)
   .background(LinearGradient(colors:selected ? [ConsolePalette.active,Color(red:0,green:0.24,blue:0.38)]:[Color(red:0.18,green:0.2,blue:0.22),Color(red:0.09,green:0.1,blue:0.11)],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:7))
   .overlay(RoundedRectangle(cornerRadius:7).stroke(selected ? Color.cyan:Color.white.opacity(0.2),lineWidth:selected ? 2:1))
   .opacity(configuration.isPressed ? 0.65:1)
 }
}
