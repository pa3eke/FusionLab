import AVFoundation

final class AudioOutput {
 private let queue:DispatchQueue
 private let key=DispatchSpecificKey<Bool>()
 private let engine=AVAudioEngine(),player=AVAudioPlayerNode()
 private let format=AVAudioFormat(standardFormatWithSampleRate:8000,channels:1)!
 private var pending=0,generation=0
 private var agc=ReceiveAGC(),agcEnabled=true
 private var equalizer=ReceiveEQ()
 func setEQ(_ settings:ReceiveEQSettings){perform{[self] in equalizer.configure(settings)}}
 private var lastAudioUptime:TimeInterval?
 func setAGCEnabled(_ enabled:Bool){perform{[self] in agcEnabled=enabled;agc.reset();lastAudioUptime=nil}}
 var volume:Float=0.6 {didSet{let value=volume;perform{[self] in player.volume=value}}}
 init(queue:DispatchQueue = .main){self.queue=queue;queue.setSpecific(key:key,value:true);engine.attach(player);engine.connect(player,to:engine.mainMixerNode,format:format);player.volume=volume}
 private func perform(_ action:@escaping()->Void){if DispatchQueue.getSpecific(key:key)==true{action()}else{queue.async(execute:DispatchWorkItem(block:action))}}
 func start()throws{
  let action={if !self.engine.isRunning{try self.engine.start()}}
  if DispatchQueue.getSpecific(key:key)==true {try action()}else{try queue.sync(execute:action)}
 }
 func append(_ samples:[Float]){perform{[self] in
  guard engine.isRunning,pending<25,let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count)) else{return}
  let now=ProcessInfo.processInfo.systemUptime
  if now-(lastAudioUptime ?? now)>0.5 {agc.reset();equalizer.reset()}
  lastAudioUptime=now
  let usesEQ=equalizer.isActive
  let shaped=equalizer.process(samples)
  var output=agcEnabled ? agc.process(shaped):shaped
  if !agcEnabled,usesEQ {
   let peak=output.reduce(Float(0)){max($0,abs($1))}
   if peak>0.95 {let gain:Float=0.95/peak;output=output.map{$0*gain}}
  }
  buffer.frameLength=buffer.frameCapacity
  output.withUnsafeBufferPointer{buffer.floatChannelData![0].update(from:$0.baseAddress!,count:output.count)}
  pending += 1;let token=generation
  if pending==1 {
   queue.asyncAfter(deadline:.now()+0.08){[weak self] in
    guard let self,self.generation==token,self.pending>0,!self.player.isPlaying else{return}
    self.player.play() // also drain a short tail of fewer than four blocks
   }
  }
  player.scheduleBuffer(buffer,completionCallbackType:.dataPlayedBack){[weak self] _ in
   guard let self else{return};self.queue.async{[weak self] in
    guard let self,self.generation==token else{return}
    self.pending=max(0,self.pending-1)
    // isPlaying remains true after starvation. Stop so the next burst gets
    // the same 80 ms prebuffer as the initial one instead of repeated gaps.
    if self.pending==0 {self.player.stop()}
   }
  }
  if !player.isPlaying && pending>=4{player.play()}
 }}
 func resetPlayback(){perform{[self] in generation += 1;player.stop();pending=0;agc.reset();equalizer.reset();lastAudioUptime=nil}}
 func stop(){perform{[self] in generation += 1;player.stop();pending=0;agc.reset();equalizer.reset();lastAudioUptime=nil;engine.stop()}}
}
