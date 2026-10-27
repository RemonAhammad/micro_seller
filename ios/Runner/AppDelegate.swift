import AVFoundation
import Flutter
import LocalAuthentication
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The app's own channel, micro_seller/device
  /// (lib/data/services/device_channel.dart): what the plugins don't tell.
  /// Here rather than in a file of its own, which the Xcode project would
  /// have to list.
  private var deviceChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: iOS shows a notification while the app is
    // open only if the notification center's delegate asks for it. The plugin
    // never sets that delegate itself; FlutterAppDelegate passes the calls on
    // to it. Without this line the low-stock and payment alerts are not shown.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "micro_seller/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "cameraStatus":
        result(AppDelegate.cameraStatus())
      case "openAppSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in result(opened) }
      case "biometryType":
        result(AppDelegate.biometryType())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    deviceChannel = channel
  }

  /// Whether the app may use the camera.
  private static func cameraStatus() -> String {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return "granted"
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    // iOS never asks twice: after a refusal only Settings can allow it.
    case .denied: return "permanentlyDenied"
    @unknown default: return "unknown"
    }
  }

  /// The biometric sensor, enrolled or not: canEvaluatePolicy fills in
  /// biometryType, also when it fails because nothing is enrolled yet.
  private static func biometryType() -> String {
    let context = LAContext()
    var error: NSError?
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    switch context.biometryType {
    case .faceID: return "face"
    case .touchID: return "touch"
    case .none: return "none"
    // Optic ID (Apple Vision Pro), and sensors to come.
    default: return "unknown"
    }
  }
}
