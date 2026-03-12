import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // 暂存 channel，等 sceneDidBecomeActive 时再绑定
  private var pendingChannel: FlutterMethodChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // willConnectTo 时 rootViewController 可能还未就绪，先不绑定
    NSLog("[KeepAlive] SceneDelegate: scene willConnectTo")
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)

    // sceneDidBecomeActive 时 rootViewController 已完全就绪，安全绑定 Channel
    guard pendingChannel == nil else { return }  // 只绑定一次

    guard let windowScene = scene as? UIWindowScene,
          let controller = windowScene.windows.first?.rootViewController as? FlutterViewController,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      NSLog("[KeepAlive] SceneDelegate: 未找到 FlutterViewController 或 AppDelegate，绑定失败")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.galaxy/background_keep_alive",
      binaryMessenger: controller.binaryMessenger
    )
    pendingChannel = channel
    appDelegate.bindMethodChannel(channel)
    NSLog("[KeepAlive] SceneDelegate: MethodChannel 绑定成功 ✅")
  }

  // MARK: - Scene 生命周期
  // iOS 13+ 下系统不再回调 AppDelegate 的 background/foreground，统一在此转发。

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.handleEnterBackground()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.handleEnterForeground()
  }
}
