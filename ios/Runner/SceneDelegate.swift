import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // 绑定 MethodChannel：在 Scene 连接完成后，从 window 取出 FlutterViewController
    guard let windowScene = scene as? UIWindowScene,
          let controller = windowScene.windows.first?.rootViewController as? FlutterViewController,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      NSLog("[KeepAlive] SceneDelegate: 初始化失败（未找到 FlutterViewController 或 AppDelegate）")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.galaxy/background_keep_alive",
      binaryMessenger: controller.binaryMessenger
    )
    appDelegate.bindMethodChannel(channel)
    NSLog("[KeepAlive] SceneDelegate: MethodChannel 绑定成功 ✅")
  }

  // MARK: - Scene 生命周期
  // iOS 13+ Scene 架构下，系统不再回调 AppDelegate 的 background/foreground 方法，
  // 统一在此转发给 AppDelegate 处理。

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.handleEnterBackground()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.handleEnterForeground()
  }
}
