import Foundation

struct ReceiveEQSettings:Equatable {
 var low:Double=0,mid:Double=0,high:Double=0
 var normalized:Self {
  func safe(_ value:Double)->Double {value.isFinite ? min(12,max(-12,value)):0}
  return Self(low:safe(low),mid:safe(mid),high:safe(high))
 }
 static func load(_ defaults:UserDefaults = .standard)->Self {
  Self(low:defaults.double(forKey:"receiveEQLow"),mid:defaults.double(forKey:"receiveEQMid"),high:defaults.double(forKey:"receiveEQHigh")).normalized
 }
 func save(_ defaults:UserDefaults = .standard){
  let value=normalized
  defaults.set(value.low,forKey:"receiveEQLow");defaults.set(value.mid,forKey:"receiveEQMid");defaults.set(value.high,forKey:"receiveEQHigh")
 }
}

// Mono 8 kHz receive EQ, before AGC. Biquad formulae: Robert Bristow-Johnson,
// W3C Audio EQ Cookbook https://www.w3.org/TR/audio-eq-cookbook/
struct ReceiveEQ {
 private var settings=ReceiveEQSettings()
 private var bank=Bank(),old:Bank?
 private var fade=0
 var isActive:Bool {settings != ReceiveEQSettings() || fade>0}
 mutating func configure(_ value:ReceiveEQSettings){
  let value=value.normalized
  guard value != settings else{return}
  old=bank;bank=Bank(value);settings=value;fade=160 // 20 ms crossfade
 }
 mutating func reset(){bank=Bank(settings);old=nil;fade=0}
 mutating func process(_ input:[Float])->[Float] {
  input.map {sample in
   let x=sample.isFinite ? Double(sample):0
   let next=bank.process(x)
   guard fade>0,var previous=old else{return Float(next)}
   let prior=previous.process(x);old=previous
   let mix=Double(161-fade)/160
   fade -= 1
   if fade==0 {old=nil}
   return Float(prior+(next-prior)*mix)
  }
 }
 private struct Bank {
  var filters:[Biquad]
  init(_ value:ReceiveEQSettings = .init()){
   filters=[Biquad(gain:value.low,frequency:300,kind:0),Biquad(gain:value.mid,frequency:1000,kind:1),Biquad(gain:value.high,frequency:2200,kind:2)]
  }
  mutating func process(_ x:Double)->Double {
   var y=x
   for i in filters.indices {y=filters[i].process(y)}
   return y
  }
 }
 private struct Biquad {
  var b0:Double=1,b1:Double=0,b2:Double=0,a1:Double=0,a2:Double=0
  var z1:Double=0,z2:Double=0
  init(gain:Double,frequency:Double,kind:Int){
   guard gain != 0 else{return}
   let a=pow(10,gain/40),w=2 * Double.pi * frequency/8000,c=cos(w),s=sin(w)
   var numerator:[Double],denominator:[Double]
   if kind==1 {
    let alpha=s/2 // Q = 1
    numerator=[1+alpha*a,-2*c,1-alpha*a]
    denominator=[1+alpha/a,-2*c,1-alpha/a]
   }else {
    let beta=sqrt(2*a)*s // shelf slope S = 1
    if kind==0 {
     numerator=[a*((a+1)-(a-1)*c+beta),2*a*((a-1)-(a+1)*c),a*((a+1)-(a-1)*c-beta)]
     denominator=[(a+1)+(a-1)*c+beta,-2*((a-1)+(a+1)*c),(a+1)+(a-1)*c-beta]
    }else {
     numerator=[a*((a+1)+(a-1)*c+beta),-2*a*((a-1)+(a+1)*c),a*((a+1)+(a-1)*c-beta)]
     denominator=[(a+1)-(a-1)*c+beta,2*((a-1)-(a+1)*c),(a+1)-(a-1)*c-beta]
    }
   }
   b0=numerator[0]/denominator[0];b1=numerator[1]/denominator[0];b2=numerator[2]/denominator[0]
   a1=denominator[1]/denominator[0];a2=denominator[2]/denominator[0]
  }
  mutating func process(_ x:Double)->Double {
   let y=b0*x+z1
   z1=b1*x-a1*y+z2;z2=b2*x-a2*y
   return y
  }
 }
}
