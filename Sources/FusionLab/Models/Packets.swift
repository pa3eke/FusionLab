import Foundation
import YSFCodec

enum Packets {
 static let rate = Data([0x61,0,13,0,0x0a,4,0x31,7,0x54,0,0,0,0,0,0,0x70,0x31])
 static func control(_ field: UInt8) -> Data { Data([0x61,0,1,0,field]) }
 static func poll(_ call: String, disconnect: Bool = false) -> Data {
  Data((disconnect ? "YSFU" : "YSFP").utf8) + Data((String(call.uppercased().prefix(10)).padding(toLength:10, withPad:" ", startingAt:0)).utf8)
 }
 static func ambe(_ voice: Data,bits:UInt8=49) -> Data { Data([0x61,0,UInt8(voice.count+2),1,1,bits]) + voice }
 static func speech(_ samples:[Float]) -> Data {
  precondition(samples.count==160)
  var result=Data([0x61,1,66,2,0,160])
  for sample in samples {
   let finite=sample.isFinite ? sample:0
   let value=Int16(max(-32768,min(32767,(finite*32768).rounded())))
   let bits=UInt16(bitPattern:value)
   result.append(UInt8(bits>>8));result.append(UInt8(bits&255))
  }
  return result
 }
 static func encodedVoice(_ d:Data,bits:UInt8=49) -> Data? {
  guard let p=dv3k(d),p.type==1 else{return nil}
  let b=[UInt8](p.body)
  let length=(Int(bits)+7)/8,bodyLength=length+2
  guard b.count>=bodyLength,b[0]==1,b[1]==bits else{return nil}
  // AMBE3000R includes a CHANMODE field (02 + 16-bit mode) after CHAND.
  guard b.count==bodyLength || (b.count==bodyLength+3 && b[bodyLength]==2) else{return nil}
  return Data(b[2..<bodyLength])
 }
 static func transmit(call:String,sequence:Int,fi:UInt8,voice:[Data]=[]) -> Data {
  precondition(fi != 1 || (voice.count==5 && voice.allSatisfy{$0.count==7}))
  let padded=Array(String(call.uppercased().prefix(10)).padding(toLength:10,withPad:" ",startingAt:0).utf8)
  let raw=fi==1 ? voice.flatMap{[UInt8]($0)}:[UInt8](repeating:0,count:35)
  var payload=[UInt8](repeating:0,count:120)
  ysf_encode_dn(padded,raw,fi,UInt8(max(0,sequence-1)%7),&payload)
  var result=Data("YSFD".utf8)+Data(padded)+Data(padded)+Data("ALL       ".utf8)
  result.append(UInt8((sequence&127)<<1)|(fi==2 ? 1:0))
  result.append(contentsOf:payload)
  return result
 }
 static func dv3k(_ d: Data) -> (type: UInt8, body: Data)? {
  let b = [UInt8](d)
  guard b.count >= 5, b[0] == 0x61, Int(b[1])*256+Int(b[2]) == b.count-4 else { return nil }
  return (b[3], Data(b.dropFirst(4)))
 }
 static func pcm(_ d: Data) -> [Float]? {
  guard let p=dv3k(d), p.type==2 else { return nil }
  let b=[UInt8](p.body)
  guard b.count==322, b[0]==0, b[1]==160 else{return nil}
  return stride(from:2,to:322,by:2).map { Float(Int16(bitPattern:UInt16(b[$0])<<8|UInt16(b[$0+1])))/32768 }
 }
 struct Reception {
  var source: String; var gateway: String; var sequence: UInt8; var end: Bool
  var fi: UInt8; var mode: UInt8; var frames: [Data]
 }
 static func receive(_ d: Data) throws -> Reception {
  let b=[UInt8](d)
  guard b.count==155, Array(b.prefix(4))==Array("YSFD".utf8) else {throw PacketError.message("Ongeldig YSF-pakket (\(b.count) bytes)")}
  var out=[UInt8](repeating:0,count:35), fi:UInt8=0, dt:UInt8=0
  let payload=Array(b[35..<155])
  let result=ysf_decode_dn(payload,120,&out,&fi,&dt)
  guard result>=0 else {throw PacketError.message("FICH/CRC of synchronisatie ongeldig")}
  func call(_ start: Int)->String {String(decoding:b[start..<start+10],as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)}
  return Reception(source:call(14),gateway:call(4),sequence:b[34]>>1,end:b[34]&1 != 0,fi:fi,mode:dt,frames:result==5 ? stride(from:0,to:35,by:7).map{Data(out[$0..<$0+7])}:[])
 }
 enum PacketError: LocalizedError {case message(String); var errorDescription:String? {switch self {case .message(let s):return s}}}
}
