// Interactive test of the real HID + production RadioSession/PTT path.
// Both UDP endpoints are loopback fixtures; microphone samples are generated.
import AppKit
import Combine
import Network

private final class ProbeMic:MicrophoneSource {
 var timer:Timer?
 func requestAccess(_ completion:@escaping(Bool)->Void){completion(true)}
 func start(onSamples:@escaping([Float])->Void,onError:@escaping(String)->Void)throws{
  stop();let timer=Timer(timeInterval:0.02,repeats:true){_ in onSamples(Array(repeating:0.1,count:160))}
  RunLoop.main.add(timer,forMode:.common);self.timer=timer
 }
 func stop(){timer?.invalidate();timer=nil}
}
private final class ProbeKey:PTTKeyRegistration {
 var registered=false,failed=false;var onKey:((Bool)->Void)?
 func setActive(_ active:Bool){}
}
private struct ProbePassword:DMRPasswordStorage {
 func read(for id:String)->String? {nil}
 func save(_ password:String,for id:String)->Bool {false}
 func remove(for id:String){}
}
private final class LoopbackServer {
 let listener:NWListener
 var clients=[NWConnection]()
 var reply:((Data)->Data?)?
 private var readyContinuation:CheckedContinuation<Void,Error>?
 var port:UInt16 {listener.port!.rawValue}
 init()throws{
  let params=NWParameters.udp
  params.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
  listener=try NWListener(using:params)
 }
 func start() async throws {
  try await withCheckedThrowingContinuation{(continuation:CheckedContinuation<Void,Error>) in
   readyContinuation=continuation
   listener.stateUpdateHandler={[weak self] state in
    guard let self,let continuation=self.readyContinuation else{return}
    if case .ready=state {self.readyContinuation=nil;continuation.resume()}
    if case .failed(let e)=state {self.readyContinuation=nil;continuation.resume(throwing:e)}
   }
   listener.newConnectionHandler={[weak self] c in self?.clients.append(c);c.start(queue:.main);self?.receive(c)}
   listener.start(queue:.main)
  }
 }
 func receive(_ c:NWConnection){c.receiveMessage{[weak self] d,_,_,error in
  guard let self,error==nil else{return}
  if let d,let response=self.reply?(d) {c.send(content:response,completion:.contentProcessed{_ in})}
  self.receive(c)
 }}
 func stop(){listener.cancel();clients.forEach{$0.cancel()}}
}
private final class Probe:NSObject,NSApplicationDelegate {
 var window:NSWindow!,label:NSTextField!,radio:RadioSession?
 var servers=[LoopbackServer](),subscriptions=Set<AnyCancellable>()
 var seen=Set<Int>()
 func applicationDidFinishLaunching(_ notification:Notification){
  window=NSWindow(contentRect:NSRect(x:0,y:0,width:610,height:230),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
  window.title="FusionLab — XK-24 hardwaretest (alleen lokaal)"
  label=NSTextField(wrappingLabelWithString:"Lokale testverbinding starten…")
  label.frame=NSRect(x:20,y:80,width:570,height:125);label.font=NSFont.monospacedSystemFont(ofSize:14,weight:.medium)
  window.contentView?.addSubview(label)
  let stop=NSButton(title:"Test stoppen",target:self,action:#selector(end));stop.frame=NSRect(x:20,y:22,width:150,height:34);window.contentView?.addSubview(stop)
  window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
  Task{@MainActor in
   do{
    let ambe=try LoopbackServer(),ysf=try LoopbackServer();servers=[ambe,ysf]
    ambe.reply={d in
     guard let p=Packets.dv3k(d) else{return nil}
     if p.type==2 {return Packets.ambe(Data(repeating:0,count:7))}
     guard p.type==0,let field=p.body.first else{return nil}
     if field==0x33 {return Data([0x61,0,1,0,0x39])}
     if field==0x30 {return Data([0x61,0,5,0,0x30,84,69,83,84])}
     return Data([0x61,0,2,0,field,0])
    }
    ysf.reply={d in d.prefix(4)==Data("YSFP".utf8) ? d:nil}
    try await ambe.start();try await ysf.start()
    let s=RadioSession(microphone:ProbeMic(),pttKey:ProbeKey(),passwordStore:ProbePassword())
    radio=s;s.selectMode(.fusion);s.call="PA0TEST";s.volume=0;s.pttKeyMode = .off
    s.host="127.0.0.1";s.port=String(ysf.port);s.ambeHost="127.0.0.1";s.ambePort=String(ambe.port);s.exclusive=true
    var config=XKeysSettings();config.enabled=true
    config.bindings=Array(repeating:XKeysBinding(),count:24)
    config.bindings[0]=XKeysBinding(action:.ptt,mode:.hold)
    config.bindings[1]=XKeysBinding(action:.ptt,mode:.toggle);config.bindings[2]=XKeysBinding(action:.stopTX)
    s.xkeys.settings=config
    s.xkeys.$eventCount.sink{[weak self] _ in DispatchQueue.main.async{self?.render(event:true)}}.store(in:&subscriptions)
    s.xkeys.$status.sink{message in print("HID",message)}.store(in:&subscriptions)
    s.$transmitting.sink{[weak self] _ in DispatchQueue.main.async{self?.render(event:false)}}.store(in:&subscriptions)
    s.$readyToTransmit.sink{[weak self] _ in DispatchQueue.main.async{self?.render(event:false)}}.store(in:&subscriptions)
    s.startXKeys();s.connect();render(event:false)
    print("TEST ONLY: synthetic microphone, AMBE and reflector bound to127.0.0.1. No public-network transmission.")
   }catch{label.stringValue="Test starten mislukt: \(error)";print("FAIL",error)}
  }
  DispatchQueue.main.asyncAfter(deadline:.now()+900){NSApp.terminate(nil)}
 }
 func render(event:Bool){
  guard let s=radio else{return}
  if let key=s.xkeys.lastKey {seen.insert(key)}
  label.stringValue="ECHTE XK-24 · alleen lokale testpakketten\n1 = PTT vasthouden · 2 = PTT toggle · 3 = direct stoppen\n\(s.transmitting ? "TEST-TX actief":"TEST-RX / stand-by") · \(s.readyToTransmit ? "zendklaar":"initialiseren")\n\(s.xkeys.status)\nLaatste toets: \(s.xkeys.lastKey.map{String($0+1)} ?? "—") · \(seen.count)/24 toetsen gezien"
  if event {print("KEY",s.xkeys.lastKey.map{String($0+1)} ?? "—","pressed",s.xkeys.pressed.sorted().map{$0+1},"TX",s.transmitting,"focus",NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "—","minimized",window.isMiniaturized,"onActiveSpace",window.isOnActiveSpace,"seen",seen.sorted().map{$0+1})}
  else {print("STATE TX",s.transmitting,"ready",s.readyToTransmit,"focus",NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "—")}
 }
 func applicationDidResignActive(_ notification:Notification){radio?.handleFocusLoss()}
 @objc func end(){NSApp.terminate(nil)}
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
 func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
  radio?.emergencyStopTransmit(reason:"hardwaretest afsluiten");radio?.stopXKeys();radio?.disconnect();servers.forEach{$0.stop()}
  DispatchQueue.main.asyncAfter(deadline:.now()+0.5){sender.reply(toApplicationShouldTerminate:true)}
  return .terminateLater
 }
}
@main struct HardwareProbe {
 @MainActor static func main(){setbuf(stdout,nil);let app=NSApplication.shared;app.setActivationPolicy(.regular);let delegate=Probe();app.delegate=delegate;app.run();withExtendedLifetime(delegate){}}
}
