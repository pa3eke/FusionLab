import AppKit
import SwiftUI
import Darwin

final class ProbePTTKey:PTTKeyRegistration {
 var registered=false,failed=false
 var onKey:((Bool)->Void)?
 func setActive(_ active:Bool){}
}

@main enum ConsoleProbe {
 @MainActor static func main(){
  let app=NSApplication.shared
  app.setActivationPolicy(.prohibited)
  let session=RadioSession(pttKey:ProbePTTKey())
  session.rememberDMRPassword=false
  session.xkeys.settings.enabled=false
  let host=NSHostingView(rootView:ContentView(session:session))
  let window=NSWindow(contentRect:NSRect(x:-5000,y:-5000,width:1120,height:740),styleMask:.borderless,backing:.buffered,defer:false)
  window.isReleasedWhenClosed=false;window.contentView=host;window.orderFront(nil)
  func cpu()->Double {
   var usage=rusage();getrusage(RUSAGE_SELF,&usage)
   return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1_000_000
  }
  DispatchQueue.global().asyncAfter(deadline:.now()+20){print("FAIL: UI probe watchdog");exit(2)}
  Task { @MainActor in
   try await Task.sleep(nanoseconds:200_000_000)
   let began=Date(),startCPU=cpu()
   for i in 0..<120 {
    session.networkFrames+=1;session.voiceFrames+=3;session.pcmFrames+=3
    session.level=Float((i%13)+1)/40;session.microphoneLevel=Float(i%9)/20;session.microphonePeak=Float(i%9)/12
    if i%30==0 {session.station="TEST1 · \(i)"}
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(nanoseconds:20_000_000)
   }
   let elapsed=Date().timeIntervalSince(began),used=cpu()-startCPU
   print(String(format:"Console stress: 120 bursts, wall %.3f s, CPU %.3f s (%.1f%%)",elapsed,used,used/elapsed*100))
   // Render fixtures only: never connect, request microphone or invoke PTT.
   for (name,mode,size) in [("dmr",DigitalMode.dmr,NSSize(width:1120,height:740)),("minimum",.dmr,NSSize(width:940,height:640)),("fusion",.fusion,NSSize(width:1120,height:740)),("nxdn",.nxdn,NSSize(width:1120,height:740)),("wide",.dmr,NSSize(width:1500,height:950))] {
    session.active=false;session.selectMode(mode)
    session.dmr.privateCall=false;session.dmr.destination="204";session.dmr.slot=2;session.dmr.colorCode=1
    session.nxdn.destination="7300";session.host="c4fm.pa7lim.nl";session.port="42000"
    session.station=mode == .fusion ? "PA3EKE/PORTABLE":mode == .nxdn ? "PA3EHA · 4163":"PD1LOI · 2047075"
    session.mode=mode == .dmr ? "DMR · TG 204 · TS2":mode == .nxdn ? "NXDN · TG 7300 · RAN 1":"Fusion DN · V/D2"
    session.ysfStatus="Voorbeeldweergave · geen netwerkverbinding";session.readyToTransmit=true;session.active=true;session.receivingAudio=true;session.level=0.1
    window.setContentSize(size);host.frame=NSRect(origin:.zero,size:size)
    try await Task.sleep(nanoseconds:150_000_000);host.layoutSubtreeIfNeeded()
    let rep=host.bitmapImageRepForCachingDisplay(in:host.bounds)!
    host.cacheDisplay(in:host.bounds,to:rep)
    try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"/private/tmp/FusionLab-console-\(name).png"))
    print("Rendered console fixture: \(name), \(Int(size.width)) × \(Int(size.height))")
   }
   session.active=false
   fflush(stdout);window.contentView=nil;window.close();exit(0)
  }
  app.run()
 }
}
