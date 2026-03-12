import Flutter
import UIKit
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  private var audioPlayer: AVAudioPlayer?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var keepAliveTimer: Timer?
  private var isKeepAliveEnabled = false
  private var methodChannel: FlutterMethodChannel?
  
  private func nativeLog(_ message: String) {
    NSLog(message)
    methodChannel?.invokeMethod("log", arguments: message)
  }

  // 供 SceneDelegate 在 Scene 启动后调用，绑定 MethodChannel
  func bindMethodChannel(_ channel: FlutterMethodChannel) {
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      self.nativeLog("[KeepAlive] 收到 Flutter 端调用方法: \(call.method)")
      switch call.method {
      case "enableKeepAlive":
        self.enableKeepAlive()
        result(true)
      case "disableKeepAlive":
        self.disableKeepAlive()
        result(true)
      case "isKeepAliveActive":
        self.nativeLog("[KeepAlive] 检查保活状态: \(self.isKeepAliveEnabled)")
        result(self.isKeepAliveEnabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    configureAudioSession()
    nativeLog("[KeepAlive] AppDelegate: MethodChannel 绑定完成 ✅")
  }
  
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
  
  // MARK: - 公开生命周期入口（由 SceneDelegate 转发调用）
  // 在 iOS 13+ Scene 架构下，AppDelegate 的 applicationDidEnterBackground /
  // applicationWillEnterForeground 不再被系统调用，改由 SceneDelegate 的
  // sceneDidEnterBackground / sceneWillEnterForeground 转发过来。

  func handleEnterBackground() {
    nativeLog("[KeepAlive] App 进入后台, 保活已启用: \(isKeepAliveEnabled)")
    
    guard isKeepAliveEnabled else {
      nativeLog("[KeepAlive] 保活未启用，不执行后台保活")
      return
    }
    
    // 启动静音音频（核心保活手段）
    startSilentAudio()
    // 申请一段短暂的后台任务作为缓冲（让音频有时间启动）
    beginBackgroundTask()
    
    var tickCount = 0
    keepAliveTimer?.invalidate()
    keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
      tickCount += 5
      let timeRemaining = UIApplication.shared.backgroundTimeRemaining
      self?.nativeLog("[KeepAlive] 后台存活 \(tickCount)s, backgroundTimeRemaining: \(Int(timeRemaining))s")
    }
  }

  func handleEnterForeground() {
    nativeLog("[KeepAlive] App 回到前台")
    keepAliveTimer?.invalidate()
    keepAliveTimer = nil
    stopSilentAudio()
    endBackgroundTask()
  }

  // MARK: - Audio Session Configuration
  
  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      nativeLog("[KeepAlive] 音频会话配置成功（category=playback, mixWithOthers）")
    } catch {
      nativeLog("[KeepAlive] 音频会话配置失败: \(error)")
    }
  }
  
  // MARK: - Keep Alive Control
  
  private func enableKeepAlive() {
    isKeepAliveEnabled = true
    // 确保音频会话处于激活状态
    configureAudioSession()
    nativeLog("=========================================")
    nativeLog("[KeepAlive] ✅ 开启后台保活功能成功")
    nativeLog("=========================================")
  }
  
  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    keepAliveTimer?.invalidate()
    keepAliveTimer = nil
    stopSilentAudio()
    endBackgroundTask()
    nativeLog("=========================================")
    nativeLog("[KeepAlive] ❌ 禁用后台保活功能")
    nativeLog("=========================================")
  }
  
  // MARK: - Background Task
  // 注意：UIBackgroundTask 最长约 30 秒，仅用于进入后台初期的过渡缓冲。
  // 真正的长期后台保活依赖 AVAudioSession playback 持续播放静音音频。

  private func beginBackgroundTask() {
    guard backgroundTask == .invalid else { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MQTTKeepAlive") { [weak self] in
      // expiration handler：系统即将结束本次后台任务，只做清理，不再重新申请
      // （在此回调中重新申请会被系统立即拒绝或过期，属于无效操作）
      self?.nativeLog("[KeepAlive] 后台任务到期 (id=\(self?.backgroundTask.rawValue ?? 0))，依赖静音音频继续保活")
      self?.endBackgroundTask()
    }
    nativeLog("[KeepAlive] 后台任务已开始 id=\(backgroundTask.rawValue), 剩余时间: \(Int(UIApplication.shared.backgroundTimeRemaining))s")
  }
  
  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
  
  // MARK: - Silent Audio
  
  private func startSilentAudio() {
    guard audioPlayer == nil else {
      nativeLog("[KeepAlive] 静音音频已在播放中，跳过重复启动")
      return
    }
    
    let sampleRate: Double = 44100
    let duration: Double = 1.0
    let numSamples = Int(sampleRate * duration)
    
    var wavData = Data()
    let dataSize = numSamples * 2
    let fileSize = 36 + dataSize
    
    // RIFF header
    wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
    wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
    
    // fmt chunk
    wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate)).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate) * 2).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
    
    // data chunk
    wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
    wavData.append(Data(count: dataSize))
    
    do {
      audioPlayer = try AVAudioPlayer(data: wavData)
      audioPlayer?.numberOfLoops = -1  // 无限循环
      audioPlayer?.volume = 0.0
      let playSuccess = audioPlayer?.play() ?? false
      nativeLog("[KeepAlive] 静音音频启动, 结果: \(playSuccess ? "✅ 成功" : "❌ 失败")")
    } catch {
      nativeLog("[KeepAlive] 静音音频播放异常: \(error)")
    }
  }
  
  private func stopSilentAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    nativeLog("[KeepAlive] 静音音频已停止")
  }

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
  }
}
