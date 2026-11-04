import Foundation

// MacDV's source-owned PTT request model, expressed at FusionLab's existing
// start/stop boundary. A release removes only its own request. Per-source
// PTTKeyState retains the physical latch through timeout and repeated reports.
struct PTTRequests {
 private var states:[String:PTTKeyState]=[:]
 private(set) var sources=Set<String>()
 var hasHeld:Bool {states.values.contains{$0.held}}
 func held(_ source:String)->Bool {states[source]?.held == true}
 mutating func event(source:String,pressed:Bool,mode:PTTKeyMode,canStart:Bool,engaged:Bool)->PTTKeyState.Action {
  var state=states[source] ?? PTTKeyState()
  let wasEmpty=sources.isEmpty
  switch state.event(pressed:pressed,mode:mode,canStart:canStart,engaged:sources.contains(source)) {
  case .start:sources.insert(source)
  case .stop:sources.remove(source)
  case .none:break
  }
  states[source]=state
  if wasEmpty,!sources.isEmpty,!engaged {return .start}
  if !wasEmpty,sources.isEmpty,engaged {return .stop}
  return .none
 }
 mutating func release(prefix:String,engaged:Bool)->PTTKeyState.Action {
  let hadRequests = !sources.isEmpty
  for source in Array(states.keys) where source.hasPrefix(prefix) {states.removeValue(forKey:source);sources.remove(source)}
  return hadRequests && sources.isEmpty && engaged ? .stop:.none
 }
 mutating func transmissionEnded(){
  sources=[]
  for source in Array(states.keys) {states[source]?.transmissionEnded()}
 }
}
