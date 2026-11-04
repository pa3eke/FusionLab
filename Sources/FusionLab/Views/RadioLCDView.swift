import SwiftUI

// Read-only presentation of existing session values. No protocol, audio or
// PTT state is created or changed by this display.
struct RadioLCDPresentation:Equatable {
 var modeTitle:String
 var badges:[String]
 var callsign:String
 var stationLabel:String
 var identifier:String?
 var identifierLabel:String?
 var destination:String
 var destinationLabel:String
 var network:String
 var status:String
 var transmitting:Bool
 var connected:Bool
 var connection:String
 var detail:String
 var error:String
 var level:Float
 var qrzURL:URL?
 init(session s:RadioSession,reflectorTitle:String?=nil){
  modeTitle=s.selectedMode == .fusion ? "C4FM":s.selectedMode.shortTitle
  let parts=s.station.components(separatedBy:" · ")
  let waiting=s.station.isEmpty || s.station=="Wachten op ontvangst" || s.station=="—"
  let numeric=parts.last.flatMap{UInt32($0.trimmingCharacters(in:.whitespaces)).map{String($0)}}
  callsign=s.transmitting ? s.call:waiting || (parts.count==1 && numeric != nil) ? "—":parts[0]
  stationLabel=s.transmitting ? "MIJN CALL":waiting ? "WACHTEN OP ONTVANGST":numeric != nil && parts.count==1 ? "ROEPNAAM NIET BESCHIKBAAR":"ONTVANGEN STATION"
  switch s.selectedMode {
  case .dmr:
   badges=["TS\(s.dmr.slot)","CC \(s.dmr.colorCode)"];network="BrandMeister"
   identifier=s.transmitting ? Self.numeric(s.dmr.radioID):numeric;identifierLabel="DMR ID"
   destination="\(s.dmr.privateCall ? "Privé":"TG") \(s.dmr.destination)";destinationLabel="BESTEMMING"
  case .nxdn:
   badges=["RAN \(s.nxdn.ran)"];network="NXDN"
   identifier=s.transmitting ? Self.numeric(s.nxdn.radioID):numeric;identifierLabel="NXDN ID"
   destination="TG \(s.nxdn.destination)";destinationLabel="BESTEMMING"
  case .fusion:
   badges=["DN"];network="YSF";identifier=nil;identifierLabel=nil
   destination=reflectorTitle ?? "\(s.host):\(s.port)";destinationLabel="REFLECTOR"
  }
  // During actual RX show the destination supplied by the existing receive
  // status. At stand-by/TX show the selected target for the next/current PTT.
  if s.receivingAudio,!s.transmitting,s.selectedMode != .fusion {
   if let received=s.mode.components(separatedBy:" · ").first(where:{$0.hasPrefix("TG ") || $0.hasPrefix("Privé ")}) {destination=received}
  }
  transmitting=s.transmitting
  connected=s.active && s.readyToTransmit
  status=s.transmitting ? (s.drainingTransmit ? "TX · EINDE":"TX"):s.preparingTransmit ? "MIC":!s.active ? "LOS":s.receivingAudio ? "RX":s.readyToTransmit ? "STAND-BY":"VERBINDEN"
  connection=s.modeSwitchTarget.map{"Wisselen naar \($0.title)…"} ?? s.ysfStatus
  detail=s.gateway=="—" ? s.mode:s.gateway
  if s.selectedMode == .fusion {detail += " · MIJN CALL \(s.call) · \(s.host):\(s.port)"}
  error=s.connectionError;level=s.level
  qrzURL=s.transmitting ? nil:s.receivedStationQRZURL
 }
 // Use directory metadata only; never resolve DNS or alter the endpoint here.
 static func reflectorTitle(host:String,port:String,hosts:[YSFHost],presets:[QuickPreset?])->String? {
  if let entry=hosts.first(where:{$0.matches(host:host,port:port)}) {return entry.name}
  return presets.compactMap{$0}.first{preset in
   guard case .fusion(_,let name,let p)=preset else{return false}
   return name.caseInsensitiveCompare(host.trimmingCharacters(in:.whitespacesAndNewlines)) == .orderedSame && UInt16(port)==p
  }?.title
 }
 private static func numeric(_ value:String)->String? {UInt32(value).map{String($0)}}
 var audioDBFS:Double? {guard level.isFinite,level>0 else{return nil};return 20*log10(Double(level))}
 var audioText:String {
  guard let db=audioDBFS else{return "−∞ dBFS"}
  let rounded=db.rounded()
  return String(format:rounded>0 ? "+%.0f dBFS":"%.0f dBFS",rounded==0 ? 0:rounded)
 }
 var activeSegments:Int {guard let db=audioDBFS else{return 0};return min(40,max(0,Int(ceil((db+60)/60*40))))}
}

