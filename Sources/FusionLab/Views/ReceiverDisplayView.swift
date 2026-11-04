import SwiftUI

struct ReceiverDisplayView:ConsoleRegionView {
 @ObservedObject var hosts:YSFHostCatalog
 let session:RadioSession
 let renderState:ConsoleRenderState
 init(session s:RadioSession,hosts:YSFHostCatalog){
  self.hosts=hosts
  session=s
  renderState=ConsoleRenderState(values:[s.selectedMode.rawValue,s.nxdn.host,s.nxdn.port,s.nxdn.destination,s.nxdn.ran,s.nxdn.radioID,s.dmr.destination,s.dmr.privateCall,s.dmr.slot,s.dmr.colorCode,s.dmr.radioID,s.transmitting,s.preparingTransmit,s.drainingTransmit,s.receivingAudio,s.station,s.call,s.host,s.port,s.gateway,s.mode,s.connectionError,s.level,s.active,s.readyToTransmit,s.ysfStatus,s.modeSwitchTarget?.rawValue],presets:s.fusionPresets)
 }
 var body:some View {RadioLCDView(model:RadioLCDPresentation(session:session,reflectorTitle:RadioLCDPresentation.reflectorTitle(host:session.host,port:session.port,hosts:hosts.hosts,presets:session.fusionPresets)))}
}
