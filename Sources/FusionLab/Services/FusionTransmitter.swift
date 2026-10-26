import Foundation

// I/O-queue state machine: 20 ms DVSI input, five voice blocks per 100 ms YSF
// frame, and a real terminator after all encoded audio has been drained.
final class FusionTransmitter {
 enum Phase {case idle,recording,draining}
 private(set) var phase:Phase = .idle
 private(set) var inputCount=0
 private(set) var encodedCount=0
 private(set) var networkCount=0
 private(set) var droppedInputCount=0
 private(set) var inputHighWaterMark=0
 static let maximumBufferedFrames=25
 static let maximumTransmitSeconds:TimeInterval=180
 private var beganUptime:TimeInterval=0
 private(set) var timedOut=false
 func remainingSeconds(at uptime:TimeInterval=ProcessInfo.processInfo.systemUptime)->Int {
  phase == .idle ? 0:max(0,Int(ceil(Self.maximumTransmitSeconds-(uptime-beganUptime))))
 }
 var onAMBE:((Data)->Void)?
 var onNetwork:((Data)->Void)?
 var onFinished:(()->Void)?
 var onError:((String)->Void)?
 private var call=""
 private var profile:VoiceProfile = .fusion
 private var stream:UInt32=0
 private var pcm=[Data](),voices=[Data]()
 private var pending=0,sequence=0
 private var began=Date(),nextPCM=Date(),nextNetwork=Date(),lastReply=Date(),stopDeadline=Date.distantFuture
 func start(call:String,profile:VoiceProfile = .fusion,now:Date=Date(),uptime:TimeInterval=ProcessInfo.processInfo.systemUptime){
  guard phase == .idle else{return}
  self.call=call;pcm=[];voices=[];pending=0;sequence=0;inputCount=0;encodedCount=0;networkCount=0;droppedInputCount=0;inputHighWaterMark=0
  self.profile=profile;stream=UInt32.random(in:1...UInt32.max)
  began=now;nextPCM=now;nextNetwork=now.addingTimeInterval(profile.interval);lastReply=now;stopDeadline = .distantFuture
  phase = .recording
  beganUptime=uptime;timedOut=false
  send(fi:0)
 }
 func append(_ samples:[Float]) {
  guard phase == .recording,samples.count==160 else{return}
  // AVAudioEngine can deliver a large tap buffer at once, particularly during
  // startup. A full jitter buffer is not a connection or codec failure.
  if pcm.count>=Self.maximumBufferedFrames {pcm.removeFirst();droppedInputCount += 1}
  pcm.append(Packets.speech(samples));inputHighWaterMark=max(inputHighWaterMark,pcm.count)
 }
 func receive(_ data:Data,now:Date=Date()){
  guard phase != .idle,pending>0 else{return}
  guard let frame=Packets.encodedVoice(data,bits:profile.bits) else{abort("AMBE-encoder gaf geen geldig \(profile.bits)-bits spraakblok terug.");return}
  pending -= 1;lastReply=now;encodedCount += 1;voices.append(frame)
 }
 func stop(now:Date=Date()){
  guard phase == .recording else{return}
  phase = .draining;stopDeadline=now.addingTimeInterval(Double(pcm.count+pending+voices.count+5)*0.02+0.5)
  // Complete the last five-block group with PCM silence encoded by the vocoder.
  let padding=(profile.blocks-(inputCount+pcm.count)%profile.blocks)%profile.blocks
  pcm.append(contentsOf:Array(repeating:Packets.speech([Float](repeating:0,count:160)),count:padding))
 }
 func tick(now:Date=Date(),uptime:TimeInterval=ProcessInfo.processInfo.systemUptime){
  guard phase != .idle else{return}
  // A hard deadline on the independent audio queue: finish immediately, also
  // while draining, without sending queued speech beyond 180 seconds. Clock
  // adjustments cannot extend it because the deadline uses monotonic uptime.
  if uptime-beganUptime>=Self.maximumTransmitSeconds {timedOut=true;end();return}
  if phase == .recording,inputCount==0,now.timeIntervalSince(began)>2{abort("Geen microfoonaudio ontvangen.");return}
  if pending>0,now.timeIntervalSince(lastReply)>1 {abort("Geen tijdig antwoord van de AMBE-encoder.");return}
  if phase == .draining,now>stopDeadline {abort("Afronden van de uitzending duurde te lang.");return}
  var submitted=0
  while !pcm.isEmpty,now.timeIntervalSince(nextPCM)>=(-0.001),pending<8,submitted<2 {
   let frame=pcm.removeFirst();pending += 1;inputCount += 1;submitted += 1
   nextPCM=nextPCM.addingTimeInterval(0.02)
   if pending==1 {lastReply=now}
   onAMBE?(frame)
   guard phase != .idle else{return}
  }
  if now.timeIntervalSince(nextPCM)>0.1 {nextPCM=now.addingTimeInterval(0.02)}
  if voices.count>=profile.blocks,now.timeIntervalSince(nextNetwork)>=(-0.001) {
   let group=Array(voices.prefix(profile.blocks));voices.removeFirst(profile.blocks)
   send(fi:1,voice:group);nextNetwork=nextNetwork.addingTimeInterval(profile.interval)
   if now.timeIntervalSince(nextNetwork)>profile.interval {nextNetwork=now.addingTimeInterval(profile.interval)}
  }
  if phase == .draining,pcm.isEmpty,pending==0,voices.isEmpty {end()}
 }
 func cancel(){guard phase != .idle else{return};end()}
 private func send(fi:UInt8,voice:[Data]=[]){
  let frame:Data
  switch profile {
  case .fusion:frame=Packets.transmit(call:call,sequence:sequence,fi:fi,voice:voice)
  case .dmr(let settings):frame=DMRPackets.transmit(settings:settings,sequence:sequence,stream:stream,kind:fi,voice:voice)
  }
  sequence += 1;networkCount += 1;onNetwork?(frame)
 }
 private func end(){
  send(fi:2);phase = .idle;pcm=[];voices=[];pending=0;onFinished?()
 }
 private func abort(_ message:String){cancel();onError?(message)}
}
