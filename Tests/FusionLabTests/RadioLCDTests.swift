import AppKit
import SwiftUI

extension ProtocolTests {
 @MainActor func testRadioLCDPresentationAndMeter(){
  let savedKeys=["nxdnID","nxdnHost","nxdnPort","nxdnDestination","nxdnRAN"]
  let savedValues=savedKeys.map{UserDefaults.standard.object(forKey:$0)}
  defer{for (key,value) in zip(savedKeys,savedValues){UserDefaults.standard.set(value,forKey:key)}}
  let s=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),xkeysTransport:StubXKeys())
  s.selectMode(.dmr);s.call="PA3EKE";s.dmr.radioID="2041007";s.dmr.destination="204";s.dmr.privateCall=false
  s.station="PD1LOI · 2047075";s.active=true;s.readyToTransmit=true;s.ysfStatus="Verbonden · BrandMeister"
  s.gateway="BrandMeister · 204100702";s.mode="DMR · TG 91 · TS2";s.receivingAudio=true;s.level=0.1
  var p=RadioLCDPresentation(session:s)
  XCTAssertEqual(p.callsign,"PD1LOI");XCTAssertEqual(p.identifier,"2047075");XCTAssertEqual(p.identifierLabel,"DMR ID")
  XCTAssertEqual(p.destination,"TG 91","RX shows the actual received target, not the configured next-PTT target")
  XCTAssertEqual(p.status,"RX");XCTAssertEqual(p.network,"BrandMeister");XCTAssertEqual(p.connected,true)
  XCTAssertEqual(p.qrzURL?.absoluteString,"https://www.qrz.com/db/PD1LOI")
  XCTAssertEqual(abs((p.audioDBFS ?? 0)+20)<0.001,true);XCTAssertEqual(p.audioText,"-20 dBFS")
  p.level=0;XCTAssertNil(p.audioDBFS);XCTAssertEqual(p.audioText,"−∞ dBFS");XCTAssertEqual(p.activeSegments,0)
  p.level = .nan;XCTAssertEqual(p.activeSegments,0)
  p.level = .infinity;XCTAssertNil(p.audioDBFS)
  p.level=1;XCTAssertEqual(p.audioText,"0 dBFS");XCTAssertEqual(p.activeSegments,40)
  p.level=0.001;XCTAssertEqual(p.activeSegments<=1,true)
  s.receivingAudio=false;s.transmitting=true
  p=RadioLCDPresentation(session:s)
  XCTAssertEqual(p.callsign,"PA3EKE");XCTAssertEqual(p.identifier,"2041007");XCTAssertEqual(p.status,"TX")
  XCTAssertEqual(p.destination,"TG 204");XCTAssertNil(p.qrzURL)
  s.transmitting=false;s.active=false;s.station="2047075";s.ysfStatus="Losgekoppeld";s.connectionError="Geen antwoord"
  p=RadioLCDPresentation(session:s)
  XCTAssertEqual(p.status,"LOS");XCTAssertEqual(p.connected,false);XCTAssertEqual(p.callsign,"—");XCTAssertEqual(p.identifier,"2047075")
  XCTAssertEqual(p.error,"Geen antwoord")
  s.selectMode(.nxdn);s.station="PA3EHA · 4163";s.nxdn.radioID="41007";s.nxdn.destination="7300"
  p=RadioLCDPresentation(session:s)
  XCTAssertEqual(p.modeTitle,"NXDN");XCTAssertEqual(p.identifierLabel,"NXDN ID");XCTAssertEqual(p.identifier,"4163");XCTAssertEqual(p.destination,"TG 7300")
  s.selectMode(.fusion);s.station="ZL1RDK";s.host="c4fm.pa7lim.nl";s.port="42000"
  p=RadioLCDPresentation(session:s)
  XCTAssertEqual(p.modeTitle,"C4FM");XCTAssertEqual(p.callsign,"ZL1RDK");XCTAssertNil(p.identifier)
  XCTAssertEqual(p.network,"YSF");XCTAssertEqual(p.destination,"c4fm.pa7lim.nl:42000")
  let entry=YSFHost(number:"32592",name:"US-America Link",description:"",host:"63.250.41.136",port:42000)
  XCTAssertEqual(RadioLCDPresentation.reflectorTitle(host:entry.host,port:"42000",hosts:[entry],presets:[]),entry.name)
  XCTAssertNil(RadioLCDPresentation.reflectorTitle(host:entry.host,port:"42001",hosts:[entry],presets:[]))
  XCTAssertEqual(RadioLCDPresentation.reflectorTitle(host:"C4FM.PA7LIM.NL",port:"42000",hosts:[],presets:[.fusion(title:"Echo PA7LIM",host:"c4fm.pa7lim.nl",port:42000)]),"Echo PA7LIM")
  XCTAssertNil(RadioLCDPresentation.reflectorTitle(host:"other.example",port:"42000",hosts:[],presets:[.dmr(title:"TG204",destination:204,privateCall:false)]))
  s.host=entry.host;s.port="42000"
  p=RadioLCDPresentation(session:s,reflectorTitle:entry.name)
  XCTAssertEqual(p.destination,"US-America Link");XCTAssertEqual(p.detail.contains("63.250.41.136:42000"),true)
  XCTAssertEqual(s.host,"63.250.41.136","Display metadata must not change the connection endpoint")
 }
 @MainActor func testRenderedRadioLCD() async throws {
  _=NSApplication.shared
  let s=RadioSession(pttKey:StubPTTKey(),passwordStore:MemoryDMRPasswordStore(),xkeysTransport:StubXKeys())
  s.selectMode(.dmr);s.station="PD1LOI · 2047075";s.dmr.destination="204";s.dmr.privateCall=false;s.active=true;s.readyToTransmit=true;s.ysfStatus="Verbonden · BrandMeister";s.level=0.1
  var model=RadioLCDPresentation(session:s)
  let host=NSHostingView(rootView:RadioLCDView(model:model))
  let window=NSWindow(contentRect:NSRect(x:-5000,y:-5000,width:797,height:232),styleMask:.borderless,backing:.buffered,defer:false)
  window.isReleasedWhenClosed=false;window.contentView=host;window.orderFront(nil)
  defer{window.contentView=nil;window.close()}
  for (name,width) in [("normal",797),("compact",617),("wide",1177),("tx",797)] {
   if name=="tx" {s.call="PA3EKE";s.dmr.radioID="2041007";s.transmitting=true;model=RadioLCDPresentation(session:s)}
   host.rootView=RadioLCDView(model:model)
   window.setContentSize(NSSize(width:width,height:232));host.frame=NSRect(x:0,y:0,width:width,height:232)
   host.layoutSubtreeIfNeeded();try await Task.sleep(nanoseconds:30_000_000);host.layoutSubtreeIfNeeded()
   let rep=host.bitmapImageRepForCachingDisplay(in:host.bounds)!
   host.cacheDisplay(in:host.bounds,to:rep)
   let color=rep.colorAt(x:rep.pixelsWide*20/width,y:rep.pixelsHigh/2)!.usingColorSpace(.deviceRGB)!
   XCTAssertEqual(color.blueComponent>0.6 && color.greenComponent>0.55,true,"LCD must remain light blue in every state and size")
   try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"/private/tmp/FusionLab-LCD-\(name).png"))
  }
 }
}
