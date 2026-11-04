import Foundation
import IOKit.hid

protocol XKeysTransport:AnyObject {
 var onDevice:((XKeysDeviceInfo,String)->Void)? {get set}
 var onRemoval:((String)->Void)? {get set}
 var onReport:((String,Data,UInt32)->Void)? {get set}
 var onError:((String?,String)->Void)? {get set}
 func start()
 func stop()
 func requestState()
 func setLEDs(_ frame:[XKeysLEDState])
}

// Same interface selection, report lengths, baseline and asynchronous output
// pattern as MacDV. Lifecycle/callbacks use the main common-mode run loop;
// blocking USB writes run on a separate queue, never on the audio queue.
final class XKeysDeviceManager:XKeysTransport {
 var onDevice:((XKeysDeviceInfo,String)->Void)?
 var onRemoval:((String)->Void)?
 var onReport:((String,Data,UInt32)->Void)?
 var onError:((String?,String)->Void)?
 private final class Device {
  let hid:IOHIDDevice,source:String
  let buffer=UnsafeMutablePointer<UInt8>.allocate(capacity:64)
  var info:XKeysDeviceInfo
  var leds:[XKeysLEDState]?
  init(_ hid:IOHIDDevice,source:String,pid:Int){self.hid=hid;self.source=source;self.info=XKeysDeviceInfo(source:source,productID:pid,compatible:false)}
  deinit{buffer.deallocate()}
 }
 private var manager:IOHIDManager?
 private var devices:[String:Device]=[:]
 private var desired=Array(repeating:XKeysLEDState(),count:24)
 private let output=DispatchQueue(label:"nl.pa3eke.FusionLab.xkeys.output",qos:.userInitiated)
 private static func number(_ d:IOHIDDevice,_ key:String)->Int {(IOHIDDeviceGetProperty(d,key as CFString) as? NSNumber)?.intValue ?? 0}
 private static func identity(_ d:IOHIDDevice)->String {
  var identity:UInt64=0;IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(d),&identity)
  return "xkeys:\(identity)"
 }
 func start(){
  precondition(Thread.isMainThread);guard manager==nil else{return}
  let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOOptionBits(kIOHIDOptionsTypeNone));self.manager=manager
  IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:XKeysReport.vendor,kIOHIDPrimaryUsagePageKey:XKeysReport.usagePage,kIOHIDPrimaryUsageKey:XKeysReport.usage] as CFDictionary)
  let context=Unmanaged.passUnretained(self).toOpaque()
  IOHIDManagerRegisterDeviceMatchingCallback(manager,{context,result,_,device in
   guard let context,result==kIOReturnSuccess else{return}
   Unmanaged<XKeysDeviceManager>.fromOpaque(context).takeUnretainedValue().added(device)
  },context)
  IOHIDManagerRegisterDeviceRemovalCallback(manager,{context,_,_,device in
   guard let context else{return}
   Unmanaged<XKeysDeviceManager>.fromOpaque(context).takeUnretainedValue().removed(device)
  },context)
  IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
  let result=IOHIDManagerOpen(manager,IOOptionBits(kIOHIDOptionsTypeNone))
  if result != kIOReturnSuccess {onError?(nil,"HID niet beschikbaar (\(String(format:"0x%08X",result))). Controleer apparaat en macOS-toegang.")}
 }
 func stop(){
  precondition(Thread.isMainThread);guard let manager else{return};self.manager=nil
  for device in devices.values {
   IOHIDDeviceRegisterInputReportCallback(device.hid,device.buffer,64,nil,nil)
   if device.info.compatible {send(XKeysReport.output(182,0,0),device);send(XKeysReport.output(182,1,0),device)}
   onRemoval?(device.source)
  }
  IOHIDManagerRegisterDeviceMatchingCallback(manager,nil,nil);IOHIDManagerRegisterDeviceRemovalCallback(manager,nil,nil)
  IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
  // Retain buffers/devices until every already queued output completes.
  let retiring=Array(devices.values);devices=[:]
  output.async{_ = retiring;IOHIDManagerClose(manager,IOOptionBits(kIOHIDOptionsTypeNone))}
 }
 func requestState(){for d in devices.values where d.info.compatible {send(XKeysReport.output(177),d)}}
 func setLEDs(_ frame:[XKeysLEDState]){
  precondition(Thread.isMainThread);guard frame.count==24 else{return};desired=frame
  for d in devices.values where d.info.compatible {applyLEDs(d)}
 }
 private func send(_ data:Data,_ d:Device){
  output.async{[weak self] in
   let status=data.withUnsafeBytes{raw in IOHIDDeviceSetReport(d.hid,kIOHIDReportTypeOutput,0,raw.bindMemory(to:UInt8.self).baseAddress!,data.count)}
   if status != kIOReturnSuccess {DispatchQueue.main.async{[weak self] in
    guard let self,self.devices[d.source] === d else{return}
    self.onError?(d.source,"XK-24 HID-uitvoer mislukt (\(String(format:"0x%08X",status))). LED-feedback kan worden uitgezet.")
   }}
  }
 }
 private func applyLEDs(_ d:Device){
  let old=d.leds;guard old != desired else{return}
  if old==nil {send(XKeysReport.output(187,160,160),d);send(XKeysReport.output(182,0,0),d);send(XKeysReport.output(182,1,0),d)}
  for key in 0..<24 where old?[key] != desired[key] {
   let index=XKeysReport.ledIndex(key),next=desired[key]
   // Extinguish the old color before enabling a new one.
   if next.red==0 {send(XKeysReport.output(181,index+32,0),d)}
   send(XKeysReport.output(181,index,next.blue),d)
   if next.red != 0 {send(XKeysReport.output(181,index+32,next.red),d)}
  }
  d.leds=desired
 }
 private func added(_ hid:IOHIDDevice){
  let source=Self.identity(hid);guard devices[source]==nil else{return}
  let pid=Self.number(hid,kIOHIDProductIDKey)
  let d=Device(hid,source:source,pid:pid);devices[source]=d
  guard XKeysReport.softwarePIDs.contains(pid),Self.number(hid,kIOHIDMaxInputReportSizeKey)==32,Self.number(hid,kIOHIDMaxOutputReportSizeKey)==35 else {
   onDevice?(d.info,XKeysReport.hardwarePIDs.contains(pid) ? "Hardwaremodus: geen directe toetsrapporten. Kies PID #1/#3 met de X-keys-software; FusionLab wijzigt de apparaatmodus niet.":"Onbekende of incompatibele X-keys-variant.");return
  }
  let context=Unmanaged.passUnretained(self).toOpaque()
  IOHIDDeviceRegisterInputReportCallback(hid,d.buffer,64,{context,result,sender,type,id,bytes,count in
   guard let context,let sender else{return}
   let selfRef=Unmanaged<XKeysDeviceManager>.fromOpaque(context).takeUnretainedValue()
   let hid=Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
   selfRef.received(hid,result:result,type:type,id:id,data:Data(bytes:bytes,count:max(0,count)))
  },context)
  onDevice?(d.info,"XK-24 aangesloten · descriptor controleren…")
  send(XKeysReport.output(214),d);send(XKeysReport.output(177),d)
 }
 private func removed(_ hid:IOHIDDevice){
  let source=Self.identity(hid);guard let d=devices.removeValue(forKey:source) else{return}
  IOHIDDeviceRegisterInputReportCallback(hid,d.buffer,64,nil,nil)
  output.async{_ = d};onRemoval?(source)
 }
 private func received(_ hid:IOHIDDevice,result:IOReturn,type:IOHIDReportType,id:UInt32,data:Data){
  guard let d=devices[Self.identity(hid)] else{return}
  guard result==kIOReturnSuccess,type==kIOHIDReportTypeInput,id==0 else{onError?(d.source,"XK-24 HID-invoerfout; PTT vrijgegeven.");return}
  let b=[UInt8](data)
  if b.count==32,b[1]==214 {
   let pid=Int(b[11])|Int(b[12])<<8
   guard b[7]==4,b[8]==6,pid==d.info.productID else{onError?(d.source,"Incompatibele XK-24-descriptor; geen toetsacties.");return}
   d.info.firmware=Int(b[10]);d.info.mode=Int(b[2]);d.info.compatible=true
   onDevice?(d.info,"Verbonden · directe HID-invoer gereed")
   applyLEDs(d);return
  }
  if b.count==32,[224,193].contains(b[1]) {return}
  guard d.info.compatible else{return}
  onReport?(d.source,data,id)
 }
 deinit {assert(manager==nil,"Stop XKeysDeviceManager before releasing it")}
}
