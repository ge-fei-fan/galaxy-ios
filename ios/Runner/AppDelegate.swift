import Flutter
import UIKit
import UserNotifications
import AVFoundation
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct GalaxyMqttActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var topic: String
    var payloadPreview: String
    var updatedAt: String
  }

  var title: String
}
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {

  // MARK: - Properties

  /// 静音音频播放器，设为实例属性防止 ARC 提前释放
  private var audioPlayer: AVAudioPlayer?
  /// 保活开关
  private var isKeepAliveEnabled = false
  /// MethodChannel 引用
  private var methodChannel: FlutterMethodChannel?
  /// App Group（用于 App 与 Widget 共享最新 MQTT 数据）
  private let appGroupId = "group.com.example.galaxyIos"
  private let sharedTopicKey = "latest_topic"
  private let sharedPayloadKey = "latest_payload"
  private let sharedUpdatedAtKey = "latest_updated_at"
  private let quickWidgetKind = "GalaxyQuickOpenWidget"
#if canImport(ActivityKit)
  /// 当前 MQTT Live Activity
  private var mqttActivity: Any?
#endif

  // MARK: - Logging

  private func nativeLog(_ message: String) {
    NSLog("[KeepAlive] \(message)")
    methodChannel?.invokeMethod("log", arguments: message)
  }

  // MARK: - MethodChannel Binding（由 SceneDelegate 在 Scene 激活后调用）

  func bindMethodChannel(_ channel: FlutterMethodChannel) {
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self else { return }
      self.nativeLog("收到 Flutter 调用: \(call.method)")
      switch call.method {
      case "enableKeepAlive":
        self.enableKeepAlive()
        result(true)
      case "disableKeepAlive":
        self.disableKeepAlive()
        result(true)
      case "isKeepAliveActive":
        result(self.isKeepAliveEnabled)
      case "startDynamicIslandDemo":
        self.startDynamicIslandDemo(result: result)
      case "stopDynamicIslandDemo":
        self.stopDynamicIslandDemo(result: result)
      case "handleIncomingMqttMessage":
        self.handleIncomingMqttMessage(call.arguments, result: result)
      case "endMqttLiveActivity":
        self.endMqttLiveActivity(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // 配置音频会话
    configureAudioSession()
    nativeLog("MethodChannel 绑定完成 ✅")
  }

  // MARK: - Application Lifecycle

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Scene 生命周期转发（由 SceneDelegate 调用）

  func handleEnterBackground() {
    nativeLog("App 进入后台，保活已启用: \(isKeepAliveEnabled)")
    guard isKeepAliveEnabled else { return }
    startSilentAudio()
  }

  func handleEnterForeground() {
    nativeLog("App 回到前台")
    stopSilentAudio()
  }

  // MARK: - Keep Alive Control

  private func enableKeepAlive() {
    isKeepAliveEnabled = true
    configureAudioSession()
    nativeLog("✅ 保活已启用")
  }

  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    stopSilentAudio()
    nativeLog("❌ 保活已禁用")
  }

  // MARK: - Audio Session

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      // 监听音频中断（电话、其他 App 抢占等），中断结束后自动恢复播放
      NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAudioInterruption(_:)),
        name: AVAudioSession.interruptionNotification,
        object: session
      )
      nativeLog("音频会话配置成功（playback + mixWithOthers）")
    } catch {
      nativeLog("音频会话配置失败: \(error)")
    }
  }

  /// 处理音频中断：电话结束、其他 App 释放音频后自动恢复静音播放
  @objc private func handleAudioInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

    if type == .ended {
      // 中断结束，尝试重新激活音频会话并恢复播放
      let optionValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
      if options.contains(.shouldResume) || optionValue == 0 {
        nativeLog("音频中断结束，恢复静音播放")
        do {
          try AVAudioSession.sharedInstance().setActive(true)
        } catch {
          nativeLog("重新激活音频会话失败: \(error)")
        }
        if isKeepAliveEnabled {
          audioPlayer?.play()
        }
      }
    } else {
      nativeLog("音频中断开始（电话/其他 App）")
    }
  }

  // MARK: - Silent Audio

  private func startSilentAudio() {
    guard audioPlayer == nil else {
      nativeLog("静音音频已在播放中，跳过重复启动")
      return
    }
    guard let url = Bundle.main.url(forResource: "silence", withExtension: "aac") else {
      nativeLog("❌ 未找到 silence.aac，请确保文件已加入 Xcode Bundle Resources")
      return
    }
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.numberOfLoops = -1  // 无限循环
      audioPlayer?.volume = 0.0
      let success = audioPlayer?.play() ?? false
      nativeLog("静音音频启动: \(success ? "✅ 成功" : "❌ 失败")")
    } catch {
      nativeLog("静音音频异常: \(error)")
    }
  }

  private func stopSilentAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    nativeLog("静音音频已停止")
  }

  // MARK: - MQTT -> Widget + Live Activity

  private func handleIncomingMqttMessage(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let map = arguments as? [String: Any] else {
      result("参数格式错误")
      return
    }

    let topic = (map["topic"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let payload = (map["payload"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let updatedAt = (map["updatedAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? Self.timeFormatter.string(from: Date())

    let limitedPayload = String(payload.prefix(160))
    saveLatestMessageToSharedStore(topic: topic, payload: limitedPayload, updatedAt: updatedAt)
    reloadQuickWidget()
    upsertMqttLiveActivity(topic: topic, payload: limitedPayload, updatedAt: updatedAt, result: result)
  }

  private func saveLatestMessageToSharedStore(topic: String, payload: String, updatedAt: String) {
    let defaults = UserDefaults(suiteName: appGroupId) ?? UserDefaults.standard
    defaults.set(topic, forKey: sharedTopicKey)
    defaults.set(payload, forKey: sharedPayloadKey)
    defaults.set(updatedAt, forKey: sharedUpdatedAtKey)
  }

  private func reloadQuickWidget() {
#if canImport(WidgetKit)
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: quickWidgetKind)
    }
#endif
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  // MARK: - Dynamic Island / Live Activity Demo

  private func startDynamicIslandDemo(result: @escaping FlutterResult) {
    let updatedAt = Self.timeFormatter.string(from: Date())
    upsertMqttLiveActivity(topic: "demo/topic", payload: "正在测试灵动岛消息展示", updatedAt: updatedAt, result: result)
  }

  private func stopDynamicIslandDemo(result: @escaping FlutterResult) {
    endMqttLiveActivity(result: result)
  }

  private func endMqttLiveActivity(result: @escaping FlutterResult) {
#if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else {
      let msg = "当前系统低于 iOS 16.1，无需结束 Live Activity"
      nativeLog(msg)
      result(msg)
      return
    }

    guard let activity = mqttActivity as? Activity<GalaxyMqttActivityAttributes> else {
      let msg = "当前没有运行中的灵动岛演示"
      nativeLog(msg)
      result(msg)
      return
    }

    Task {
      let finalState = GalaxyMqttActivityAttributes.ContentState(
        topic: "MQTT",
        payloadPreview: "监听已结束",
        updatedAt: Self.timeFormatter.string(from: Date())
      )
      if #available(iOS 16.2, *) {
        await activity.end(
          ActivityContent(state: finalState, staleDate: nil),
          dismissalPolicy: .immediate
        )
      } else {
        await activity.end(
          using: finalState,
          dismissalPolicy: .immediate
        )
      }
      self.mqttActivity = nil
      let msg = "已结束 Live Activity 演示"
      self.nativeLog(msg)
      result(msg)
    }
#else
    let msg = "当前构建环境不支持 ActivityKit"
    nativeLog(msg)
    result(msg)
#endif
  }

  private func upsertMqttLiveActivity(
    topic: String,
    payload: String,
    updatedAt: String,
    result: @escaping FlutterResult
  ) {
#if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else {
      result("当前系统低于 iOS 16.1，跳过 Live Activity")
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result("系统未开启 Live Activity")
      return
    }

    let safeTopic = topic.isEmpty ? "(无主题)" : String(topic.prefix(64))
    let safePayload = payload.isEmpty ? "(空消息)" : String(payload.prefix(160))
    let state = GalaxyMqttActivityAttributes.ContentState(
      topic: safeTopic,
      payloadPreview: safePayload,
      updatedAt: updatedAt
    )

    if let activity = mqttActivity as? Activity<GalaxyMqttActivityAttributes> {
      Task {
        if #available(iOS 16.2, *) {
          await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
          await activity.update(using: state)
        }
        result("已更新 Live Activity")
      }
      return
    }

    do {
      let attributes = GalaxyMqttActivityAttributes(title: "MQTT 最新消息")
      let activity: Activity<GalaxyMqttActivityAttributes>
      if #available(iOS 16.2, *) {
        activity = try Activity<GalaxyMqttActivityAttributes>.request(
          attributes: attributes,
          content: ActivityContent(state: state, staleDate: nil),
          pushType: nil
        )
      } else {
        activity = try Activity<GalaxyMqttActivityAttributes>.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
      }
      mqttActivity = activity
      nativeLog("已启动 MQTT Live Activity，id=\(activity.id)")
      result("已启动 Live Activity")
    } catch {
      result("启动 Live Activity 失败: \(error.localizedDescription)")
    }
#else
    result("当前构建环境不支持 ActivityKit")
#endif
  }

  // MARK: - UNUserNotificationCenterDelegate

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
  }
}
