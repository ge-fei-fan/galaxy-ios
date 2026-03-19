import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
struct GalaxyMqttActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var topic: String
    var payloadPreview: String
    var updatedAt: String
  }

  var title: String
}
#endif

struct GalaxyQuickOpenEntry: TimelineEntry {
  let date: Date
  let topic: String
  let payload: String
  let updatedAt: String
}

struct GalaxyQuickOpenProvider: TimelineProvider {
  private let appGroupId = "group.com.example.galaxyIos"
  private let topicKey = "latest_topic"
  private let payloadKey = "latest_payload"
  private let updatedAtKey = "latest_updated_at"

  func placeholder(in context: Context) -> GalaxyQuickOpenEntry {
    GalaxyQuickOpenEntry(
      date: Date(),
      topic: "mqtt/demo",
      payload: "等待最新 MQTT 消息...",
      updatedAt: "--:--:--"
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (GalaxyQuickOpenEntry) -> Void) {
    completion(loadLatestEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GalaxyQuickOpenEntry>) -> Void) {
    let entry = loadLatestEntry()
    let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
    let timeline = Timeline(entries: [entry], policy: .after(next))
    completion(timeline)
  }

  private func loadLatestEntry() -> GalaxyQuickOpenEntry {
    let defaults = UserDefaults(suiteName: appGroupId) ?? UserDefaults.standard
    let topic = defaults.string(forKey: topicKey) ?? "mqtt/demo"
    let payload = defaults.string(forKey: payloadKey) ?? "等待最新 MQTT 消息..."
    let updatedAt = defaults.string(forKey: updatedAtKey) ?? "--:--:--"

    return GalaxyQuickOpenEntry(
      date: Date(),
      topic: String(topic.prefix(64)),
      payload: String(payload.prefix(200)),
      updatedAt: updatedAt
    )
  }
}

struct GalaxyQuickOpenWidgetView: View {
  @Environment(\.widgetFamily) var family
  var entry: GalaxyQuickOpenProvider.Entry

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.21, green: 0.34, blue: 0.95), Color(red: 0.47, green: 0.26, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      contentView
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .padding(14)
    }
    .widgetURL(URL(string: "galaxyios://open?tab=mqtt"))
  }

  @ViewBuilder
  private var contentView: some View {
    switch family {
    case .systemSmall:
      smallView
    case .systemMedium:
      mediumView
    case .systemLarge:
      largeView
    default:
      mediumView
    }
  }

  private var smallView: some View {
    VStack(alignment: .leading, spacing: 8) {
      header
      Text(entry.topic)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.95))
        .lineLimit(1)
      Text(entry.payload)
        .font(.system(size: 12, weight: .regular))
        .foregroundColor(.white.opacity(0.9))
        .lineLimit(2)
      footer
    }
  }

  private var mediumView: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      Text(entry.topic)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.white.opacity(0.96))
        .lineLimit(1)
      Text(entry.payload)
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(.white.opacity(0.92))
        .lineLimit(3)
      footer
    }
  }

  private var largeView: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      Text("主题：\(entry.topic)")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white.opacity(0.98))
        .lineLimit(2)
      Text(entry.payload)
        .font(.system(size: 14, weight: .regular))
        .foregroundColor(.white.opacity(0.92))
        .lineLimit(8)
      footer
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: "paperplane.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
      Text("Galaxy MQTT")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.white)
    }
  }

  private var footer: some View {
    Text("更新于 \(entry.updatedAt) · 点击进入 App")
      .font(.system(size: 11, weight: .medium))
      .foregroundColor(.white.opacity(0.82))
      .lineLimit(1)
  }
}

struct GalaxyQuickOpenWidget: Widget {
  let kind: String = "GalaxyQuickOpenWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GalaxyQuickOpenProvider()) { entry in
      GalaxyQuickOpenWidgetView(entry: entry)
    }
    .configurationDisplayName("Galaxy 快捷入口")
    .description("展示最新 MQTT 消息，点击后打开 Galaxy App。")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
struct GalaxyMqttLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: GalaxyMqttActivityAttributes.self) { context in
      ZStack {
        Color.black.opacity(0.9)
        VStack(alignment: .leading, spacing: 6) {
          Text("MQTT 最新消息")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
          Text(context.state.topic)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(1)
          Text(context.state.payloadPreview)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(3)
          Text("更新于 \(context.state.updatedAt)")
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(.white.opacity(0.75))
        }
        .padding(12)
      }
      .activityBackgroundTint(.black)
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text("MQTT")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.updatedAt)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text(context.state.topic)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
            Text(context.state.payloadPreview)
              .font(.system(size: 12, weight: .regular))
              .lineLimit(2)
          }
          .foregroundColor(.white)
        }
      } compactLeading: {
        Image(systemName: "wave.3.right.circle.fill")
          .foregroundColor(.white)
      } compactTrailing: {
        Text("MQTT")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.white)
      } minimal: {
        Image(systemName: "dot.radiowaves.left.and.right")
          .foregroundColor(.white)
      }
      .widgetURL(URL(string: "galaxyios://open?tab=mqtt"))
      .keylineTint(.white)
    }
  }
}
#endif
