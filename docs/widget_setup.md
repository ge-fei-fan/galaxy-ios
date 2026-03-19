# iOS 小组件 + 灵动岛（MQTT 最新消息）接入说明

本仓库已完成以下代码：

- Flutter 侧 deep link 监听（`galaxyios://open?tab=...`）
- `Runner/Info.plist` URL Scheme 注册（`galaxyios`）
- Widget 与 Live Activity 源码：
  - `ios/WidgetExtension/GalaxyWidgetBundle.swift`
  - `ios/WidgetExtension/GalaxyQuickOpenWidget.swift`
  - `ios/WidgetExtension/Info.plist`
- Flutter MQTT 收到消息后会调用原生：
  - 写入 App Group 共享存储（供 Widget 显示）
  - 刷新 Widget 时间线
  - 创建/更新 Live Activity（灵动岛）

## 当前功能

- 小组件展示最新 MQTT 消息（支持 `small / medium / large`）
- 点击小组件跳转到 App 的 MQTT 页
- 收到 MQTT 新消息后自动更新灵动岛/锁屏 Live Activity（iOS 16.1+）

## 你需要确认/修改的配置（非常重要）

### 1) App Group ID 与包名一致

当前示例使用：`group.com.example.galaxyIos`

若你改了包名，需同步修改以下位置：

1. `ios/Runner/Runner.entitlements`
2. `ios/WidgetExtension/WidgetExtension.entitlements`
3. `ios/Runner/AppDelegate.swift` 里的 `appGroupId`
4. `ios/WidgetExtension/GalaxyQuickOpenWidget.swift` 里的 `appGroupId`

### 2) Apple Developer 能力开关

在 Xcode 中确认 Runner 与 WidgetExtension 两个 target 都打开：

- **App Groups**（并勾选同一个 group）
- **Background Modes / audio**（Runner，已用于你现有保活策略）
- **Live Activities**（Runner）

> 如果 capability 没开，代码能编译但运行时可能不显示数据/不出灵动岛。

## Deep Link 参数约定

- `galaxyios://open?tab=home` -> 首页
- `galaxyios://open?tab=collection` -> 收藏
- `galaxyios://open?tab=mqtt` -> MQTT
- `galaxyios://open?tab=settings` -> 设置

## 验证

1. 安装到 iPhone
2. 连接 MQTT 并订阅主题
3. 长按桌面添加小组件，选择 `Galaxy 快捷入口`
4. 向订阅主题发送消息，确认：
   - 小组件显示最新 topic/payload/time
   - iOS 16.1+ 机型在锁屏/灵动岛出现并更新 Live Activity
5. 点击小组件或灵动岛，确认跳转到 App MQTT 页

> TrollStore 场景下若新装后暂时看不到小组件：可尝试重启 SpringBoard 或卸载重装一次。

> 系统限制：Widget/Live Activity 刷新为“近实时”，不保证每条消息都毫秒级立即展示。

## CI / GitHub Actions 说明

本仓库工作流已补充两点：

1. `flutter build ios --no-codesign`（当前 Flutter 版本下 `--release` 不是有效参数）
2. 构建后校验：`Runner.app/PlugIns/WidgetExtension.appex` 必须存在，否则工作流失败

你如果在 TrollStore 安装后仍然看不到小组件，优先检查发布日志里是否通过了这一步嵌入校验。