enum LCDPalette {
 static let ink=Color(red:7/255,green:55/255,blue:71/255)
 static let secondary=Color(red:40/255,green:88/255,blue:103/255)
 static let rule=Color(red:57/255,green:117/255,blue:133/255)
 static let background=LinearGradient(colors:[Color(red:181/255,green:232/255,blue:240/255),Color(red:168/255,green:223/255,blue:235/255),Color(red:145/255,green:204/255,blue:217/255)],startPoint:.topLeading,endPoint:.bottomTrailing)
}

struct RadioLCDView:View {
 let model:RadioLCDPresentation
 var body:some View {
  GeometryReader {geometry in
   let compact=geometry.size.width<680
   VStack(alignment:.leading,spacing:4){
    header(compact:compact)
    identity(compact:compact)
    Rectangle().fill(LCDPalette.rule.opacity(0.8)).frame(height:1)
    destination(compact:compact)
    meter
    VStack(alignment:.leading,spacing:1){
     Text(model.error.isEmpty ? model.connection:model.error)
      .font(.system(size:10,weight:model.error.isEmpty ? .medium:.semibold,design:.monospaced))
      .foregroundStyle(model.error.isEmpty ? LCDPalette.secondary:Color(red:0.5,green:0.15,blue:0.08))
      .lineLimit(1).truncationMode(.middle).help(model.error.isEmpty ? model.connection:model.error)
     Text(model.detail).font(.system(size:9,design:.monospaced)).foregroundStyle(LCDPalette.secondary).lineLimit(1).truncationMode(.middle).help(model.detail)
    }.frame(height:23,alignment:.topLeading)
   }.padding(.horizontal,15).padding(.vertical,8)
    .foregroundStyle(LCDPalette.ink)
    .background(RoundedRectangle(cornerRadius:12).fill(LCDPalette.background))
    .overlay(RoundedRectangle(cornerRadius:12).stroke(LCDPalette.rule.opacity(0.5),lineWidth:1))
    .overlay(RoundedRectangle(cornerRadius:11).stroke(Color.white.opacity(0.22),lineWidth:1).padding(2))
    .padding(8)
    .background(RoundedRectangle(cornerRadius:19).fill(LinearGradient(colors:[Color(white:0.025),Color(white:0.08)],startPoint:.top,endPoint:.bottom)))
    .overlay(RoundedRectangle(cornerRadius:19).stroke(Color(red:0.23,green:0.3,blue:0.32),lineWidth:1))
    .overlay(RoundedRectangle(cornerRadius:15).stroke(.black.opacity(0.8),lineWidth:3).padding(4))
  }.frame(height:232)
   .accessibilityElement(children:.contain).accessibilityLabel("Radiodisplay")
 }
 private func header(compact:Bool)->some View {
  HStack(spacing:compact ? 5:7){
   pill(model.modeTitle,filled:true)
   ForEach(model.badges,id:\.self){pill($0)}
   Spacer(minLength:3)
   HStack(spacing:4){Image(systemName:model.connected ? "wifi":"wifi.slash");Text(model.network)}
    .font(.system(size:compact ? 10:11,weight:.semibold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.8)
    .accessibilityLabel("\(model.network), \(model.connection)")
   Text(model.status).font(.system(size:compact ? 11:12,weight:.heavy,design:.monospaced))
    .foregroundStyle(model.transmitting ? Color(red:0.58,green:0.13,blue:0.08):LCDPalette.ink)
    .padding(.horizontal,8).padding(.vertical,4)
    .background(model.transmitting ? Color.orange.opacity(0.15):Color.clear,in:RoundedRectangle(cornerRadius:4))
    .overlay(RoundedRectangle(cornerRadius:4).stroke(LCDPalette.rule,lineWidth:1))
    .lineLimit(1).minimumScaleFactor(0.75)
  }.frame(height:25)
 }
 private func identity(compact:Bool)->some View {
  HStack(alignment:.center,spacing:14){
   VStack(alignment:.leading,spacing:1){
    Text(model.stationLabel).font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundStyle(LCDPalette.secondary).lineLimit(1)
    Group {
     if let url=model.qrzURL {Link(model.callsign,destination:url).help("Open ontvangen station op QRZ.com")}
     else {Text(model.callsign)}
    }.font(.system(size:compact ? 43:52,weight:.black,design:.monospaced)).tracking(-1.5)
     .foregroundStyle(LCDPalette.ink).lineLimit(1).minimumScaleFactor(0.38)
     .frame(maxWidth:.infinity,alignment:.leading)
   }.frame(maxWidth:.infinity,alignment:.leading)
   if let id=model.identifier,let label=model.identifierLabel {
    Rectangle().fill(LCDPalette.rule).frame(width:1,height:48)
    VStack(alignment:.leading,spacing:3){
     Text(label).font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(LCDPalette.secondary)
     Text(id).font(.system(size:compact ? 29:36,weight:.heavy,design:.monospaced)).tracking(-1).lineLimit(1).minimumScaleFactor(0.5)
    }.frame(maxWidth:.infinity,alignment:.leading)
   }
  }.frame(height:64)
 }
 private func destination(compact:Bool)->some View {
  HStack(alignment:.center,spacing:15){
   VStack(alignment:.leading,spacing:1){
    Text(model.destinationLabel).font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundStyle(LCDPalette.secondary)
    Text(model.destination).font(.system(size:compact ? 22:26,weight:.bold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.45).truncationMode(.middle)
   }.frame(maxWidth:.infinity,alignment:.leading)
   Rectangle().fill(LCDPalette.rule.opacity(0.7)).frame(width:1,height:32)
   VStack(alignment:.leading,spacing:1){
    Text("NETWERK").font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundStyle(LCDPalette.secondary)
    Text(model.network).font(.system(size:compact ? 20:24,weight:.bold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.65)
   }.frame(maxWidth:.infinity,alignment:.leading)
  }.frame(height:39)
 }
 private var meter:some View {
  HStack(alignment:.top,spacing:10){
   Text("RX AUDIO").font(.system(size:9,weight:.semibold,design:.monospaced)).padding(.top,2)
   VStack(spacing:3){
    HStack(spacing:2){
     ForEach(0..<40,id:\.self){segment in Rectangle().fill(LCDPalette.ink.opacity(segment<model.activeSegments ? 0.95:0.16)).frame(maxWidth:.infinity)}
    }.frame(height:12)
    HStack{Text("−60");Spacer();Text("−40");Spacer();Text("−20");Spacer();Text("0 dBFS")}
     .font(.system(size:8,weight:.medium,design:.monospaced)).foregroundStyle(LCDPalette.secondary)
   }
   Text(model.audioText).font(.system(size:9,weight:.semibold,design:.monospaced)).monospacedDigit().frame(width:63,alignment:.trailing).padding(.top,1)
  }.frame(height:27)
   .accessibilityElement(children:.ignore).accessibilityLabel("Ontvangstaudio").accessibilityValue(model.audioText)
   .help("RMS-audioniveau in dBFS, gemeten door de bestaande audioketen; schaal −60 tot 0 dBFS")
 }
 private func pill(_ text:String,filled:Bool=false)->some View {
  Text(text).font(.system(size:11,weight:.bold,design:.monospaced))
   .foregroundStyle(filled ? Color(red:0.73,green:0.92,blue:0.95):LCDPalette.ink)
   .padding(.horizontal,8).padding(.vertical,4)
   .background(filled ? LCDPalette.ink:Color.clear,in:RoundedRectangle(cornerRadius:4))
   .overlay(RoundedRectangle(cornerRadius:4).stroke(LCDPalette.rule,lineWidth:1)).lineLimit(1).minimumScaleFactor(0.75)
 }
}
