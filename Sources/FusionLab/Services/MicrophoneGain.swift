import Foundation

struct MicrophoneGain {
 struct Result {
  let samples:[Float]
  let rms:Float
  let peak:Float
  let clipped:Bool
 }
 static func process(_ samples:[Float],decibels:Double)->Result {
  let db=decibels.isFinite ? min(36,max(-12,decibels)):0
  let gain=Float(pow(10,db/20))
  var peak:Float=0,energy:Float=0,clipped=false
  let output=samples.map{sample -> Float in
   let input=sample.isFinite ? sample:0
   let amplified=input*gain
   peak=max(peak,abs(amplified))
   if abs(input)>=1 || abs(amplified)>=1 {clipped=true}
   // Saturate before PCM conversion; never wrap an overloaded sample.
   let value=min(Float(32767)/32768,max(-1,amplified))
   energy += value*value
   return value
  }
  return Result(samples:output,rms:output.isEmpty ? 0:sqrt(energy/Float(output.count)),peak:min(peak,1),clipped:clipped)
 }
}
