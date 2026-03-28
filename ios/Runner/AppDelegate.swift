import Flutter
import UIKit
import UserNotifications
import AVFoundation
import Network
import Darwin
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
  private let deviceStatusCollector = DeviceStatusCollector()
  /// App Group（用于 App 与 Widget 共享最新 MQTT 数据）
  private let appGroupId = "group.com.example.galaxyIos"
  private let sharedTopicKey = "latest_topic"
  private let sharedPayloadKey = "latest_payload"
  private let sharedUpdatedAtKey = "latest_updated_at"
  private let quickWidgetKind = "GalaxyQuickOpenWidget"
  private var clipboardMonitorTimer: Timer?
  private var clipboardLastSeenText: String?
  private var clipboardMonitorEnabled = false
  private var clipboardNotifyEnabled = true
  private var clipboardLiveActivityEnabled = false
  private var shouldKeepRunningInBackground: Bool {
    isKeepAliveEnabled || clipboardMonitorEnabled
  }
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
      case "setClipboardMonitorEnabled":
        self.setClipboardMonitorEnabled(call.arguments, result: result)
      case "getDeviceStatusSnapshot":
        result(self.deviceStatusCollector.snapshot())
      case "installIpaViaTrollStore":
        self.installIpaViaTrollStore(call.arguments, result: result)
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
    nativeLog("App 进入后台，保活开关: \(isKeepAliveEnabled)，剪贴板监听: \(clipboardMonitorEnabled)")
    refreshBackgroundAudioState(reason: "进入后台")
  }

  func handleEnterForeground() {
    nativeLog("App 回到前台")
    refreshBackgroundAudioState(reason: "回到前台")
  }

  // MARK: - Keep Alive Control

  private func enableKeepAlive() {
    isKeepAliveEnabled = true
    configureAudioSession()
    nativeLog("✅ 保活已启用")
    refreshBackgroundAudioState(reason: "启用保活")
  }

  private func disableKeepAlive() {
    isKeepAliveEnabled = false
    nativeLog("❌ 保活已禁用")
    refreshBackgroundAudioState(reason: "禁用保活")
  }

  private func refreshBackgroundAudioState(reason: String) {
    let appState = UIApplication.shared.applicationState
    if appState == .background {
      if shouldKeepRunningInBackground {
        startSilentAudio()
        nativeLog("后台保活已开启（原因: \(reason)）")
      } else {
        stopSilentAudio()
        nativeLog("后台保活未开启（原因: \(reason)）")
      }
      return
    }

    // 前台/非后台状态下不需要静音保活，确保及时释放
    if audioPlayer != nil {
      stopSilentAudio()
      nativeLog("当前非后台，已停止静音保活（原因: \(reason)）")
    }
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
    let updatedAt = ((map["updatedAt"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)) ?? Self.timeFormatter.string(from: Date())
    let enableLiveActivity = map["enableLiveActivity"] as? Bool ?? false

    let limitedPayload = String(payload.prefix(160))
    saveLatestMessageToSharedStore(topic: topic, payload: limitedPayload, updatedAt: updatedAt)
    reloadQuickWidget()

    guard enableLiveActivity else {
      result("已更新小组件（灵动岛已关闭）")
      return
    }

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

  // MARK: - Clipboard Monitor

  private func setClipboardMonitorEnabled(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let map = arguments as? [String: Any] else {
      result("参数格式错误")
      return
    }

    clipboardMonitorEnabled = map["enabled"] as? Bool ?? false
    clipboardNotifyEnabled = map["notifyOnClipboardChange"] as? Bool ?? true
    clipboardLiveActivityEnabled = map["enableLiveActivity"] as? Bool ?? false

    if clipboardMonitorEnabled {
      startClipboardMonitor()
      refreshBackgroundAudioState(reason: "开启剪贴板监听")
      result("剪贴板监听已开启")
    } else {
      stopClipboardMonitor()
      refreshBackgroundAudioState(reason: "关闭剪贴板监听")
      result("剪贴板监听已关闭")
    }
  }

  private func startClipboardMonitor() {
    guard clipboardMonitorTimer == nil else { return }
    clipboardLastSeenText = UIPasteboard.general.string
    clipboardMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
      self?.pollClipboardIfNeeded()
    }
    RunLoop.main.add(clipboardMonitorTimer!, forMode: .common)
    nativeLog("剪贴板监听定时器已启动")
  }

  private func stopClipboardMonitor() {
    clipboardMonitorTimer?.invalidate()
    clipboardMonitorTimer = nil
    nativeLog("剪贴板监听定时器已停止")
  }

  private func pollClipboardIfNeeded() {
    guard clipboardMonitorEnabled else { return }
    let currentText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let currentText, !currentText.isEmpty else { return }
    guard currentText != clipboardLastSeenText else { return }
    clipboardLastSeenText = currentText

    let preview = String(currentText.prefix(160))
    let updatedAt = Self.timeFormatter.string(from: Date())
    saveLatestMessageToSharedStore(topic: "clipboard/new", payload: preview, updatedAt: updatedAt)
    reloadQuickWidget()

    if clipboardNotifyEnabled {
      sendClipboardLocalNotification(content: preview)
    }

    guard clipboardLiveActivityEnabled else {
      nativeLog("剪贴板新内容已捕获（灵动岛关闭）")
      return
    }

    upsertMqttLiveActivity(topic: "clipboard/new", payload: preview, updatedAt: updatedAt) { _ in }
  }

  private func sendClipboardLocalNotification(content: String) {
    guard #available(iOS 10.0, *) else { return }
    let notificationContent = UNMutableNotificationContent()
    notificationContent.title = "检测到新复制内容"
    notificationContent.body = content
    notificationContent.sound = .default

    let request = UNNotificationRequest(
      identifier: "clipboard_\(Int(Date().timeIntervalSince1970))",
      content: notificationContent,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  // MARK: - TrollStore Install

  private func installIpaViaTrollStore(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let map = arguments as? [String: Any] else {
      result("参数格式错误")
      return
    }

    let ipaUrl = (map["ipaUrl"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !ipaUrl.isEmpty else {
      result("IPA 下载地址为空")
      return
    }

    guard let encodedIpaUrl = ipaUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      result("IPA 下载地址无效")
      return
    }

    let probeUrls = [
      URL(string: "trollstore://"),
      URL(string: "apple-magnifier://")
    ].compactMap { $0 }

    let installUrls = [
      URL(string: "trollstore://install?url=\(encodedIpaUrl)"),
      URL(string: "apple-magnifier://install?url=\(encodedIpaUrl)")
    ].compactMap { $0 }

    guard !probeUrls.isEmpty, !installUrls.isEmpty else {
      result("IPA 下载地址无效")
      return
    }

    DispatchQueue.main.async {
      let app = UIApplication.shared
      let isTrollStoreDetected = probeUrls.contains { app.canOpenURL($0) }

      guard isTrollStoreDetected else {
        result("未检测到 TrollStore，请先安装 TrollStore")
        return
      }

      self.openTrollStoreInstallUrl(installUrls, index: 0, result: result)
    }
  }

  private func openTrollStoreInstallUrl(
    _ urls: [URL],
    index: Int,
    result: @escaping FlutterResult
  ) {
    guard index < urls.count else {
      result("检测到 TrollStore，但唤起安装失败")
      return
    }

    UIApplication.shared.open(urls[index], options: [:]) { success in
      if success {
        result("已交给 TrollStore 下载并安装")
      } else {
        self.openTrollStoreInstallUrl(urls, index: index + 1, result: result)
      }
    }
  }

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

final class DeviceStatusCollector {
  private let pathMonitor = NWPathMonitor()
  private let pathQueue = DispatchQueue(label: "com.galaxy.device_status.path")

  private var networkConnected = false
  private var networkType = "未知网络"

  private var lastRxBytes: UInt64?
  private var lastTxBytes: UInt64?
  private var lastSampleTime: TimeInterval?

  init() {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      self.networkConnected = path.status == .satisfied
      if path.usesInterfaceType(.wifi) {
        self.networkType = "WiFi"
      } else if path.usesInterfaceType(.cellular) {
        self.networkType = "蜂窝网络"
      } else if path.usesInterfaceType(.wiredEthernet) {
        self.networkType = "有线网络"
      } else {
        self.networkType = "网络"
      }
    }
    pathMonitor.start(queue: pathQueue)
  }

  func snapshot() -> [String: Any] {
    UIDevice.current.isBatteryMonitoringEnabled = true

    let now = Date()
    let nowTs = now.timeIntervalSince1970
    let uptime = ProcessInfo.processInfo.systemUptime
    let bootAt = Date(timeInterval: -uptime, since: now)

    let memoryTotalBytes = Int64(ProcessInfo.processInfo.physicalMemory)
    let memoryUsedBytes = currentAppMemoryUsageBytes()
    let cpuUsagePercent = currentProcessCpuUsagePercent()

    let storageInfo = fetchStorageBytes()
    let storageTotalBytes = storageInfo.total
    let storageUsedBytes: Int64? = {
      guard let total = storageInfo.total, let free = storageInfo.free else {
        return nil
      }
      return max(total - free, 0)
    }()

    let totals = fetchNetworkTotals()
    let speed = calculateSpeed(nowTs: nowTs, totals: totals)

    let batteryLevelPercent: Double? = {
      let level = UIDevice.current.batteryLevel
      return level < 0 ? nil : Double(level * 100)
    }()

    let snapshot: [String: Any?] = [
      "deviceName": UIDevice.current.name,
      "systemVersion": UIDevice.current.systemVersion,
      "modelIdentifier": modelIdentifier(),
      "chip": "Apple SoC (\(ProcessInfo.processInfo.processorCount) cores)",
      "storageTotalBytes": storageTotalBytes,
      "storageUsedBytes": storageUsedBytes,
      "memoryTotalBytes": memoryTotalBytes,
      "memoryUsedBytes": memoryUsedBytes,
      "cpuUsagePercent": cpuUsagePercent,
      "batteryLevelPercent": batteryLevelPercent,
      "batteryState": batteryStateString(UIDevice.current.batteryState),
      "networkConnected": networkConnected,
      "networkType": networkType,
      "downloadSpeedBytesPerSec": speed.down,
      "uploadSpeedBytesPerSec": speed.up,
      "downloadTotalBytes": Double(totals.rx),
      "uploadTotalBytes": Double(totals.tx),
      "uptimeSeconds": Int(uptime),
      "bootAt": ISO8601DateFormatter().string(from: bootAt),
    ]

    var result: [String: Any] = [:]
    for (key, value) in snapshot {
      if let value {
        result[key] = value
      }
    }
    return result
  }

  private func modelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
  }

  private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
    switch state {
    case .charging:
      return "charging"
    case .full:
      return "full"
    case .unplugged:
      return "unplugged"
    case .unknown:
      return "unknown"
    @unknown default:
      return "unknown"
    }
  }

  private func fetchStorageBytes() -> (total: Int64?, free: Int64?) {
    do {
      let attrs = try FileManager.default.attributesOfFileSystem(
        forPath: NSHomeDirectory()
      )
      let total = (attrs[.systemSize] as? NSNumber)?.int64Value
      let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value
      return (total, free)
    } catch {
      return (nil, nil)
    }
  }

  private func fetchNetworkTotals() -> (rx: UInt64, tx: UInt64) {
    var addressPointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addressPointer) == 0,
          let firstAddress = addressPointer else {
      return (0, 0)
    }
    defer { freeifaddrs(addressPointer) }

    var rx: UInt64 = 0
    var tx: UInt64 = 0

    var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
    while let current = cursor {
      let flags = Int32(current.pointee.ifa_flags)
      let isUp = (flags & IFF_UP) != 0
      let isRunning = (flags & IFF_RUNNING) != 0

      if isUp,
         isRunning,
         let cName = current.pointee.ifa_name,
         let data = current.pointee.ifa_data {
        let name = String(cString: cName)
        if name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
          let networkData = data.assumingMemoryBound(to: if_data.self).pointee
          rx += UInt64(networkData.ifi_ibytes)
          tx += UInt64(networkData.ifi_obytes)
        }
      }

      cursor = current.pointee.ifa_next
    }

    return (rx, tx)
  }

  private func calculateSpeed(
    nowTs: TimeInterval,
    totals: (rx: UInt64, tx: UInt64)
  ) -> (down: Double, up: Double) {
    guard let lastRxBytes,
          let lastTxBytes,
          let lastSampleTime,
          nowTs > lastSampleTime else {
      self.lastRxBytes = totals.rx
      self.lastTxBytes = totals.tx
      self.lastSampleTime = nowTs
      return (0, 0)
    }

    let deltaSec = nowTs - lastSampleTime
    let down = Double(max(Int64(totals.rx) - Int64(lastRxBytes), 0)) / deltaSec
    let up = Double(max(Int64(totals.tx) - Int64(lastTxBytes), 0)) / deltaSec

    self.lastRxBytes = totals.rx
    self.lastTxBytes = totals.tx
    self.lastSampleTime = nowTs

    return (down, up)
  }

  private func currentAppMemoryUsageBytes() -> Int64? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

    let kern: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          $0,
          &count
        )
      }
    }

    guard kern == KERN_SUCCESS else { return nil }
    return Int64(info.resident_size)
  }

  private func currentProcessCpuUsagePercent() -> Double? {
    var threadList: thread_act_array_t?
    var threadCount: mach_msg_type_number_t = 0

    guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
          let threadList else {
      return nil
    }

    defer {
      let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
      vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), size)
    }

    var totalCpu: Double = 0

    for index in 0..<Int(threadCount) {
      var info = thread_basic_info()
      var count = mach_msg_type_number_t(THREAD_INFO_MAX)

      let kr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
          thread_info(
            threadList[index],
            thread_flavor_t(THREAD_BASIC_INFO),
            $0,
            &count
          )
        }
      }

      if kr != KERN_SUCCESS { continue }
      if (info.flags & TH_FLAGS_IDLE) == 0 {
        totalCpu += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
      }
    }

    return totalCpu
  }
}
