import Foundation

// Audio/network timing belongs to this serial I/O queue, never the SwiftUI
// run loop. The screen gets snapshots at 10 Hz instead of every 20 ms.
final class TransmissionLoop {
 struct Metrics {
  let inputCount:Int,encodedCount:Int,networkCount:Int,droppedInputCount:Int,inputHighWaterMark:Int
  let draining:Bool
  let remainingSeconds:Int,timedOut:Bool
 }
 struct Meter {let rms:Float,peak:Float,clipped:Bool,count:Int}
 struct ReceptionMetrics:Equatable {
  var received=0,submitted=0,decoded=0,discarded=0,buffered=0,highWater=0
  var busy:Bool {buffered>0 || submitted>decoded}
 }
 private let queue:DispatchQueue
 private let key=DispatchSpecificKey<Bool>()
 private let tx=FusionTransmitter()
 private var timer:DispatchSourceTimer?
 private var enabled=false
 private var profile:VoiceProfile = .fusion
 private var dmrStream:UInt32?
 private var dmrSequence:UInt8?
 private var token:UUID?
 private var captureForTX=false
 private var gainDB:Double=0
 private var peak:Float=0,rms:Float=0
 private var peakUntil=Date.distantPast,clipUntil=Date.distantPast,lastMeter=Date.distantPast,lastUI=Date.distantPast
 private var captureCount=0,pcmCount=0,lastPublishedPCM=0
 private var pcmDate=Date.distantPast
 private var pcmLevel:Float=0
 private var rx=[Data](),rxSource=""
 // Echo services may return a complete recording much faster than real time.
 // Preserve up to the maximum 180-second PTT plus one second of headroom;
 // only the decoder clock determines playout speed, never network arrival.
 static let maximumReceivedFrames=9050
 private var reception=ReceptionMetrics(),publishedReception=ReceptionMetrics()
 var onReception:((ReceptionMetrics)->Void)?
 private var rxSequence:UInt8?
 private var decodeWaiting:Date?
 private var decodeWarning=false
 var onRXTimeout:(()->Void)?
 var onAMBE:((Data)->Void)?
 var onNetwork:((Data)->Void)?
 var onUpdate:((Metrics)->Void)?
 var onFinished:((Metrics)->Void)?
 var onError:((String)->Void)?
 var onMeter:((UUID,Meter)->Void)?
 var onPCM:(([Float])->Void)? // runs on the audio I/O queue
 var onPCMUpdate:((Int,Date,Float)->Void)?
 init(queue:DispatchQueue){
  self.queue=queue;queue.setSpecific(key:key,value:true)
  tx.onAMBE={[weak self] in self?.onAMBE?($0)}
  tx.onNetwork={[weak self] in self?.onNetwork?($0)}
  tx.onFinished={[weak self] in
   guard let self else{return};self.token=nil
   let snapshot=self.metrics()
   DispatchQueue.main.async{[weak self] in self?.onFinished?(snapshot)}
  }
  tx.onError={[weak self] message in DispatchQueue.main.async{[weak self] in self?.onError?(message)}}
 }
 private func perform(_ action:@escaping()->Void){if DispatchQueue.getSpecific(key:key)==true{action()}else{queue.async(execute:DispatchWorkItem(block:action))}}
 func setGain(_ db:Double){perform{[self] in gainDB=db}}
 func prepareCapture(token:UUID,gain:Double,forTX:Bool){perform{[self] in
  self.token=token;gainDB=gain;captureForTX=forTX;captureCount=0;peak=0;rms=0
  peakUntil = .distantPast;clipUntil = .distantPast;lastMeter = .distantPast
 }}
 func endCapture(){perform{[self] in token=nil}}
 func appendMicrophone(_ samples:[Float],token:UUID){perform{[self] in
  guard self.token==token else{return}
  let result=MicrophoneGain.process(samples,decibels:gainDB),now=Date()
  rms=result.rms;captureCount += 1
  if result.peak>=peak || now>peakUntil {peak=result.peak;peakUntil=now.addingTimeInterval(1)}
  if result.clipped {clipUntil=now.addingTimeInterval(1)}
  if captureForTX {tx.append(result.samples)}
  if now.timeIntervalSince(lastMeter)>=0.1 {
   lastMeter=now;let meter=Meter(rms:rms,peak:peak,clipped:now<clipUntil,count:captureCount)
   DispatchQueue.main.async{[weak self] in self?.onMeter?(token,meter)}
  }
 }}
 func reset(){perform{[self] in
  tx.cancel();token=nil;enabled=false;pcmCount=0;lastPublishedPCM=0
  pcmDate = .distantPast;pcmLevel=0;rx=[];rxSource="";rxSequence=nil;decodeWaiting=nil;decodeWarning=false;timer?.cancel();timer=nil
  reception=ReceptionMetrics();publishedReception=ReceptionMetrics()
  dmrStream=nil;dmrSequence=nil
 }}
 func configure(_ profile:VoiceProfile){perform{[self] in self.profile=profile;dmrStream=nil;dmrSequence=nil}}
 func setEnabled(_ value:Bool){perform{[self] in
  enabled=value
  if !value {reception.discarded += rx.count;rx=[];reception.buffered=0;decodeWaiting=nil;decodeWarning=false}
  if value {ensureTimer()}else if tx.phase == .idle {timer?.cancel();timer=nil}
 }}
 func start(call:String,limit:TransmitLimit = .threeMinutes){perform{[self] in guard enabled else{return};rx=[];decodeWaiting=nil;decodeWarning=false;tx.start(call:call,profile:profile,limit:limit);lastUI = .distantPast;ensureTimer()}}
 func stop(){perform{[self] in token=nil;tx.stop()}}
 func cancel(){perform{[self] in token=nil;tx.cancel()}}
 func receiveEncoded(_ packet:Data){perform{[self] in guard enabled else{return};tx.receive(packet)}}
 func receivePCM(_ packet:Data){perform{[self] in
  guard enabled,tx.phase == .idle,let samples=Packets.pcm(packet) else{return}
  decodeWaiting=nil;decodeWarning=false
  pcmCount += 1;pcmDate=Date();pcmLevel=sqrt(samples.reduce(0){$0+$1*$1}/Float(samples.count))
  reception.decoded += 1
  onPCM?(samples)
 }}
 func receiveNetworkAudio(_ packet:Data){perform{[self] in
  if case .dmr(let settings)=profile {receiveDMRAudio(packet,settings:settings);return}
  if case .nxdn(let settings)=profile {
   guard enabled,tx.phase == .idle,let frame=NXDNPackets.receive(packet),frame.destination==settings.destination else{return}
   reception.received += frame.frames.count
   let available=Self.maximumReceivedFrames-rx.count
   rx.append(contentsOf:frame.frames.prefix(available))
   reception.discarded += max(0,frame.frames.count-available)
   reception.buffered=rx.count;reception.highWater=max(reception.highWater,rx.count)
   return
  }
  guard enabled,tx.phase == .idle,let frame=try? Packets.receive(packet) else{return}
  if frame.fi==0 || frame.source != rxSource {rxSequence=nil;rxSource=frame.source}
  if let previous=rxSequence {
   let delta=(Int(frame.sequence)-Int(previous)+128)%128
   if delta==0 || delta>64{return}
  }
  rxSequence=frame.sequence
  reception.received += frame.frames.count
  let available=Self.maximumReceivedFrames-rx.count
  rx.append(contentsOf:frame.frames.prefix(available))
  reception.discarded += max(0,frame.frames.count-available)
  reception.buffered=rx.count;reception.highWater=max(reception.highWater,rx.count)
  if frame.end || frame.fi==2 {rxSequence=nil;rxSource=""}
 }}
 private func receiveDMRAudio(_ packet:Data,settings:DMRVoiceSettings){
  guard enabled,tx.phase == .idle,let frame=DMRPackets.receive(packet),frame.slot==settings.slot else{return}
  if frame.privateCall,frame.destination != settings.source,frame.destination != settings.peer{return}
  if frame.stream != dmrStream || frame.kind==0 {dmrStream=frame.stream;dmrSequence=nil}
  if let previous=dmrSequence {
   let delta=(Int(frame.sequence)-Int(previous)+256)%256
   if delta==0 || delta>128{return}
  }
  dmrSequence=frame.sequence
  reception.received += frame.frames.count
  let available=Self.maximumReceivedFrames-rx.count
  rx.append(contentsOf:frame.frames.prefix(available))
  reception.discarded += max(0,frame.frames.count-available)
  reception.buffered=rx.count;reception.highWater=max(reception.highWater,rx.count)
  if frame.kind==2 {dmrStream=nil;dmrSequence=nil}
 }
 private func metrics()->Metrics {
  Metrics(inputCount:tx.inputCount,encodedCount:tx.encodedCount,networkCount:tx.networkCount,droppedInputCount:tx.droppedInputCount,inputHighWaterMark:tx.inputHighWaterMark,draining:tx.phase == .draining,remainingSeconds:tx.remainingSeconds(),timedOut:tx.timedOut)
 }
 private func ensureTimer(){
  guard timer==nil else{return}
  let timer=DispatchSource.makeTimerSource(queue:queue)
  timer.schedule(deadline:.now(),repeating:.milliseconds(20),leeway:.milliseconds(1))
  timer.setEventHandler{[weak self] in self?.tick()};self.timer=timer;timer.resume()
 }
 private func tick(){
  let now=Date();tx.tick(now:now)
  if enabled,tx.phase == .idle,!rx.isEmpty {
   if decodeWaiting==nil {decodeWaiting=now}
   reception.submitted += 1;reception.buffered=rx.count-1
   onAMBE?(Packets.ambe(rx.removeFirst(),bits:profile.bits))
  }
  if let waiting=decodeWaiting,now.timeIntervalSince(waiting)>2,!decodeWarning {
   decodeWarning=true;DispatchQueue.main.async{[weak self] in self?.onRXTimeout?()}
  }
  guard now.timeIntervalSince(lastUI)>=0.1 else{return};lastUI=now
  if reception != publishedReception {
   publishedReception=reception;let snapshot=reception
   DispatchQueue.main.async{[weak self] in self?.onReception?(snapshot)}
  }
  if tx.phase != .idle {let snapshot=metrics();DispatchQueue.main.async{[weak self] in self?.onUpdate?(snapshot)}}
  if pcmCount != lastPublishedPCM {
   lastPublishedPCM=pcmCount;let count=pcmCount,date=pcmDate,level=pcmLevel
   DispatchQueue.main.async{[weak self] in self?.onPCMUpdate?(count,date,level)}
  }
 }
 deinit{timer?.cancel()}
}
