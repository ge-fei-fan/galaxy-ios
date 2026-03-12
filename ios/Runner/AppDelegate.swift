import Flutter
import UIKit
import UserNotifications
import AVFoundation
import PushKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  // MARK: - Properties

  private var audioPlayer: AVAudioPlayer?
  private var isKeepAliveEnabled = false
  private var methodChannel: FlutterMethodChannel?

  // MARK: - Native Log

  private func nativeLog(_ message: String) {
    NSLog(message)
    methodChannel?.invokeMethod("log", arguments: message)
  }

  // MARK: - MethodChannel Binding（由 SceneDelegate 在 Scene 启动后调用）

  func bindMethodChannel(_ channel: FlutterMethodChannel) {
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      self.nativeLog("[KeepAlive] 收到 Flutter 端调用: \(call.method)")
      switch call.method {
      case "enableKeepAlive":
        self.enableKeepAlive()
        result(true)
      case "disableKeepAlive":
        self.disableKeepAlive()
        result(true)
      case "isKeepAliveActive":
        result(self.isKeepAliveEnabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // 配置音频会话
    configureAudioSession()
    // 注册 PushKit VoIP 推送（用于被杀死后唤醒重连）
    registerVoIPPush()
    nativeLog("[KeepAlive] MethodChannel 绑定完成 ✅")
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

  // MARK: - Scene 生命周期入口（由 SceneDelegate 转发）
  // iOS 13+ Scene 架构下 AppDelegate 的 background/foreground 不再被系统回调，
  // 由 SceneDelegate 的 sceneDidEnterBackground / sceneWillEnterForeground 转发。

  func handleEnterBackground() {
    nativeLog("[KeepAlive] App 进入后台, 保活已启用: \(isKeepAliveEnabled)")
    guard isKeepAliveEnabled else {
      nativeLog("[KeepAlive] 保活未启用，跳过")
      return
    }
    startSilentAudio()
  }

  func handleEnterForeground() {
    nativeLog("[KeepAlive] App 回到前台")
    stopSilentAudio()
  }

  // MARK: - Keep Alive Control

  private func enableKeepAlive() {
    isKeepAliveEnabled = true
    configureAudioSession()
    nativeLog("[KeepAlive] ✅ 保活已启用")
  }

  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    stopSilentAudio()
    nativeLog("[KeepAlive] ❌ 保活已禁用")
  }

  // MARK: - Audio Session

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      nativeLog("[KeepAlive] 音频会话配置成功（playback + mixWithOthers）")
    } catch {
      nativeLog("[KeepAlive] 音频会话配置失败: \(error)")
    }
  }

  // MARK: - Silent Audio
  // 使用 Bundle 内预置的 silence.aac 文件，比内存动态 WAV 更稳定。

  private func startSilentAudio() {
    guard audioPlayer == nil else {
      nativeLog("[KeepAlive] 静音音频已在播放中，跳过重复启动")
      return
    }
    guard let url = Bundle.main.url(forResource: "silence", withExtension: "aac") else {
      nativeLog("[KeepAlive] ❌ 未找到 silence.aac，请确保文件已添加到 Xcode Bundle Resources")
      return
    }
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.numberOfLoops = -1  // 无限循环
      audioPlayer?.volume = 0.0
      let success = audioPlayer?.play() ?? false
      nativeLog("[KeepAlive] 静音音频启动: \(success ? "✅ 成功" : "❌ 失败")")
    } catch {
      nativeLog("[KeepAlive] 静音音频异常: \(error)")
    }
  }

  private func stopSilentAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    nativeLog("[KeepAlive] 静音音频已停止")
  }

  // MARK: - PushKit VoIP
  // VoIP 推送可以在 App 被系统完全杀死后将其唤醒，是 iOS 后台保活的最强手段。
  // 收到 VoIP 推送后，App 有约 30 秒时间在后台执行代码（如重连 MQTT）。

  private func registerVoIPPush() {
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    nativeLog("[KeepAlive] PushKit VoIP 已注册，等待系统下发 VoIP 推送 Token")
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

// MARK: - PKPushRegistryDelegate

extension AppDelegate: PKPushRegistryDelegate {

  /// 系统颁发 VoIP Token（每次 App 安装或 Token 轮换时回调）
  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let tokenData = pushCredentials.token
    let token = tokenData.map { String(format: "%02x", $0) }.joined()
    nativeLog("[KeepAlive] VoIP Push Token: \(token)")
    // 可将 token 上报给服务端，服务端通过 APNs VoIP 通道推送唤醒消息
    methodChannel?.invokeMethod("voipToken", arguments: token)
  }

  /// 收到 VoIP 推送（App 被杀死也会唤醒）
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    nativeLog("[KeepAlive] 收到 VoIP 推送，唤醒 App 重连 MQTT")
    // 通知 Flutter 层重新连接 MQTT
    methodChannel?.invokeMethod("voipWakeup", arguments: payload.dictionaryPayload)
    completion()
  }
}
