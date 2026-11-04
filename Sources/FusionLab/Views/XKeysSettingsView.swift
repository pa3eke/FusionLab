import SwiftUI

struct XKeysSettingsView:View {
 @ObservedObject var controller:XKeysController
 @State private var selected=0
 var body:some View {
  VStack(alignment:.leading,spacing:10){
   HStack {
    Toggle("X-keys ondersteuning",isOn:$controller.settings.enabled).toggleStyle(.switch)
    Spacer();Toggle("LED-feedback",isOn:$controller.settings.leds)
   }
   HStack(alignment:.top){
    Circle().fill(controller.ready ? Color.green:Color.secondary).frame(width:9,height:9).padding(.top,4)
    VStack(alignment:.leading,spacing:3){
     Text(controller.status).font(.callout).fixedSize(horizontal:false,vertical:true)
     ForEach(controller.devices.values.sorted{$0.source<$1.source},id:\.source){info in Text(info.title).font(.caption.monospaced()).foregroundStyle(.secondary)}
    }
    Spacer();Button("Opnieuw zoeken"){controller.reconnect()}.disabled(!controller.settings.enabled)
   }
   LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:4),spacing:6){
    ForEach(0..<24,id:\.self){position in
     let key=(position%4)*6+position/4,binding=controller.settings.bindings[key]
     Button{selected=key}label:{
      VStack(spacing:3){
       Text("\(key+1)").font(.caption.bold())
       Text(binding.title).font(.system(size:10)).lineLimit(1).minimumScaleFactor(0.6)
      }.frame(maxWidth:.infinity,minHeight:37)
       .foregroundStyle(.white)
       .background(controller.pressed.contains(key) ? Color.blue.opacity(0.65):Color.clear,in:RoundedRectangle(cornerRadius:5))
     }.buttonStyle(ConsoleButtonStyle(selected:selected==key))
      .help("Kolom \(key/6+1), rij \(key%6+1) · HID \(XKeysReport.ledIndex(key))")
      .accessibilityLabel("X-keys toets \(key+1), \(binding.title)\(controller.pressed.contains(key) ? ", ingedrukt":"")")
    }
   }
   GroupBox("Toets \(selected+1) · kolom \(selected/6+1), rij \(selected%6+1)"){
    HStack{
     Picker("Functie",selection:$controller.settings.bindings[selected].action){ForEach(XKeysAction.allCases){Text($0.title).tag($0)}}
     if controller.settings.bindings[selected].action == .ptt {
      Picker("PTT",selection:$controller.settings.bindings[selected].mode){ForEach(XKeysPTTMode.allCases){Text($0.title).tag($0)}}.frame(width:190)
     }
     Button("Wissen"){controller.settings.bindings[selected]=XKeysBinding()}
    }.padding(6)
   }
   HStack {
    Button("Standaardindeling herstellen"){controller.restoreDefaults()}
    Spacer();Text(controller.lastKey.map{"Laatste toets: \($0+1)"} ?? "Laatste toets: —").font(.caption)
    Text("\(controller.eventCount) toets-events").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
   }
   Toggle("Testen zonder acties — ook geen PTT",isOn:$controller.testMode).font(.callout)
   Text("De toetsen werken ook met een andere app op de voorgrond. Elke PTT-toets heeft een eigen verzoek; de laatste actieve bron laat TX los. PTT OFF stopt alle bronnen. Bij vergrendelen of slaap stopt TX; ontgrendelen start geen uitzending.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
   Text("Gebruik softwaremodus PID #1/#3. Sluit macrosoftware en de X-keys-bediening van MacDV om dubbele macro’s of conflicterende LEDs te voorkomen. Er worden geen macro’s, PIDs of EEPROM-instellingen gewijzigd.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
  }
 }
}
