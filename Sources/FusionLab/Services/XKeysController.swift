import Foundation
import Combine

final class XKeysController:ObservableObject {
 @Published var settings:XKeysSettings {
  didSet {
   guard settings != oldValue else{return}
   guard settings.bindings.count==24 else{settings=oldValue;return}
   settings.save(defaults)
   releaseAll();handlers=[:];deviceKeys=[:];pressed=[]
   if started {if settings.enabled {transport.start();transport.requestState()}else{transport.stop();devices=[:];status="Uit"}}
   updateLEDs()
  }
 }
 @Published private(set) var devices:[String:XKeysDeviceInfo]=[:]
 @Published private(set) var status="Uit"
 @Published private(set) var pressed=Set<Int>()
 @Published private(set) var lastKey:Int?
 @Published private(set) var eventCount=0
 @Published var testMode=false {didSet{if testMode != oldValue {resetInput();updateLEDs()}}}
 var connected:Bool {!devices.isEmpty}
 var ready:Bool {devices.values.contains{$0.compatible}}
 var onAction:((String,Int,XKeysBinding,Bool)->Void)?
 var onRelease:((String)->Void)?
 private let defaults:UserDefaults
 private let transport:XKeysTransport
 private var handlers:[String:XKeysInputHandler]=[:]
 private var deviceKeys:[String:Set<Int>]=[:]
 private var started=false,suspended=false,transmitting=false
 init(transport:XKeysTransport=XKeysDeviceManager(),defaults:UserDefaults = .standard){
  self.transport=transport;self.defaults=defaults;settings=XKeysSettings.load(defaults)
  status=settings.enabled ? "Niet verbonden":"Uit"
  transport.onDevice={[weak self] info,message in
   guard let self,self.started,self.settings.enabled else{return}
   self.devices[info.source]=info;self.status=message;self.updateLEDs()
  }
  transport.onRemoval={[weak self] source in
   guard let self else{return};self.onRelease?(source+":");self.handlers.removeValue(forKey:source);self.deviceKeys.removeValue(forKey:source);self.refreshPressed()
   self.devices.removeValue(forKey:source);self.status=self.settings.enabled ? (self.connected ? "XK-24 aangesloten":"Niet verbonden"):"Uit"
  }
  transport.onReport={[weak self] source,data,id in self?.receive(source:source,data:data,id:id)}
  transport.onError={[weak self] source,message in
   guard let self else{return}
   if let source {self.onRelease?(source+":");self.handlers[source]=XKeysInputHandler();self.deviceKeys[source]=[];self.refreshPressed()}else{self.releaseAll()}
   if self.status != message {self.status=message}
  }
 }
 func start(){guard !started else{return};started=true;if settings.enabled {transport.start()}}
 func stop(){releaseAll();started=false;transport.stop();devices=[:];handlers=[:];deviceKeys=[:];pressed=[];status=settings.enabled ? "Niet verbonden":"Uit"}
 func reconnect(){guard started,settings.enabled else{return};resetInput();transport.stop();transport.start()}
 func resetInput(){releaseAll();handlers=[:];deviceKeys=[:];refreshPressed();if settings.enabled {transport.requestState()}}
 func setSuspended(_ value:Bool){guard value != suspended else{return};suspended=value;resetInput()}
 func setTransmitting(_ value:Bool){guard value != transmitting else{return};transmitting=value;updateLEDs()}
 func restoreDefaults(){var next=settings;next.bindings=XKeysSettings.defaults;settings=next}
 private func releaseAll(){onRelease?("xkeys:")}
 private func receive(source:String,data:Data,id:UInt32){
  guard started,settings.enabled,!suspended,devices[source]?.compatible==true else{return}
  guard let keys=XKeysReport.keys(data,reportID:id) else {
   onRelease?(source+":");handlers[source]=XKeysInputHandler();deviceKeys[source]=[];refreshPressed();status="Ongeldig HID-rapport · X-keys PTT vrijgegeven";return
  }
  var handler=handlers[source] ?? XKeysInputHandler()
  let events=handler.events(keys);handlers[source]=handler
  deviceKeys[source]=keys;refreshPressed()
  // Emergency stop wins over a simultaneous PTT press, and a held emergency
  // key cannot allow a new HID PTT request until released and pressed anew.
  let emergencyHeld=pressed.contains{settings.bindings[$0].action == .stopTX}
  let ordered=events.filter{$0.down && settings.bindings[$0.key].action == .stopTX}+events.filter{!($0.down && settings.bindings[$0.key].action == .stopTX)}
  for event in ordered {
   eventCount += 1;if event.down {lastKey=event.key}
   let binding=settings.bindings[event.key]
   if !testMode,!(event.down && binding.action == .ptt && emergencyHeld) {onAction?(source+":key:\(event.key)",event.key,binding,event.down)}
  }
 }
 private func refreshPressed(){let value=deviceKeys.values.reduce(into:Set<Int>()){$0.formUnion($1)};if value != pressed {pressed=value;updateLEDs()}}
 private func updateLEDs(){transport.setLEDs(XKeysLEDController.frame(settings:settings,transmitting:transmitting,pressed:pressed))}
 deinit{transport.onDevice=nil;transport.onRemoval=nil;transport.onReport=nil;transport.onError=nil;transport.stop()}
}
