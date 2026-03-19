import WidgetKit
import SwiftUI

@main
struct GalaxyWidgetBundle: WidgetBundle {
  var body: some Widget {
    GalaxyQuickOpenWidget()
#if canImport(ActivityKit)
    if #available(iOSApplicationExtension 16.1, *) {
      GalaxyMqttLiveActivityWidget()
    }
#endif
  }
}
