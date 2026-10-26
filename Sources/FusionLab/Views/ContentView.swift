import SwiftUI

struct ContentView: View {
 @ObservedObject var session:RadioSession
 @StateObject private var hosts=YSFHostCatalog()
 var body:some View {
  ScrollView {
  VStack(alignment:.leading,spacing:16){
   HStack(spacing:12){
    Image(systemName:"antenna.radiowaves.left.and.right").font(.largeTitle).foregroundStyle(.tint)
    VStack(alignment:.leading){Text("FusionLab").font(.title.bold());Text("Fusion · YSF / DMR · BrandMeister · 0.4.9").foregroundStyle(.secondary)}
    Spacer()
    Text(session.call).font(.title3.monospaced().bold())
   }
   ConnectionView(session:session,hosts:hosts)
   GroupBox {
    VStack(alignment:.leading,spacing:8){
     HStack{Label(session.mode,systemImage:"waveform").foregroundStyle(.secondary);Spacer();Text(session.transmitting ? "TX":"RX").font(.headline).foregroundStyle(session.transmitting ? .red:session.level>0 ? .green:.secondary)}
     Group {
      if let url=session.receivedStationQRZURL {
       Link(session.station,destination:url).help("Open de ontvangen roepnaam op QRZ.com")
      }else {
       Text(session.transmitting ? session.call:session.station).textSelection(.enabled)
      }
     }.font(.system(size:30,weight:.bold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.5)
     HStack{Text("Gateway: \(session.gateway)").font(.caption);Spacer();Image(systemName:"speaker.wave.2");Slider(value:$session.volume,in:0...1).frame(width:130);Text("\(Int(session.volume*100))%").monospacedDigit().frame(width:40)}
     Toggle("Ontvangst AGC · automatisch volume",isOn:$session.receiveAGCEnabled)
      .font(.caption).help("Maakt zachte en harde stations gelijkmatiger hoorbaar. Werkt alleen op ontvangst; de volumeregelaar bepaalt je luistersterkte.")
     ReceiveEQView(session:session)
     ProgressView(value:Double(min(session.level*4,1))).tint(.green)
     HStack {counter(session.selectedMode == .fusion ? "YSF":"DMR",session.networkFrames);Spacer();counter("AMBE",session.voiceFrames);Spacer();counter("PCM",session.pcmFrames);Spacer();counter("Verlies",session.dropped);Spacer();counter("Fouten",session.errors)}.padding(.top,4)
     if !session.receptionDetail.isEmpty {Text(session.receptionDetail).font(.caption.monospaced()).foregroundStyle(.secondary)}
    }.padding(8)
   }
   TransmitView(session:session)
   HStack{Label(session.ysfStatus,systemImage:"network");Spacer();Label(session.ambeStatus,systemImage:"cpu")}.font(.caption)
   VStack(alignment:.leading,spacing:6){
    HStack{Text("Diagnostiek").font(.headline);Spacer();Button("Wis log"){session.log=""}.disabled(session.active)}
    ScrollView {
     Text(session.log.isEmpty ? "Klaar voor de eerste spraaktest. Er wordt niet automatisch verbonden.":session.log)
      .font(.system(size:11,design:.monospaced)).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled).padding(10)
    }.background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:8)).frame(minHeight:90)
   }
  }.padding(20)
  }
   .onExitCommand{session.stopTransmit()}
   .onReceive(NotificationCenter.default.publisher(for:NSApplication.willResignActiveNotification)){_ in session.handleFocusLoss()}
   .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)){_ in session.disconnect()}
   .onDisappear{session.disconnect()}
 }
 private func counter(_ title:String,_ n:Int)->some View {
  VStack(alignment:.leading){Text(title).font(.caption).foregroundStyle(.secondary);Text("\(n)").monospacedDigit().font(.headline)}
 }
}
