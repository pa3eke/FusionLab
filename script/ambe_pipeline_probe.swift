// Local hardware diagnostic; sends synthetic PCM silence only. No YSF socket.
// Use only after disconnecting all other AMBE clients.
import Foundation
import Darwin

@main struct HardwareProbe {
 @MainActor static func main() async {
  let options=Set(CommandLine.arguments.dropFirst(3))
  guard (3...5).contains(CommandLine.arguments.count),let port=UInt16(CommandLine.arguments[2]),port>0,options.isSubset(of:["--burst-echo","--dmr"]) else {
   print("Usage: ambe_pipeline_probe HOST PORT [--burst-echo] [--dmr] (disconnect other AMBE clients first)");exit(2)
  }
  let burst=options.contains("--burst-echo"),dmr=options.contains("--dmr")
  let frameCount=burst ? 315:dmr ? 60:50
  let settings=DMRVoiceSettings(source:2040001,destination:9990,peer:204000101,slot:2,colorCode:1,privateCall:true)
  let profile:VoiceProfile=dmr ? .dmr(settings):.fusion
  let host=CommandLine.arguments[1]
  let io=DispatchQueue(label:"FusionLab.hardware-probe")
  let socket=UDPLink(queue:io),loop=TransmissionLoop(queue:io),token=UUID()
  loop.configure(profile)
  var packets=[Data](),decoded=0
  var finished:TransmissionLoop.Metrics?,failure:String?
  var reception=TransmissionLoop.ReceptionMetrics()
  let begin=Date()
  loop.onAMBE={socket.send($0)}
  loop.onNetwork={packets.append($0)} // Intentionally no reflector socket.
  loop.onPCM={_ in decoded += 1}
  loop.onError={failure=$0}
  loop.onReception={reception=$0}
  loop.onFinished={result in
   finished=result
   let frames=io.sync{packets}
   for (i,frame) in frames.enumerated(){
    var echo=frame
    if dmr,let rx=DMRPackets.receive(frame){
     let reply=DMRVoiceSettings(source:9990,destination:settings.source,peer:settings.peer,slot:settings.slot,colorCode:settings.colorCode,privateCall:true)
     echo=DMRPackets.transmit(settings:reply,sequence:Int(rx.sequence),stream:rx.stream,kind:rx.kind,voice:rx.frames)
    }
    let received=echo
    io.asyncAfter(deadline:.now()+(burst ? 0:Double(i)*profile.interval),execute:DispatchWorkItem{loop.receiveNetworkAudio(received)})
   }
  }
  socket.onError={message in DispatchQueue.main.async{failure=message}}
  socket.onReady={socket.send(profile.rate)}
  socket.onData={data in
   guard let p=Packets.dv3k(data) else{return}
   if p.type==1 {loop.receiveEncoded(data)}
   else if p.type==2 {loop.receivePCM(data)}
   else if p.type==0,let f=p.body.first {
    if f==0x0a {socket.send(Data([0x61,0,3,0,0x15,0,1]))}
    if f==0x15 {
     loop.setEnabled(true);loop.prepareCapture(token:token,gain:0,forTX:true);loop.start(call:"PA3EKE")
     for batch in 0..<(frameCount/5) {
      io.asyncAfter(deadline:.now()+Double(batch)*0.1,execute:DispatchWorkItem{
       for _ in 0..<5 {loop.appendMicrophone([Float](repeating:0,count:160),token:token)}
      })
     }
     io.asyncAfter(deadline:.now()+Double(frameCount)*0.02+0.05,execute:DispatchWorkItem{loop.stop()})
    }
   }
  }
  socket.open(host:host,port:port)
  let deadline=Date().addingTimeInterval(Double(frameCount)*0.04+6)
  while (finished==nil || io.sync{decoded}<frameCount),failure==nil,Date()<deadline {
   try? await Task.sleep(nanoseconds:20_000_000)
  }
  let count=io.sync{decoded}
  print("Production pipeline: inputs=\(finished?.inputCount ?? -1), encoded=\(finished?.encodedCount ?? -1), dropped=\(finished?.droppedInputCount ?? -1), Network frames kept local=\(finished?.networkCount ?? -1), decoded PCM=\(count), elapsed=\(String(format:"%.3f",Date().timeIntervalSince(begin))) s")
  print("Codec bits=\(profile.bits), receive burst=\(burst), high water=\(reception.highWater), discarded=\(reception.discarded)")
  loop.setEnabled(false);loop.reset();socket.close();io.sync{}
  if let failure {print("FAIL: \(failure)");exit(1)}
  guard finished?.encodedCount==frameCount,finished?.droppedInputCount==0,count==frameCount,reception.discarded==0 else{exit(1)}
 }
}
