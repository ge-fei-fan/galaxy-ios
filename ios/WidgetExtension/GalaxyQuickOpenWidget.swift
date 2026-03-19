import WidgetKit
import SwiftUI

struct GalaxyQuickOpenEntry: TimelineEntry {
  let date: Date
}

struct GalaxyQuickOpenProvider: TimelineProvider {
  func placeholder(in context: Context) -> GalaxyQuickOpenEntry {
    GalaxyQuickOpenEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (GalaxyQuickOpenEntry) -> Void) {
    completion(GalaxyQuickOpenEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GalaxyQuickOpenEntry>) -> Void) {
    let entry = GalaxyQuickOpenEntry(date: Date())
    // 本示例是快捷入口组件，不依赖频繁刷新。
    let timeline = Timeline(entries: [entry], policy: .never)
    completion(timeline)
  }
}

struct GalaxyQuickOpenWidgetView: View {
  var entry: GalaxyQuickOpenProvider.Entry

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.21, green: 0.34, blue: 0.95), Color(red: 0.47, green: 0.26, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      VStack(alignment: .leading, spacing: 8) {
        Image(systemName: "paperplane.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundColor(.white)

        Text("Galaxy MQTT")
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)

        Text("点击快速打开 App")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.92))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .padding(14)
    }
    .widgetURL(URL(string: "galaxyios://open?tab=home"))
  }
}

struct GalaxyQuickOpenWidget: Widget {
  let kind: String = "GalaxyQuickOpenWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GalaxyQuickOpenProvider()) { entry in
      GalaxyQuickOpenWidgetView(entry: entry)
    }
    .configurationDisplayName("Galaxy 快捷入口")
    .description("点击后打开 Galaxy App。")
    .supportedFamilies([.systemSmall])
  }
}
