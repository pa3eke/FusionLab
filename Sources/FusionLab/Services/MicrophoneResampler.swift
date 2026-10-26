import AVFoundation

// Used only from the serial audio-input callback. Separately testable without
// opening an actual microphone or asking for permission.
final class MicrophoneResampler {
 private let source:AVAudioFormat
 private let target:AVAudioFormat
 private let converter:AVAudioConverter
 private var samples=[Float]()
 private let channel:Int
 init(source:AVAudioFormat,channel:Int=0) throws {
  guard source.sampleRate>0,source.channelCount>0,
   let target=AVAudioFormat(standardFormatWithSampleRate:8000,channels:1),
   let converter=AVAudioConverter(from:AVAudioFormat(standardFormatWithSampleRate:source.sampleRate,channels:1)!,to:target) else {
   throw Packets.PacketError.message("Geen bruikbaar microfoonformaat gevonden.")
  }
  self.channel=channel
  self.source=source;self.target=target;self.converter=converter
 }
 func convert(_ input:AVAudioPCMBuffer) throws -> [[Float]] {
  let capacity=AVAudioFrameCount(ceil(Double(input.frameLength)*8000/source.sampleRate)+32)
  guard let output=AVAudioPCMBuffer(pcmFormat:target,frameCapacity:capacity) else{return []}
  // Explicitly select the hardware channel before resampling. Do not average
  // stereo inputs: a microphone can be wired to only one PUC2 channel.
  let selected:AVAudioPCMBuffer
  if source.channelCount>1,let mono=AVAudioFormat(standardFormatWithSampleRate:source.sampleRate,channels:1),let copy=AVAudioPCMBuffer(pcmFormat:mono,frameCapacity:input.frameLength),let data=input.floatChannelData {
   copy.frameLength=input.frameLength
   let index=min(max(channel,0),Int(source.channelCount)-1)
   copy.floatChannelData![0].update(from:data[index],count:Int(input.frameLength))
   selected=copy
  }else{selected=input}
  var fed=false,error:NSError?
  let status=converter.convert(to:output,error:&error){_,state in
   if fed {state.pointee = .noDataNow;return nil}
   fed=true;state.pointee = .haveData;return selected
  }
  if status == .error {throw error ?? Packets.PacketError.message("Microfoonconversie mislukt.") as NSError}
  guard let values=output.floatChannelData?[0],output.frameLength>0 else{return []}
  samples.append(contentsOf:UnsafeBufferPointer(start:values,count:Int(output.frameLength)))
  var frames=[[Float]]()
  while samples.count>=160 {frames.append(Array(samples.prefix(160)));samples.removeFirst(160)}
  return frames
 }
}
