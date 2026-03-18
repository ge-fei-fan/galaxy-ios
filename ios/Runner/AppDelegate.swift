import Flutter
import UIKit
import UserNotifications
import AVFoundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct GalaxyDemoAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var statusText: String
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
#if canImport(ActivityKit)
  /// 当前演示 Live Activity
  private var demoActivity: Any?
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

  // MARK: - Dynamic Island / Live Activity Demo

  private func startDynamicIslandDemo(result: @escaping FlutterResult) {
#if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else {
      let msg = "当前系统低于 iOS 16.1，无法启动 Live Activity"
      nativeLog(msg)
      result(msg)
      return
    }

    if demoActivity != nil {
      let msg = "灵动岛演示已在运行中"
      nativeLog(msg)
      result(msg)
      return
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      let msg = "系统未开启 Live Activity（请检查系统设置）"
      nativeLog(msg)
      result(msg)
      return
    }

    let attributes = GalaxyDemoAttributes(title: "Galaxy Demo")
    let state = GalaxyDemoAttributes.ContentState(statusText: "正在测试灵动岛")

    do {
      let activity: Activity<GalaxyDemoAttributes>
      if #available(iOS 16.2, *) {
        activity = try Activity<GalaxyDemoAttributes>.request(
          attributes: attributes,
          content: ActivityContent(state: state, staleDate: nil),
          pushType: nil
        )
      } else {
        activity = try Activity<GalaxyDemoAttributes>.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
      }
      demoActivity = activity
      let msg = "已启动 Live Activity（支持机型会显示在灵动岛/锁屏）"
      nativeLog("\(msg)，id=\(activity.id)")
      result(msg)
    } catch {
      let msg = "启动 Live Activity 失败: \(error.localizedDescription)"
      nativeLog(msg)
      result(msg)
    }
#else
    let msg = "当前构建环境不支持 ActivityKit，无法启动 Live Activity"
    nativeLog(msg)
    result(msg)
#endif
  }

  private func stopDynamicIslandDemo(result: @escaping FlutterResult) {
#if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else {
      let msg = "当前系统低于 iOS 16.1，无需结束 Live Activity"
      nativeLog(msg)
      result(msg)
      return
    }

    guard let activity = demoActivity as? Activity<GalaxyDemoAttributes> else {
      let msg = "当前没有运行中的灵动岛演示"
      nativeLog(msg)
      result(msg)
      return
    }

    Task {
      let finalState = GalaxyDemoAttributes.ContentState(statusText: "演示已结束")
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
      self.demoActivity = nil
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
