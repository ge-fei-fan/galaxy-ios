import Flutter
import UIKit
import AVFoundation

class SceneDelegate: FlutterSceneDelegate {
  private var audioPlayer: AVAudioPlayer?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var keepAliveTimer: Timer?
  private var isKeepAliveEnabled = false
  private var methodChannel: FlutterMethodChannel?
  
  private func nativeLog(_ message: String) {
    NSLog(message)
    methodChannel?.invokeMethod("log", arguments: message)
  }

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    
    // 获取 FlutterViewController
    guard let windowScene = scene as? UIWindowScene,
          let window = windowScene.windows.first,
          let controller = window.rootViewController as? FlutterViewController else {
      NSLog("[KeepAlive] 无法获取 FlutterViewController")
      return
    }
    
    // 设置 MethodChannel
    let channel = FlutterMethodChannel(
      name: "com.galaxy/background_keep_alive",
      binaryMessenger: controller.binaryMessenger
    )
    self.methodChannel = channel
    
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
    
    configureAudioSession()
    nativeLog("[KeepAlive] SceneDelegate: MethodChannel 绑定成功")
  }

  // MARK: - App Lifecycle via Scene
  
  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    nativeLog("[KeepAlive] Scene 进入后台, 启用保活: \(isKeepAliveEnabled)")
    
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

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    nativeLog("[KeepAlive] Scene 回到前台")
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
    nativeLog("[KeepAlive] 后台保活已启用")
  }
  
  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    stopSilentAudio()
    endBackgroundTask()
    nativeLog("[KeepAlive] 后台保活已禁用")
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
}
