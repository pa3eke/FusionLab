import Foundation

// Main-thread control plane only; audio remains on the dedicated I/O queue.
final class BrandMeisterHandshake {
 enum Phase {case idle,challenge,authentication,configuration,ready,failed}
 private(set) var phase:Phase = .idle
 private var peer:UInt32=0,call="",password=""
 private var colorCode:UInt8=1
 private var deadline=Date.distantFuture,lastPacket=Date.distantPast,lastPing=Date.distantPast
 var onSend:((Data)->Void)?,onReady:(()->Void)?,onError:((String)->Void)?
 var onProgress:((String)->Void)?
 func start(peer:UInt32,call:String,password:String,colorCode:UInt8=1,now:Date=Date()){
  self.peer=peer;self.call=call;self.password=password
  self.colorCode=colorCode
  phase = .challenge;deadline=now.addingTimeInterval(8);lastPacket=now;lastPing=now
  onProgress?("BrandMeister: DMR-ID aanmelden…")
  onSend?(DMRPackets.control("RPTL",peer:peer))
 }
 func receive(_ data:Data,now:Date=Date()){
  guard phase != .idle,phase != .failed else{return}
  if data.prefix(6)==Data("MSTNAK".utf8){
   let message:String
   switch phase {
   case .challenge:message="BrandMeister weigert het DMR-ID/SSID vóór de wachtwoordcontrole. Controleer ID, SSID en toegang tot deze master."
   case .authentication:message="BrandMeister weigert het hotspotwachtwoord. Gebruik Hotspot Security uit SelfCare voor dit DMR-ID, niet het dashboardwachtwoord."
   case .configuration:message="BrandMeister weigert de apparaatconfiguratie. De wachtwoordcontrole was al geslaagd."
   default:message="BrandMeister heeft de verbinding geweigerd."
   }
   fail(message);return
  }
  if data.prefix(5)==Data("MSTCL".utf8){fail("BrandMeister heeft de verbinding gesloten.");return}
  if data.count==11,data.prefix(7)==Data("MSTPONG".utf8),data.suffix(4)==DMRPackets.id(peer) {lastPacket=now;return}
  guard data.prefix(6)==Data("RPTACK".utf8) else{return}
  switch phase {
  case .challenge:
   guard data.count==10 else{return}
   phase = .authentication;deadline=now.addingTimeInterval(8)
   onProgress?("BrandMeister: DMR-ID geaccepteerd; hotspotwachtwoord controleren…")
   let response=DMRPackets.authentication(peer:peer,salt:Data(data.suffix(4)),password:password)
   password="";onSend?(response)
  case .authentication:
   guard data.count==10,data.suffix(4)==DMRPackets.id(peer) else{return}
   phase = .configuration;deadline=now.addingTimeInterval(8)
   onProgress?("BrandMeister: hotspotwachtwoord geaccepteerd; configuratie aanmelden…")
   onSend?(DMRPackets.configuration(peer:peer,call:call,colorCode:colorCode))
  case .configuration:
   guard data.count==10,data.suffix(4)==DMRPackets.id(peer) else{return}
   phase = .ready;lastPacket=now;lastPing=now;onReady?()
  default:break
  }
 }
 func tick(now:Date=Date()){
  guard phase != .idle,phase != .failed else{return}
  if phase != .ready {if now>deadline{fail("BrandMeister geeft geen antwoord op de aanmelding.")};return}
  if now.timeIntervalSince(lastPacket)>20{fail("BrandMeister: geen keepalive-antwoord binnen 20 seconden.");return}
  if now.timeIntervalSince(lastPing)>=5{lastPing=now;onSend?(DMRPackets.control("RPTPING",peer:peer))}
 }
 func disconnect(){
  if phase != .idle,phase != .failed {onSend?(DMRPackets.control("RPTCL",peer:peer))}
  reset()
 }
 func reset(){phase = .idle;password=""}
 private func fail(_ message:String){phase = .failed;password="";onError?(message)}
}
