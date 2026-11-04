import Foundation
import CryptoKit
import MD380Codec

final class MD380Vocoder {
 static let supportDirectory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("FusionLab/MD380")
 private var context:OpaquePointer?
 private let firmware:Data,ram:Data,library:String
 init(directory:URL=MD380Vocoder.supportDirectory) throws {
  let bundled=Bundle.main.privateFrameworksURL?.appendingPathComponent("libunicorn.2.dylib")
  library=(bundled.flatMap{FileManager.default.fileExists(atPath:$0.path) ? $0:nil} ?? directory.appendingPathComponent("libunicorn.2.dylib")).path
  do {
   firmware=try Data(contentsOf:directory.appendingPathComponent("md380fw.img"))
   ram=try Data(contentsOf:directory.appendingPathComponent("md380ram.img"))
  }catch{throw Packets.PacketError.message("MD380-bestanden ontbreken. Installeer de lokale MD380-ondersteuning; AMBEserver blijft beschikbaar.")}
  func digest(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
  guard digest(firmware)=="c0351f250a834660641bca3b06be931c80cc1ed0ef808356c550b99cd0f4c632",digest(ram)=="d40398183e9aa8db6288a62d9a0e0c233cb143ef5633680abd829cc03c719f66" else{throw Packets.PacketError.message("MD380-firmware komt niet overeen met de geteste versie.")}
  try reset()
 }
 func reset() throws {
  if let context {md380_destroy(context)};context=nil
  var error=[CChar](repeating:0,count:256)
  context=firmware.withUnsafeBytes{fw in ram.withUnsafeBytes{memory in
   md380_create(library,fw.bindMemory(to:UInt8.self).baseAddress,firmware.count,memory.bindMemory(to:UInt8.self).baseAddress,ram.count,&error,error.count)
  }}
  guard context != nil else{throw Packets.PacketError.message("MD380 starten mislukt: \(String(cString:error))")}
 }
 // 49-bit frames here are native MD380 parameters, not DVSI wire order.
 func encode(_ pcm:[Int16],bits:UInt8) throws ->Data {
  guard pcm.count==160,(bits==49 || bits==72) else{throw Packets.PacketError.message("Ongeldig MD380-audioblok.")}
  var voice=[UInt8](repeating:0,count:bits==49 ? 7:9),error=[CChar](repeating:0,count:256)
  guard md380_encode_frame(context,pcm,&voice,Int32(bits),&error,error.count)==1 else{throw Packets.PacketError.message("MD380 encoder: \(String(cString:error))")}
  return Data(voice)
 }
 func decode(_ voice:Data,bits:UInt8) throws ->[Int16] {
  guard (bits==49 && voice.count==7)||(bits==72 && voice.count==9) else{throw Packets.PacketError.message("Ongeldig MD380-spraakblok.")}
  var pcm=[Int16](repeating:0,count:160),error=[CChar](repeating:0,count:256)
  guard md380_decode_frame(context,[UInt8](voice),Int32(bits),&pcm,&error,error.count)==1 else{throw Packets.PacketError.message("MD380 decoder: \(String(cString:error))")}
  return pcm
 }
 deinit{if let context {md380_destroy(context)}}
}
