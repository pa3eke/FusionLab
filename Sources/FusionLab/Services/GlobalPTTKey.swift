import AppKit
import Carbon.HIToolbox

protocol PTTKeyRegistration:AnyObject {
 var registered:Bool {get}
 var failed:Bool {get}
 var onKey:((Bool)->Void)? {get set}
 func setActive(_ active:Bool)
}

// Register only keypad 0 (key code 82), just like MacDV. This avoids a global
// keyboard monitor and does not request Accessibility/Input Monitoring access.
final class GlobalPTTKey:PTTKeyRegistration {
 private var hotKey:EventHotKeyRef?,handler:EventHandlerRef?
 private var localMonitor:Any?
 private var status:OSStatus=noErr
 private static let signature:OSType=0x464c5054 // FLPT
 var onKey:((Bool)->Void)?
 var registered:Bool {hotKey != nil}
 var failed:Bool {status != noErr}
 func setActive(_ active:Bool){
  if !active {
   if let hotKey {UnregisterEventHotKey(hotKey)};hotKey=nil;status=noErr
   if let localMonitor {NSEvent.removeMonitor(localMonitor)};localMonitor=nil
   return
  }
  guard !registered,!failed else{return}
  if handler==nil {
   var events=[EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed)),EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyReleased))]
   status=InstallEventHandler(GetApplicationEventTarget(),{_,event,context in
    guard let event,let context else{return OSStatus(eventNotHandledErr)}
    let key=Unmanaged<GlobalPTTKey>.fromOpaque(context).takeUnretainedValue()
    var identity=EventHotKeyID()
    guard key.registered,GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&identity)==noErr,
     identity.signature==GlobalPTTKey.signature,identity.id==1 else{return OSStatus(eventNotHandledErr)}
    let pressed=GetEventKind(event)==UInt32(kEventHotKeyPressed)
    if Thread.isMainThread {key.onKey?(pressed)}
    else {DispatchQueue.main.async{[weak key] in guard let key,key.registered else{return};key.onKey?(pressed)}}
    return noErr
   },events.count,&events,Unmanaged.passUnretained(self).toOpaque(),&handler)
   guard status==noErr else{return}
  }
  status=RegisterEventHotKey(UInt32(kVK_ANSI_Keypad0),0,EventHotKeyID(signature:Self.signature,id:1),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&hotKey)
  guard registered else{return}
  // Carbon is the sole PTT event source, in foreground and background.
  // A latch only deduplicates consecutive downs: local down/up followed by
  // Carbon down/up can otherwise look like two separate toggle gestures.
  // Consume any foreground Cocoa events without dispatching a second gesture.
  localMonitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp]){[weak self] event in
   guard let self,self.registered,event.keyCode==UInt16(kVK_ANSI_Keypad0) else{return event}
   if event.type == .keyDown,!event.modifierFlags.intersection([.command,.control,.option,.shift]).isEmpty {return event}
   return nil
  }
 }
 deinit {
  if let hotKey {UnregisterEventHotKey(hotKey)}
  if let handler {RemoveEventHandler(handler)}
  if let localMonitor {NSEvent.removeMonitor(localMonitor)}
 }
}
