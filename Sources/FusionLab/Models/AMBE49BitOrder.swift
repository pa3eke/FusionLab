import Foundation

// FusionLab's YSF boundary uses the AMBE3000/DVSI 49-bit ordering.
// MD380 exposes the uncoded A(12), B(12), C(25) parameter ordering instead.
// Positions follow DroidStar ysf.cpp (AD8DP, GPL-3.0-or-later): hardware-only
// interleave() on RX and the inverse in encode_dv2() on TX. DMR's 72-bit
// framing has its own FEC mapping and must not pass through this conversion.
enum AMBE49BitOrder {
 private static let dvsiPositions=[
  0,3,6,9,12,15,18,21,24,27,30,33,36,39,41,43,45,47,
  1,4,7,10,13,16,19,22,25,28,31,34,37,40,42,44,46,48,
  2,5,8,11,14,17,20,23,26,29,32,35,38
 ]
 static func toMD380(_ dvsi:Data)throws->Data {try reorder(dvsi,toDVSI:false)}
 static func fromMD380(_ native:Data)throws->Data {try reorder(native,toDVSI:true)}
 private static func reorder(_ frame:Data,toDVSI:Bool)throws->Data {
  guard frame.count==7 else{throw Packets.PacketError.message("Een 49-bits AMBE-frame moet 7 bytes bevatten.")}
  let input=[UInt8](frame)
  var output=[UInt8](repeating:0,count:7)
  for (native,dvsi) in dvsiPositions.enumerated(){
   let source=toDVSI ? native:dvsi,destination=toDVSI ? dvsi:native
   if input[source/8] & (0x80 >> (source%8)) != 0 {output[destination/8] |= 0x80 >> (destination%8)}
  }
  return Data(output)
 }
}
