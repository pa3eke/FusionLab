import Foundation
import CryptoKit
import YSFCodec

enum DigitalMode:String,CaseIterable,Identifiable {
 case fusion,dmr
 var id:String {rawValue}
 var title:String {self == .fusion ? "Fusion · YSF":"DMR · BrandMeister"}
}

struct DMRVoiceSettings:Equatable {
 let source:UInt32,destination:UInt32,peer:UInt32
 let slot:UInt8,colorCode:UInt8
 let privateCall:Bool
}

enum VoiceProfile:Equatable {
 case fusion,dmr(DMRVoiceSettings)
 var blocks:Int {if case .fusion=self{return 5};return 3}
 var bits:UInt8 {if case .fusion=self{return 49};return 72}
 var interval:TimeInterval {Double(blocks)*0.02}
 var rate:Data {
  if case .fusion=self{return Packets.rate}
  return Data([0x61,0,13,0,0x0a,4,0x31,7,0x54,0x24,0,0,0,0,0,0x6f,0x48])
 }
}

enum DMRPackets {
 static func id(_ value:UInt32)->Data {Data([UInt8(value>>24),UInt8((value>>16)&255),UInt8((value>>8)&255),UInt8(value&255)])}
 static func control(_ tag:String,peer:UInt32)->Data {Data(tag.utf8)+id(peer)}
 static func authentication(peer:UInt32,salt:Data,password:String)->Data {
  control("RPTK",peer:peer)+Data(SHA256.hash(data:salt+Data(password.utf8)))
 }
 static func configuration(peer:UInt32,call:String,colorCode:UInt8=1)->Data {
  func field(_ value:String,_ count:Int)->Data {
   let bytes=Array(value.utf8.prefix(count));return Data(bytes)+Data(repeating:32,count:count-bytes.count)
  }
  // Homebrew 294-byte configuration, following the fixed-width MMDVM layout.
  // Software clients still supply nominal RF metadata (as DroidStar does).
  // These values do not tune hardware or cause RF transmission; location is unknown.
  // Keep the client identity truthful and the software version in YYYYMMDD format.
  var d=control("RPTC",peer:peer)
  for (value,count) in [(call,8),("438800000",9),("438800000",9),("00",2),(String(format:"%02u",colorCode),2),("0.000000",8),("00.000000",9),("000",3),("",20),("FusionLab DMR",19),("4",1),("",124),("20261025",40),("MMDVM_FusionLab",40)] {d += field(value,count)}
  return d
 }
 static func transmit(settings s:DMRVoiceSettings,sequence:Int,stream:UInt32,kind:UInt8,voice:[Data]=[])->Data {
  precondition(kind != 1 || (voice.count==3 && voice.allSatisfy{$0.count==9}))
  let raw=kind==1 ? voice.flatMap{[UInt8]($0)}:[UInt8](repeating:0,count:27)
  var payload=[UInt8](repeating:0,count:33)
  dmr_encode_payload(s.source,s.destination,s.privateCall ? 1:0,s.colorCode,kind,UInt32(max(0,sequence-1)),raw,&payload)
  var d=Data("DMRD".utf8);d.append(UInt8(sequence&255))
  d += id(s.source).suffix(3);d += id(s.destination).suffix(3);d += id(s.peer)
  let phase=max(0,sequence-1)%6
  let frameType:UInt8=kind==0 ? 0x21:kind==2 ? 0x22:phase==0 ? 0x10:UInt8(phase)
  d.append((s.slot==2 ? 0x80:0)|(s.privateCall ? 0x40:0)|frameType)
  // Stream IDs are opaque on Homebrew; match DroidStar's little-endian ID.
  d.append(contentsOf:[UInt8(stream&255),UInt8((stream>>8)&255),UInt8((stream>>16)&255),UInt8(stream>>24)])
  d.append(contentsOf:payload);d.append(contentsOf:[0,0]);return d
 }
 struct Reception {
  let source:UInt32,destination:UInt32,peer:UInt32,stream:UInt32
  let sequence:UInt8,slot:UInt8,privateCall:Bool,kind:UInt8,frames:[Data]
 }
 static func receive(_ data:Data)->Reception? {
  let b=[UInt8](data)
  guard b.count==55,Array(b[0..<4])==Array("DMRD".utf8) else{return nil}
  func number(_ range:Range<Int>)->UInt32 {range.reduce(0){($0<<8)|UInt32(b[$1])}}
  let flags=b[15],isData=flags&0x20 != 0,type=flags&15
  // Voice LC header and terminator are the only supported data bursts.
  guard !isData || type==1 || type==2 else{return nil}
  if !isData,flags&0x10==0,type>5{return nil}
  let kind:UInt8=isData ? (type==1 ? 0:2):1
  if isData {
   var lc=[UInt8](repeating:0,count:12)
   guard dmr_decode_lc(Array(b[20..<53]),kind,&lc)==1 else{return nil}
   // Unsupported LC opcodes (including encrypted signalling) are not voice.
   guard lc[0]==0 || lc[0]==3,lc[2]&0x40==0 else{return nil}
  }
  var frames=[Data]()
  if kind==1 {
   var raw=Array(b[20..<34]);raw[13]=(raw[13]&0xf0)|(b[39]&0x0f)
   raw.append(contentsOf:b[40..<53])
   frames=stride(from:0,to:27,by:9).map{Data(raw[$0..<$0+9])}
  }
  return Reception(source:number(5..<8),destination:number(8..<11),peer:number(11..<15),stream:UInt32(b[16])|UInt32(b[17])<<8|UInt32(b[18])<<16|UInt32(b[19])<<24,sequence:b[4],slot:flags&0x80==0 ? 1:2,privateCall:flags&0x40 != 0,kind:kind,frames:frames)
 }
}
