import Flutter
import UIKit
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  
  private var audioPlayer: AVAudioPlayer?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var keepAliveTimer: Timer?
  private var isKeepAliveEnabled = false
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // 设置 MethodChannel
    setupMethodChannel()
    
    // 配置音频会话
    configureAudioSession()
    
    // 监听 App 生命周期
    if #available(iOS 13.0, *) {
      NotificationCenter.default.addObserver(
        self, selector: #selector(appDidEnterBackground),
        name: UIScene.didEnterBackgroundNotification, object: nil
      )
      NotificationCenter.default.addObserver(
        self, selector: #selector(appWillEnterForeground),
        name: UIScene.willEnterForegroundNotification, object: nil
      )
    } else {
      NotificationCenter.default.addObserver(
        self, selector: #selector(appDidEnterBackground),
        name: UIApplication.didEnterBackgroundNotification, object: nil
      )
      NotificationCenter.default.addObserver(
        self, selector: #selector(appWillEnterForeground),
        name: UIApplication.willEnterForegroundNotification, object: nil
      )
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  // MARK: - MethodChannel
  
  private func setupMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "com.galaxy/background_keep_alive",
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "enableKeepAlive":
        self?.enableKeepAlive()
        result(true)
      case "disableKeepAlive":
        self?.disableKeepAlive()
        result(true)
      case "isKeepAliveActive":
        result(self?.isKeepAliveEnabled ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // MARK: - Audio Session Configuration
  
  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      // 使用 playback 类别，mixWithOthers 不影响其他 App 的音频
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      try session.setActive(true)
    } catch {
      NSLog("[KeepAlive] 音频会话配置失败: \(error)")
    }
  }
  
  // MARK: - Keep Alive Control
  
  private func enableKeepAlive() {
    isKeepAliveEnabled = true
    NSLog("[KeepAlive] 后台保活已启用")
  }
  
  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    stopSilentAudio()
    endBackgroundTask()
    NSLog("[KeepAlive] 后台保活已禁用")
  }
  
  // MARK: - Background Task
  
  private func beginBackgroundTask() {
    guard backgroundTask == .invalid else { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MQTTKeepAlive") { [weak self] in
      // 系统即将结束后台任务，重新申请
      self?.endBackgroundTask()
      // 尝试重新申请后台时间
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self?.beginBackgroundTask()
      }
    }
    NSLog("[KeepAlive] 后台任务已开始, id=\(backgroundTask.rawValue)")
  }
  
  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
  
  // MARK: - Silent Audio
  
  private func startSilentAudio() {
    guard audioPlayer == nil else { return }
    
    // 生成一个极短的静音音频数据（PCM 16-bit, mono, 44100Hz, 1秒）
    let sampleRate: Double = 44100
    let duration: Double = 1.0
    let numSamples = Int(sampleRate * duration)
    
    // 构建 WAV 文件数据
    var wavData = Data()
    let dataSize = numSamples * 2 // 16-bit = 2 bytes per sample
    let fileSize = 36 + dataSize
    
    // RIFF header
    wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
    wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
    
    // fmt chunk
    wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM format
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // mono
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate)).littleEndian) { Array($0) }) // sample rate
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate) * 2).littleEndian) { Array($0) }) // byte rate
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) }) // block align
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample
    
    // data chunk
    wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
    
    // 静音数据（全部为 0）
    wavData.append(Data(count: dataSize))
    
    do {
      audioPlayer = try AVAudioPlayer(data: wavData)
      audioPlayer?.numberOfLoops = -1 // 无限循环
      audioPlayer?.volume = 0.0 // 静音
      audioPlayer?.play()
      NSLog("[KeepAlive] 静音音频已开始播放")
    } catch {
      NSLog("[KeepAlive] 静音音频播放失败: \(error)")
    }
  }
  
  private func stopSilentAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    NSLog("[KeepAlive] 静音音频已停止")
  }
  
  // MARK: - App Lifecycle
  
  @objc private func appDidEnterBackground() {
    NSLog("[KeepAlive] App 进入后台")
    guard isKeepAliveEnabled else {
      NSLog("[KeepAlive] 保活未启用，不执行后台保活")
      return
    }
    beginBackgroundTask()
    startSilentAudio()
    
    // 启动一个定时器，定期续期后台任务
    keepAliveTimer?.invalidate()
    keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
      NSLog("[KeepAlive] 续期后台任务")
      self?.endBackgroundTask()
      self?.beginBackgroundTask()
    }
  }
  
  @objc private func appWillEnterForeground() {
    NSLog("[KeepAlive] App 回到前台")
    keepAliveTimer?.invalidate()
    keepAliveTimer = nil
    stopSilentAudio()
    endBackgroundTask()
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
