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
  private var methodChannel: FlutterMethodChannel?
  
  private func nativeLog(_ message: String) {
    NSLog(message)
    methodChannel?.invokeMethod("log", arguments: message)
  }
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // 延迟绑定 MethodChannel，确保 Flutter 引擎和 ViewController 已经完全初始化
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        if let controller = self.window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "com.galaxy/background_keep_alive",
                binaryMessenger: controller.binaryMessenger
            )
            self.methodChannel = channel
            
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
            
            self.configureAudioSession()
            self.nativeLog("[KeepAlive] AppDelegate: MethodChannel 通信绑定成功 ✅")
        } else {
            NSLog("[KeepAlive] AppDelegate: 未找到 FlutterViewController，通道绑定失败")
        }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - App Lifecycle
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    nativeLog("[KeepAlive] App 进入后台, 启用保活: \(isKeepAliveEnabled)")
    
    guard isKeepAliveEnabled else {
      nativeLog("[KeepAlive] 保活未启用，不执行后台保活")
      return
    }
    
    beginBackgroundTask()
    startSilentAudio()
    
    var tickCount = 0
    keepAliveTimer?.invalidate()
    keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      tickCount += 2
      let timeRemaining = UIApplication.shared.backgroundTimeRemaining
      self?.nativeLog("[KeepAlive] 存活 tick \(tickCount)s, 后台可用时间: \(timeRemaining)s")
      
      if tickCount % 20 == 0 {
        self?.nativeLog("[KeepAlive] 准备重置后台任务")
        self?.endBackgroundTask()
        self?.beginBackgroundTask()
      }
    }
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
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
      nativeLog("[KeepAlive] 音频会话配置成功")
    } catch {
      nativeLog("[KeepAlive] 音频会话配置失败: \(error)")
    }
  }
  
  // MARK: - Keep Alive Control
  
  private func enableKeepAlive() {
    isKeepAliveEnabled = true
    nativeLog("=========================================")
    nativeLog("[KeepAlive] ✅ 开启后台保活功能成功")
    nativeLog("=========================================")
  }
  
  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    stopSilentAudio()
    endBackgroundTask()
    nativeLog("=========================================")
    nativeLog("[KeepAlive] ❌ 禁用后台保活功能")
    nativeLog("=========================================")
  }
  
  // MARK: - Background Task
  
  private func beginBackgroundTask() {
    guard backgroundTask == .invalid else { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MQTTKeepAlive") { [weak self] in
      self?.nativeLog("[KeepAlive] 系统即将结束当前后台任务 (id=\(self?.backgroundTask.rawValue ?? 0))")
      self?.endBackgroundTask()
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self?.nativeLog("[KeepAlive] 尝试重新开始后台任务...")
        self?.beginBackgroundTask()
      }
    }
    nativeLog("[KeepAlive] 后台任务已开始, id=\(backgroundTask.rawValue), 剩余时间: \(UIApplication.shared.backgroundTimeRemaining)s")
  }
  
  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
  
  // MARK: - Silent Audio
  
  private func startSilentAudio() {
    guard audioPlayer == nil else { return }
    
    let sampleRate: Double = 44100
    let duration: Double = 1.0
    let numSamples = Int(sampleRate * duration)
    
    var wavData = Data()
    let dataSize = numSamples * 2
    let fileSize = 36 + dataSize
    
    wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
    wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
    
    wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate)).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate) * 2).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
    wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
    
    wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
    wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
    
    wavData.append(Data(count: dataSize))
    
    do {
      audioPlayer = try AVAudioPlayer(data: wavData)
      audioPlayer?.numberOfLoops = -1
      audioPlayer?.volume = 0.0
      let playSuccess = audioPlayer?.play() ?? false
      nativeLog("[KeepAlive] 静音音频尝试播放, 结果: \(playSuccess)")
    } catch {
      nativeLog("[KeepAlive] 静音音频播放异常: \(error)")
    }
  }
  
  private func stopSilentAudio() {
    audioPlayer?.stop()
    audioPlayer = nil
    nativeLog("[KeepAlive] 静音音频已停止")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
