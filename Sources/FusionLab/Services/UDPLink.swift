import Foundation
import Network

final class UDPLink {
 private let queue:DispatchQueue
 private let key=DispatchSpecificKey<Bool>()
 private var connection:NWConnection?
 var onReady:(()->Void)?
 var onData:((Data)->Void)?
 var onError:((String)->Void)?
 init(queue:DispatchQueue = .main){self.queue=queue;queue.setSpecific(key:key,value:true)}
 private func perform(_ action:@escaping()->Void){if DispatchQueue.getSpecific(key:key)==true{action()}else{queue.async(execute:DispatchWorkItem(block:action))}}
 func open(host:String,port:UInt16){perform{[self] in
  closeNow()
  guard let endpoint=NWEndpoint.Port(rawValue:port) else{return}
  let c=NWConnection(host:NWEndpoint.Host(host),port:endpoint,using:.udp);connection=c
  c.stateUpdateHandler={[weak self,weak c] state in
   guard let self,let c,self.connection === c else{return}
   switch state {
   case .ready:self.onReady?();self.read(c)
   case .failed(let e):self.onError?(e.localizedDescription)
   case .waiting(let e):self.onError?(e.localizedDescription)
   default:break
   }
  }
  c.start(queue:queue)
 }}
 private func read(_ c:NWConnection){
  c.receiveMessage{[weak self,weak c] data,_,_,error in
   guard let self,let c,self.connection === c else{return}
   if let error{self.onError?(error.localizedDescription);return}
   if let data{self.onData?(data)}
   self.read(c)
  }
 }
 func send(_ d:Data,completion:(()->Void)?=nil){perform{[self] in
  guard let c=connection else{return}
  c.send(content:d,completion:.contentProcessed{[weak self,weak c] e in
   guard let self,let c,self.connection === c else{return}
   if let e{self.onError?(e.localizedDescription)}else{completion?()}
  })
 }}
 private func closeNow(){connection?.stateUpdateHandler=nil;connection?.cancel();connection=nil}
 func close(){perform{[self] in closeNow()}}
 deinit{connection?.cancel()}
}
