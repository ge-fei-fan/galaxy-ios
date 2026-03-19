# iOS 小组件（点击跳转 App）接入说明

本仓库已完成以下代码：

- Flutter 侧 deep link 监听（`galaxyios://open?tab=...`）
- `Runner/Info.plist` URL Scheme 注册（`galaxyios`）
- Widget 示例源码：
  - `ios/WidgetExtension/GalaxyWidgetBundle.swift`
  - `ios/WidgetExtension/GalaxyQuickOpenWidget.swift`
  - `ios/WidgetExtension/Info.plist`

## 还需在 Xcode 完成的一次性配置

由于 `Runner.xcodeproj/project.pbxproj` 的 target 配置结构较复杂，建议在 Xcode 中完成 target 接入（最稳妥）。

1. 用 Xcode 打开 `ios/Runner.xcworkspace`
2. `File -> New -> Target... -> Widget Extension`
3. Product Name 建议填：`WidgetExtension`
4. 勾选 `Include Configuration Intent` 请关闭（不需要）
5. 创建后，用以下文件替换 Xcode 自动生成文件：
   - 删除默认 `Widget` swift 文件
   - 把仓库中的 `ios/WidgetExtension/GalaxyWidgetBundle.swift`、`ios/WidgetExtension/GalaxyQuickOpenWidget.swift`、`ios/WidgetExtension/Info.plist` 拖入该 target
6. 在 Runner target 的 `General -> Frameworks, Libraries, and Embedded Content` 确认 `.appex` 为 `Embed & Sign`
7. 清理并重建：`Product -> Clean Build Folder`，然后 Build

## Deep Link 参数约定

- `galaxyios://open?tab=home` -> 首页
- `galaxyios://open?tab=collection` -> 收藏
- `galaxyios://open?tab=mqtt` -> MQTT
- `galaxyios://open?tab=settings` -> 设置

## 验证

1. 安装到 iPhone
2. 长按桌面添加小组件，选择 `Galaxy 快捷入口`
3. 点击小组件，确认能拉起 App 并切换到指定 tab

> TrollStore 场景下若新装后暂时看不到小组件：可尝试重启 SpringBoard 或卸载重装一次。
