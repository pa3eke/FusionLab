import Foundation

// Both backends expose the existing DV3K control/audio boundary, leaving the
// network framing, 20-ms clock, PTT and audio processing unchanged.
final class VocoderTransport {
 private let queue:DispatchQueue,key=DispatchSpecificKey<Bool>()
 private let server:UDPLink
 private var local:MD380Vocoder?,backend=VocoderBackend.ambeServer,bits:UInt8=49
 var onReady:(()->Void)?,onData:((Data)->Void)?,onError:((String)->Void)?
 init(queue:DispatchQueue){
  self.queue=queue;server=UDPLink(queue:queue);queue.setSpecific(key:key,value:true)
  server.onReady={[weak self] in self?.onReady?()}
  server.onData={[weak self] in self?.onData?($0)}
  server.onError={[weak self] in self?.onError?($0)}
 }
 private func perform(_ action:@escaping()->Void){if DispatchQueue.getSpecific(key:key)==true{action()}else{queue.async(execute:DispatchWorkItem(block:action))}}
 func open(host:String,port:UInt16,backend:VocoderBackend){perform{[self] in
  server.close();local=nil;self.backend=backend;bits=49
  if backend == .ambeServer {server.open(host:host,port:port);return}
  do {local=try MD380Vocoder();onReady?()}catch{onError?(error.localizedDescription)}
 }}
 func close(){perform{[self] in server.close();local=nil}}
 func send(_ data:Data){perform{[self] in
  if backend == .ambeServer {server.send(data);return}
  guard let local,let packet=Packets.dv3k(data),let field=packet.body.first else{return}
  do {
   if packet.type==0 {
    switch field {
    case 0x33:try local.reset();onData?(Data([0x61,0,1,0,0x39]))
    case 0x30:
     let name=Data("MD380 lokaal".utf8);onData?(Data([0x61,0,UInt8(name.count+1),0,0x30])+name)
    case 0x0a:
     if data==Packets.rate {bits=49}
     else if data==VoiceProfile.dmrRate {bits=72}
     else {throw Packets.PacketError.message("MD380 ondersteunt deze vocodermode niet.")}
     onData?(Data([0x61,0,2,0,0x0a,0]))
    case 0x15:onData?(Data([0x61,0,2,0,0x15,0]))
    default:throw Packets.PacketError.message("Onbekend MD380-besturingscommando.")
    }
   }else if packet.type==2 {
    guard data.count==326,data[4]==0,data[5]==160 else{throw Packets.PacketError.message("Ongeldig MD380-PCM-pakket.")}
    let bytes=[UInt8](data.dropFirst(6))
    let pcm=stride(from:0,to:320,by:2).map{Int16(bitPattern:UInt16(bytes[$0])<<8|UInt16(bytes[$0+1]))}
    let native=try local.encode(pcm,bits:bits)
    let wire=bits==49 ? try AMBE49BitOrder.fromMD380(native):native
    onData?(Packets.ambe(wire,bits:bits))
   }else if packet.type==1 {
    guard let frame=Packets.encodedVoice(data,bits:bits) else{throw Packets.PacketError.message("Ongeldig MD380-AMBE-pakket.")}
    let native=bits==49 ? try AMBE49BitOrder.toMD380(frame):frame
    let pcm=try local.decode(native,bits:bits)
    var response=Data([0x61,1,0x42,2,0,160])
    for sample in pcm {let value=UInt16(bitPattern:sample);response.append(UInt8(value>>8));response.append(UInt8(value&255))}
    onData?(response)
   }
  }catch{onError?(error.localizedDescription)}
 }}
}
