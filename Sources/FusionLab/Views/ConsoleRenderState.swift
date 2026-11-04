import SwiftUI

// RadioSession publishes protocol counters and audio levels frequently. A
// region keeps an immutable copy of only its displayed inputs so unrelated
// packets cannot invalidate its native controls or layout.
struct ConsoleRenderState:Equatable {
 var values:[AnyHashable]
 var presets:[QuickPreset?]=[]
 var devices:[AudioInputDevice]=[]
}
protocol ConsoleRegionView:View,Equatable {
 var renderState:ConsoleRenderState {get}
}
extension ConsoleRegionView {
 static func ==(lhs:Self,rhs:Self)->Bool {lhs.renderState==rhs.renderState}
}

@dynamicMemberLookup
struct SessionBindings {
 let session:RadioSession
 subscript<Value>(dynamicMember path:ReferenceWritableKeyPath<RadioSession,Value>)->Binding<Value> {
  Binding(get:{session[keyPath:path]},set:{session[keyPath:path]=$0})
 }
}
