import Foundation

// NXDNReflector's 17-byte NXDNP/NXDNU control and 43-byte NXDND voice
// transport. Wire reference: G4KLX NXDNClients/NXDNNetwork.cpp and AD8DP
// DroidStar/nxdn.cpp (GPL-2.0-or-later / GPL-3.0-or-later respectively).
// Public vocoder boundary remains DVSI; the network carries native AMBE49.
enum NXDNPackets {
 static func poll(_ call:String,destination:UInt16,disconnect:Bool=false)->Data {
  let name=String(call.uppercased().prefix(10)).padding(toLength:10,withPad:" ",startingAt:0)
  return Data((disconnect ? "NXDNU":"NXDNP").utf8)+Data(name.utf8)+Data([UInt8(destination>>8),UInt8(destination&255)])
 }
 static func isPollReply(_ data:Data,call:String,destination:UInt16)->Bool {
  data==poll(call,destination:destination)
 }
 static func transmit(settings:NXDNVoiceSettings,sequence:Int,kind:UInt8,voice:[Data]=[])->Data {
  precondition(kind<=2 && (kind != 1 || (voice.count==4 && voice.allSatisfy{$0.count==7})))
  let s=settings
  var b=[UInt8](repeating:0,count:43)
  b.replaceSubrange(0..<5,with:Array("NXDND".utf8))
  b[5]=UInt8(s.source>>8);b[6]=UInt8(s.source&255)
  b[7]=UInt8(s.destination>>8);b[8]=UInt8(s.destination&255)
  var lc=[UInt8](repeating:0,count:14)
  lc[0]=kind==2 ? 8:1;lc[2]=0x20
  lc[3]=b[5];lc[4]=b[6];lc[5]=b[7];lc[6]=b[8]
  b[9]=kind==0 ? 5:kind==2 ? 9:1
  b[10]=kind==1 ? 0xac:0x81
  var sacch=[UInt8](repeating:0,count:4)
  if kind==1 {
   let phase=sequence%4
   sacch[0]=UInt8(3-phase)<<6 | (s.ran&63)
   for i in 0..<18 {put(&sacch,8+i,bit(lc,phase*18+i))}
  }else {
   sacch[0]=s.ran&63
   sacch[1]=0x10 // idle SACCH content, 18 bits
  }
  let crc=crc6(sacch)
  for i in 0..<6 {put(&sacch,26+i,(crc & (0x20>>i)) != 0)}
  b.replaceSubrange(11..<15,with:sacch)
  if kind==1 {
   let raw=voice.map{[UInt8](try! AMBE49BitOrder.toMD380($0))}
   let offsets=[120,169,232,281]
   for block in 0..<4 {for i in 0..<49 {put(&b,offsets[block]+i,bit(raw[block],i))}}
   // Match DroidStar's spare-bit fill; these bits are outside the AMBE49 data.
   b[28] |= raw[1][6]>>2;b[41] |= raw[3][6]>>2
  }else {
   b.replaceSubrange(15..<29,with:lc);b.replaceSubrange(29..<43,with:lc)
  }
  return Data(b)
 }
 struct Reception {
  let source:UInt16,destination:UInt16
  let kind:UInt8,ran:UInt8
  let frames:[Data]
 }
 static func receive(_ data:Data)->Reception? {
  let b=[UInt8](data)
  guard b.count==43,Array(b.prefix(5))==Array("NXDND".utf8),b[9]&0xf2==0,b[9]&1==1,
   (b[10]==0x81 || b[10]==0x83 || b[10]==0xac || b[10]==0xae) else{return nil}
  let source=UInt16(b[5])<<8|UInt16(b[6]),destination=UInt16(b[7])<<8|UInt16(b[8])
  guard source>0,source<=65519,destination>0 else{return nil}
  let sacch=Array(b[11..<15])
  let receivedCRC=(0..<6).reduce(UInt8(0)){($0<<1)|(bit(sacch,26+$1) ? 1:0)}
  guard crc6(sacch)==receivedCRC else{return nil}
  let control=((b[10]>>4)&3)==0
  let kind:UInt8
  if control {
   guard Array(b[15..<29])==Array(b[29..<43]),b[18]==b[5],b[19]==b[6],b[20]==b[7],b[21]==b[8],b[17]&0x20 != 0 else{return nil}
   if b[15]&63==1,b[9]&12==4 {kind=0}
   else if b[15]&63==8,b[9]&12==8 {kind=2}
   else{return nil}
  }else {
   guard b[9]&12==0 else{return nil};kind=1
  }
  var frames=[Data]()
  if kind==1 {
   for offset in [120,169,232,281] {
    var raw=[UInt8](repeating:0,count:7)
    for i in 0..<49 {put(&raw,i,bit(b,offset+i))}
    frames.append(try! AMBE49BitOrder.fromMD380(Data(raw)))
   }
  }
  return Reception(source:source,destination:destination,kind:kind,ran:b[11]&63,frames:frames)
 }
 private static func bit(_ bytes:[UInt8],_ index:Int)->Bool {bytes[index/8] & (0x80>>(index%8)) != 0}
 private static func put(_ bytes:inout [UInt8],_ index:Int,_ value:Bool){
  if value {bytes[index/8] |= 0x80>>(index%8)}else{bytes[index/8] &= ~(0x80>>(index%8))}
 }
 private static func crc6(_ data:[UInt8])->UInt8 {
  var crc:UInt8=0x3f
  for i in 0..<26 {
   let feedback=bit(data,i) != (crc&0x20 != 0)
   crc=crc &<< 1
   if feedback {crc ^= 0x27}
  }
  return crc&63
 }
}
