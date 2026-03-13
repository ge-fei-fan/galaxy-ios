import Flutter
import UIKit
import UserNotifications
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {

    // MARK: - Properties

    /// VPN 隧道配置管理器
    private var tunnelManager: NETunnelProviderManager?
    /// 保活开关
    private var isKeepAliveEnabled = false
    /// MethodChannel 引用
    private var methodChannel: FlutterMethodChannel?
    /// VPN 状态观察者
    private var vpnStatusObserver: NSObjectProtocol?

    // MARK: - 常量

    /// VPN 配置描述名（唯一标识，避免重复创建）
    private static let vpnConfigDescription = "GalaxyKeepAlive"
    /// Extension Bundle ID
    private static let extensionBundleID = "com.example.galaxyIos.tunnel"

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
                self.enableKeepAlive { success in
                    result(success)
                }
            case "disableKeepAlive":
                self.disableKeepAlive { success in
                    result(success)
                }
            case "isKeepAliveActive":
                result(self.isKeepAliveEnabled)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        nativeLog("MethodChannel 绑定完成 ✅")
        // 绑定后立即加载已有的 VPN 配置
        loadExistingTunnelManager()
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
        nativeLog("App 进入后台，VPN 隧道状态: \(currentTunnelStatusDesc())")
    }

    func handleEnterForeground() {
        nativeLog("App 回到前台，VPN 隧道状态: \(currentTunnelStatusDesc())")
    }

    // MARK: - Keep Alive Control

    private func enableKeepAlive(completion: @escaping (Bool) -> Void) {
        nativeLog("🔌 正在启用 VPN 隧道保活...")
        isKeepAliveEnabled = true
        setupAndStartTunnel(completion: completion)
    }

    private func disableKeepAlive(completion: @escaping (Bool) -> Void) {
        nativeLog("🔌 正在停用 VPN 隧道保活...")
        isKeepAliveEnabled = false
        stopTunnel(completion: completion)
    }

    // MARK: - VPN 配置加载

    /// 启动时尝试加载已有 VPN 配置（避免重复创建）
    private func loadExistingTunnelManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else { return }
            if let error {
                self.nativeLog("⚠️  加载已有 VPN 配置失败: \(error.localizedDescription)")
                return
            }
            // 找到我们创建的配置
            let existing = managers?.first {
                $0.localizedDescription == Self.vpnConfigDescription
            }
            if let existing {
                self.tunnelManager = existing
                self.nativeLog("✅ 已加载现有 VPN 配置，当前状态: \(self.currentTunnelStatusDesc())")
                // 恢复观察 VPN 状态
                self.observeVPNStatus()
            } else {
                self.nativeLog("ℹ️  未找到已有 VPN 配置，将在首次启用时创建")
            }
        }
    }

    // MARK: - VPN 隧道建立

    private func setupAndStartTunnel(completion: @escaping (Bool) -> Void) {
        // 先尝试加载已有配置
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else { return }

            if let error {
                self.nativeLog("❌ 加载 VPN 配置失败: \(error.localizedDescription)")
                completion(false)
                return
            }

            // 复用已有配置 or 新建
            let manager = managers?.first {
                $0.localizedDescription == Self.vpnConfigDescription
            } ?? NETunnelProviderManager()

            // 配置 Protocol
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.extensionBundleID
            proto.serverAddress = "127.0.0.1"  // 伪服务器地址（本地回环，不真实连接）
            proto.disconnectOnSleep = false      // 设备睡眠时不断开

            manager.protocolConfiguration = proto
            manager.localizedDescription = Self.vpnConfigDescription
            manager.isEnabled = true

            self.nativeLog("💾 正在保存 VPN 配置到系统偏好...")

            manager.saveToPreferences { [weak self] error in
                guard let self else { return }

                if let error {
                    self.nativeLog("❌ 保存 VPN 配置失败: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                self.nativeLog("✅ VPN 配置保存成功，正在加载并启动隧道...")
                self.tunnelManager = manager

                // 必须 reload 后再 start（iOS 要求）
                manager.loadFromPreferences { [weak self] error in
                    guard let self else { return }

                    if let error {
                        self.nativeLog("❌ 重新加载 VPN 配置失败: \(error.localizedDescription)")
                        completion(false)
                        return
                    }

                    self.observeVPNStatus()
                    self.startVPNConnection(manager: manager, completion: completion)
                }
            }
        }
    }

    private func startVPNConnection(manager: NETunnelProviderManager, completion: @escaping (Bool) -> Void) {
        do {
            nativeLog("🚀 正在调用 startVPNTunnel...")
            try manager.connection.startVPNTunnel()
            nativeLog("✅ startVPNTunnel 调用成功，等待隧道建立...")
            completion(true)
        } catch let error as NSError {
            nativeLog("❌ startVPNTunnel 失败: \(error.localizedDescription) (domain=\(error.domain) code=\(error.code))")
            completion(false)
        }
    }

    // MARK: - VPN 隧道停止

    private func stopTunnel(completion: @escaping (Bool) -> Void) {
        guard let manager = tunnelManager else {
            nativeLog("ℹ️  无活跃的 VPN 配置，无需停止")
            completion(true)
            return
        }

        let status = manager.connection.status
        nativeLog("🛑 正在停止 VPN 隧道，当前状态: \(describeStatus(status))")

        if status == .disconnected || status == .disconnecting {
            nativeLog("ℹ️  隧道已处于断开状态，跳过")
            completion(true)
            return
        }

        manager.connection.stopVPNTunnel()
        nativeLog("✅ stopVPNTunnel 调用完成")
        completion(true)
    }

    // MARK: - VPN 状态观察

    private func observeVPNStatus() {
        // 移除旧观察者
        if let obs = vpnStatusObserver {
            NotificationCenter.default.removeObserver(obs)
        }

        vpnStatusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: tunnelManager?.connection,
            queue: .main
        ) { [weak self] _ in
            guard let self, let connection = self.tunnelManager?.connection else { return }
            let status = connection.status
            self.nativeLog("📶 VPN 状态变化 → \(self.describeStatus(status))")

            // 如果意外断开且保活开关仍开启，自动重连
            if status == .disconnected && self.isKeepAliveEnabled {
                self.nativeLog("⚡ 隧道意外断开，3 秒后自动重连...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let self, self.isKeepAliveEnabled else { return }
                    self.nativeLog("🔄 正在执行自动重连...")
                    self.startVPNConnection(manager: connection.manager as! NETunnelProviderManager) { success in
                        self.nativeLog("🔄 自动重连结果: \(success ? "✅ 成功" : "❌ 失败")")
                    }
                }
            }
        }

        nativeLog("👁️  VPN 状态观察者已注册")
    }

    // MARK: - 工具方法

    private func currentTunnelStatusDesc() -> String {
        guard let manager = tunnelManager else { return "无配置" }
        return describeStatus(manager.connection.status)
    }

    private func describeStatus(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:      return "invalid（配置无效）"
        case .disconnected: return "disconnected（已断开）"
        case .connecting:   return "connecting（连接中）"
        case .connected:    return "connected（已连接）✅"
        case .reasserting:  return "reasserting（重新建立中）"
        case .disconnecting: return "disconnecting（断开中）"
        @unknown default:   return "unknown(\(status.rawValue))"
        }
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
