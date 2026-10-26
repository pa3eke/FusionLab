import Foundation

// Receive-only, mono 8 kHz PCM. RMS leveling with a fast gain reduction and
// slower recovery; block lookahead limits peaks without flattening the waveform.
struct ReceiveAGC {
 private(set) var gain:Float=1
 private let targetRMS:Float=0.14
 private let maximumGain:Float=8 // +18 dB maximum lift
 private let speechFloor:Float=0.0032 // Do not increase gain for background below -50 dBFS.
 private let ceiling:Float=0.85
 mutating func reset(){gain=1}
 mutating func process(_ input:[Float])->[Float] {
  guard !input.isEmpty else{return []}
  let samples=input.map{$0.isFinite ? $0:0}
  let rms=sqrt(samples.reduce(Float(0)){$0+$1*$1}/Float(samples.count))
  let peak=samples.reduce(Float(0)){max($0,abs($1))}
  let desired=rms>=speechFloor ? min(maximumGain,targetRMS/max(rms,0.000001)):gain
  let time:Float=desired<gain ? 0.01:0.6
  let smoothing=exp(-1/(8000*time))
  let peakGain=peak>0 ? ceiling/peak:maximumGain
  return samples.map {sample in
   gain=desired+(gain-desired)*smoothing
   return sample*min(gain,peakGain)
  }
 }
}
