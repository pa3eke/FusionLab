import Foundation

// Serialize registration and keepalive on the network/audio queue. The UI
// receives notifications only; drawing or scrolling cannot delay a ping/pong.
final class BrandMeisterConnection {
 private let queue:DispatchQueue,key=DispatchSpecificKey<Bool>()
 private let handshake=BrandMeisterHandshake()
 private let clock:()->Date,interval:TimeInterval
 private var timer:DispatchSourceTimer?,generation=0
 var onSend:((Data)->Void)?,onReady:(()->Void)?,onError:((String)->Void)?,onProgress:((String)->Void)?
 init(queue:DispatchQueue,interval:TimeInterval=0.5,clock:@escaping()->Date={Date(timeIntervalSince1970:ProcessInfo.processInfo.systemUptime)}){
  self.queue=queue;self.interval=interval;self.clock=clock;queue.setSpecific(key:key,value:true)
  handshake.onSend={[weak self] in self?.onSend?($0)}
  handshake.onReady={[weak self] in guard let self else{return};let handler=self.onReady;self.deliver{handler?()}}
  handshake.onProgress={[weak self] message in guard let self else{return};let handler=self.onProgress;self.deliver{handler?(message)}}
  handshake.onError={[weak self] message in
   guard let self else{return};self.cancelTimer();let handler=self.onError;self.deliver{handler?(message)}
  }
 }
 private func perform(_ action:@escaping()->Void){if DispatchQueue.getSpecific(key:key)==true{action()}else{queue.async(execute:DispatchWorkItem(block:action))}}
 private func deliver(_ action:@escaping()->Void){
  let token=generation
  DispatchQueue.main.async{[weak self] in
   guard let self,self.queue.sync(execute:{self.generation==token}) else{return}
   action()
  }
 }
 func start(peer:UInt32,call:String,password:String,colorCode:UInt8=1){perform{[self] in
  generation += 1;cancelTimer();handshake.reset()
  handshake.start(peer:peer,call:call,password:password,colorCode:colorCode,now:clock())
  guard handshake.phase != .idle,handshake.phase != .failed else{return}
  let timer=DispatchSource.makeTimerSource(queue:queue)
  timer.schedule(deadline:.now()+interval,repeating:interval,leeway:.milliseconds(10))
  timer.setEventHandler{[weak self] in guard let self else{return};self.handshake.tick(now:self.clock())}
  self.timer=timer;timer.resume()
 }}
 func receive(_ data:Data){perform{[self] in handshake.receive(data,now:clock())}}
 func disconnect(){perform{[self] in generation += 1;cancelTimer();handshake.disconnect()}}
 func reset(){perform{[self] in generation += 1;cancelTimer();handshake.reset()}}
 private func cancelTimer(){timer?.cancel();timer=nil}
 deinit{timer?.cancel()}
}
