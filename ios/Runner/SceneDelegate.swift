import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  private var didBindChannel = false
  private var bindRetryCount = 0
  private let maxBindRetryCount = 20

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
    tryBindMethodChannel(scene)
  }

  private func tryBindMethodChannel(_ scene: UIScene) {
    guard !didBindChannel else { return }

    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      NSLog("[KeepAlive] SceneDelegate: 未找到 AppDelegate，稍后重试")
      scheduleBindRetry(scene)
      return
    }

    let flutterController = resolveFlutterViewController(from: scene)
    guard let flutterController else {
      NSLog("[KeepAlive] SceneDelegate: 未找到 FlutterViewController，稍后重试")
      scheduleBindRetry(scene)
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.galaxy/background_keep_alive",
      binaryMessenger: flutterController.binaryMessenger
    )
    appDelegate.bindMethodChannel(channel)
    didBindChannel = true
    NSLog("[KeepAlive] SceneDelegate: MethodChannel 绑定成功 ✅")
  }

  private func scheduleBindRetry(_ scene: UIScene) {
    guard !didBindChannel else { return }
    guard bindRetryCount < maxBindRetryCount else {
      NSLog("[KeepAlive] SceneDelegate: MethodChannel 重试达到上限，放弃")
      return
    }

    bindRetryCount += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.tryBindMethodChannel(scene)
    }
  }

  private func resolveFlutterViewController(from scene: UIScene) -> FlutterViewController? {
    guard let windowScene = scene as? UIWindowScene else { return nil }

    for window in windowScene.windows {
      if let controller = findFlutterViewController(in: window.rootViewController) {
        return controller
      }
    }
    return nil
  }

  private func findFlutterViewController(in controller: UIViewController?) -> FlutterViewController? {
    guard let controller else { return nil }
    if let flutter = controller as? FlutterViewController {
      return flutter
    }
    if let navigation = controller as? UINavigationController {
      for vc in navigation.viewControllers {
        if let result = findFlutterViewController(in: vc) {
          return result
        }
      }
    }
    if let tab = controller as? UITabBarController {
      for vc in tab.viewControllers ?? [] {
        if let result = findFlutterViewController(in: vc) {
          return result
        }
      }
    }
    if let presented = controller.presentedViewController,
       let result = findFlutterViewController(in: presented) {
      return result
    }
    return nil
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
