import Foundation
import CoreAudio

struct AudioInputDevice:Identifiable,Equatable {
 let id:String
 let name:String
 let deviceID:AudioDeviceID
 let channels:Int
}

enum AudioInputDevices {
 static func list()->[AudioInputDevice]{
  var address=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDevices,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
  var size:UInt32=0
  guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size)==noErr else{return []}
  var ids=[AudioDeviceID](repeating:0,count:Int(size)/MemoryLayout<AudioDeviceID>.size)
  let status=ids.withUnsafeMutableBytes{AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size,$0.baseAddress!)}
  guard status==noErr else{return []}
  return ids.compactMap{id in
   let channels=inputChannels(id)
   guard channels>0,let uid=string(id,kAudioDevicePropertyDeviceUID),let name=string(id,kAudioObjectPropertyName) else{return nil}
   return AudioInputDevice(id:uid,name:name,deviceID:id,channels:channels)
  }.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
 }
 static func defaultInput()->AudioDeviceID {
  var value=AudioDeviceID(0),size=UInt32(MemoryLayout<AudioDeviceID>.size)
  var address=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDefaultInputDevice,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
  _=AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,&size,&value)
  return value
 }
 private static func string(_ id:AudioDeviceID,_ selector:AudioObjectPropertySelector)->String? {
  var address=AudioObjectPropertyAddress(mSelector:selector,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
  var value:Unmanaged<CFString>?,size=UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
  guard AudioObjectGetPropertyData(id,&address,0,nil,&size,&value)==noErr else{return nil}
  return value?.takeRetainedValue() as String?
 }
 private static func inputChannels(_ id:AudioDeviceID)->Int {
  var address=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyStreamConfiguration,mScope:kAudioDevicePropertyScopeInput,mElement:kAudioObjectPropertyElementMain)
  var size:UInt32=0
  guard AudioObjectGetPropertyDataSize(id,&address,0,nil,&size)==noErr,size>0 else{return 0}
  let memory=UnsafeMutableRawPointer.allocate(byteCount:Int(size),alignment:MemoryLayout<AudioBufferList>.alignment)
  defer{memory.deallocate()}
  guard AudioObjectGetPropertyData(id,&address,0,nil,&size,memory)==noErr else{return 0}
  return UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to:AudioBufferList.self)).reduce(0){$0+Int($1.mNumberChannels)}
 }
}
