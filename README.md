# Galaxy iOS

这是一个 Flutter 项目，仓库内置 GitHub Actions 工作流用于打包 **未签名 IPA**。

## 发布流程

1. 推送 tag（形如 `v1.0.0`）或手动触发 `Release (iOS IPA)` 工作流。
2. 工作流会在 macOS 构建：
   - `flutter build ios --release --no-codesign`
   - 打包出 `GalaxyIOS.ipa`
3. IPA 会上传到 GitHub Release 与 Actions Artifact。

## 重要说明（无证书）

- 该 IPA **未签名**，无法直接在真机上通过系统安装。
- 可使用 AltStore / Sideloadly / Xcode 等工具进行侧载安装。

## 本地运行

```bash
flutter pub get
flutter run
```
