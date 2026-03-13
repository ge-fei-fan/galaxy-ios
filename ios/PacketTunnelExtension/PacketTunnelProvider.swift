import NetworkExtension
import os.log

/// 日志子系统
private let logger = Logger(subsystem: "com.example.galaxyIos.tunnel", category: "PacketTunnelProvider")

/// 空包隧道提供者
/// 功能：建立一个不转发任何真实流量的伪 VPN 隧道，仅用于保持 App 在 iOS 后台常驻。
/// 原理：系统为维持 VPN 连接，会主动保持此进程存活，即使主 App 被用户划掉也不受影响。
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - 心跳定时器（防止系统回收进程）
    private var heartbeatTimer: Timer?
    private static let heartbeatInterval: TimeInterval = 25  // 每 25 秒一次心跳日志

    // MARK: - 启动隧道

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        logger.info("🚀 [PacketTunnel] startTunnel 被调用，开始建立空隧道...")

        // 配置网络设置：使用本地回环地址建立最小化 TUN 接口
        let settings = createTunnelNetworkSettings()

        logger.info("📡 [PacketTunnel] 正在应用网络设置: local=10.8.0.1 remote=10.8.0.2 mtu=1500")

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }

            if let error {
                logger.error("❌ [PacketTunnel] 网络设置应用失败: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            logger.info("✅ [PacketTunnel] 空隧道建立成功，进程已被系统接管保活")
            self.startHeartbeat()
            completionHandler(nil)
        }
    }

    // MARK: - 停止隧道

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        let reasonDesc = describeStopReason(reason)
        logger.info("🛑 [PacketTunnel] stopTunnel 被调用，原因: \(reasonDesc) (rawValue=\(reason.rawValue))")

        stopHeartbeat()
        completionHandler()

        logger.info("✅ [PacketTunnel] 隧道已关闭")
    }

    // MARK: - 处理 App 消息（主 App → Extension 通信）

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let message = String(data: messageData, encoding: .utf8) ?? "(二进制数据)"
        logger.info("📨 [PacketTunnel] 收到主 App 消息: \(message)")

        // 回复当前状态
        let response = "tunnelAlive:\(Date())"
        completionHandler?(response.data(using: .utf8))
    }

    // MARK: - 睡眠/唤醒处理

    override func sleep(completionHandler: @escaping () -> Void) {
        logger.info("😴 [PacketTunnel] 设备进入睡眠，隧道挂起")
        completionHandler()
    }

    override func wake() {
        logger.info("⏰ [PacketTunnel] 设备唤醒，隧道恢复")
    }

    // MARK: - Private: 创建隧道网络设置

    /// 创建最小化的 TUN 网络设置
    /// - 使用 10.8.0.0/30 子网，不设置任何路由，不捕获任何流量
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.8.0.2")

        // IPv4：本地端 10.8.0.1，对端 10.8.0.2，子网 /30
        let ipv4 = NEIPv4Settings(addresses: ["10.8.0.1"], subnetMasks: ["255.255.255.252"])
        // 不添加任何路由 → 不捕获任何真实网络流量
        ipv4.includedRoutes = []
        ipv4.excludedRoutes = []
        settings.ipv4Settings = ipv4

        // MTU 设为标准值
        settings.mtu = 1500

        // 不设置 DNS（避免影响系统 DNS）
        // settings.dnsSettings = nil

        logger.info("⚙️  [PacketTunnel] 网络设置创建完毕（空路由表，不拦截流量）")
        return settings
    }

    // MARK: - Private: 心跳定时器

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: Self.heartbeatInterval,
            repeats: true
        ) { _ in
            logger.info("💓 [PacketTunnel] 心跳 - 进程仍在运行，时间: \(Date())")
        }
        logger.info("⏱️  [PacketTunnel] 心跳定时器已启动（间隔 \(Self.heartbeatInterval)s）")
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        logger.info("⏱️  [PacketTunnel] 心跳定时器已停止")
    }

    // MARK: - Private: 停止原因描述

    private func describeStopReason(_ reason: NEProviderStopReason) -> String {
        switch reason {
        case .none:               return "无"
        case .userInitiated:      return "用户主动断开"
        case .providerFailed:     return "Provider 异常"
        case .noNetworkAvailable: return "网络不可用"
        case .unrecoverableNetworkChange: return "网络变化（不可恢复）"
        case .providerDisabled:   return "Provider 被禁用"
        case .authenticationCanceled: return "认证被取消"
        case .configurationFailed: return "配置失败"
        case .idleTimeout:        return "空闲超时"
        case .configurationDisabled: return "配置被禁用"
        case .sleeping:           return "设备进入睡眠"
        case .appUpdate:          return "App 更新"
        @unknown default:         return "未知原因(\(reason.rawValue))"
        }
    }
}
