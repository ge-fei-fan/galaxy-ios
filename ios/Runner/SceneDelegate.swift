import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // 在 Scene 架构下，window 由 SceneDelegate 管理
    // 这里绑定 MethodChannel，并初始化音频会话
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let windowScene = scene as? UIWindowScene,
            let controller = windowScene.windows.first?.rootViewController as? FlutterViewController else {
        NSLog("[KeepAlive] SceneDelegate: 未找到 FlutterViewController，通道绑定失败")
        return
      }

      guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
        NSLog("[KeepAlive] SceneDelegate: 未找到 AppDelegate")
        return
      }

      let channel = FlutterMethodChannel(
        name: "com.galaxy/background_keep_alive",
        binaryMessenger: controller.binaryMessenger
      )
      appDelegate.bindMethodChannel(channel)
      NSLog("[KeepAlive] SceneDelegate: MethodChannel 通信绑定成功 ✅")
    }
  }

  // MARK: - Scene 生命周期（iOS 13+ Scene 架构下替代 AppDelegate 的 background/foreground 回调）

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    NSLog("[KeepAlive] SceneDelegate: sceneDidEnterBackground 触发，转发给 AppDelegate")
    (UIApplication.shared.delegate as? AppDelegate)?.handleEnterBackground()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    NSLog("[KeepAlive] SceneDelegate: sceneWillEnterForeground 触发，转发给 AppDelegate")
    (UIApplication.shared.delegate as? AppDelegate)?.handleEnterForeground()
  }
}
