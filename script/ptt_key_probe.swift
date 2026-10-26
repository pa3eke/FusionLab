// Focus-independent keypad-0 diagnostic. No microphone, vocoder or network.
import AppKit
import Darwin

@main struct PTTKeyProbe {
 static func main(){
  setbuf(stdout,nil)
  let app=NSApplication.shared
  app.setActivationPolicy(.prohibited)
  let key=GlobalPTTKey()
  var events=[Bool]()
  key.onKey={pressed in
   events.append(pressed);print(pressed ? "KEY DOWN":"KEY UP")
   if events == [true,false] {key.setActive(false);print("PASS: global keypad 0 pressed and released");exit(0)}
  }
  key.setActive(true)
  guard key.registered else{print("FAIL: keypad 0 unavailable");exit(1)}
  print("READY: press numeric keypad 0 in another app; no transmission")
  DispatchQueue.main.asyncAfter(deadline:.now()+30){print("FAIL: no complete key press/release within 30 seconds");exit(1)}
  app.run()
 }
}
