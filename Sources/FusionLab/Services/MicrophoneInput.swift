import AVFoundation
import AudioToolbox

protocol MicrophoneSource:AnyObject {
 func requestAccess(_ completion:@escaping (Bool)->Void)
 func start(onSamples:@escaping ([Float])->Void,onError:@escaping (String)->Void) throws
 func stop()
}

final class MicrophoneInput:MicrophoneSource {
 var deviceUID=""
 var channel=0
 var deliveryQueue:DispatchQueue = .main
 var onInfo:((String)->Void)?
 private var engine:AVAudioEngine?
 func requestAccess(_ completion:@escaping (Bool)->Void){
  switch AVCaptureDevice.authorizationStatus(for:.audio){
  case .authorized:completion(true)
  case .notDetermined:AVCaptureDevice.requestAccess(for:.audio){granted in DispatchQueue.main.async{completion(granted)}}
  default:completion(false)
  }
 }
 func start(onSamples:@escaping ([Float])->Void,onError:@escaping (String)->Void) throws {
  stop()
  let engine=AVAudioEngine(),input=engine.inputNode
  if !deviceUID.isEmpty {
   guard let device=AudioInputDevices.list().first(where:{$0.id==deviceUID}),let unit=input.audioUnit else {
    throw Packets.PacketError.message("De gekozen microfoon is niet beschikbaar. Kies de ingang opnieuw.")
   }
   var id=device.deviceID
   let status=AudioUnitSetProperty(unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&id,UInt32(MemoryLayout<AudioDeviceID>.size))
   guard status==noErr else{throw Packets.PacketError.message("Microfoon kiezen mislukt (CoreAudio \(status)).")}
   var actual=AudioDeviceID(0),size=UInt32(MemoryLayout<AudioDeviceID>.size)
   let check=AudioUnitGetProperty(unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&actual,&size)
   guard check==noErr,actual==device.deviceID else{throw Packets.PacketError.message("CoreAudio heeft de gekozen microfoon niet geactiveerd.")}
  }
  let native=input.outputFormat(forBus:0)
  let resampler=try MicrophoneResampler(source:native,channel:channel)
  let stats=CaptureStats(),info=onInfo,delivery=deliveryQueue
  input.installTap(onBus:0,bufferSize:1024,format:native){buffer,_ in
   do {
    let frames=try resampler.convert(buffer)
    if !stats.reported {stats.reported=true;let message="Microfoon levert \(buffer.frameLength) samples per callback op \(Int(native.sampleRate)) Hz (\(frames.count) audioblokken).";DispatchQueue.main.async{info?(message)}}
    delivery.async{for frame in frames{onSamples(frame)}}
   }catch {DispatchQueue.main.async{onError(error.localizedDescription)}}
  }
  self.engine=engine
  engine.prepare()
  do{try engine.start()}catch{stop();throw error}
 }
 func stop(){if let engine {engine.stop();engine.inputNode.removeTap(onBus:0)};engine=nil}
 deinit{stop()}
}

private final class CaptureStats {var reported=false}
