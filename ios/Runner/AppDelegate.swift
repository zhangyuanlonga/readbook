import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let sourceImportChannelName = "com.example.flutter_appread/source_import_intent"
  private let methodGetInitialImportPayload = "getInitialImportPayload"
  private let methodOnImportPayload = "onImportPayload"
  private let defaultPayloadLabel = "外部书源"
  private let appIconChannelName = "com.example.flutter_appread/app_icon"
  private let methodIsSupported = "isSupported"
  private let methodGetCurrentIcon = "getCurrentIcon"
  private let methodSetAppIcon = "setAppIcon"
  private let iconKeyDefault = "default"
  private let iconKeyAlt = "alt"
  private let alternateIconName = "AppIconAlt"

  private var sourceImportMethodChannel: FlutterMethodChannel?
  private var appIconMethodChannel: FlutterMethodChannel?
  private var pendingInitialPayload: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let launchURL = launchOptions?[.url] as? URL {
      pendingInitialPayload = payloadFromURL(launchURL)
    }

    GeneratedPluginRegistrant.register(with: self)
    setupSourceImportMethodChannel()
    setupAppIconMethodChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard let payload = payloadFromURL(url) else {
      return super.application(app, open: url, options: options)
    }

    pendingInitialPayload = payload
    sourceImportMethodChannel?.invokeMethod(methodOnImportPayload, arguments: payload)
    return true
  }

  private func setupSourceImportMethodChannel() {
    guard let registrar = self.registrar(forPlugin: "SourceImportIntentBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: sourceImportChannelName,
      binaryMessenger: registrar.messenger())

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self else {
        result(nil as Any?)
        return
      }

      switch call.method {
      case self.methodGetInitialImportPayload:
        result(self.pendingInitialPayload)
        self.pendingInitialPayload = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    sourceImportMethodChannel = channel
  }

  private func setupAppIconMethodChannel() {
    guard let registrar = self.registrar(forPlugin: "AppIconBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: appIconChannelName,
      binaryMessenger: registrar.messenger())

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil as Any?)
        return
      }

      switch call.method {
      case self.methodIsSupported:
        result(self.isAlternateIconSupported())
      case self.methodGetCurrentIcon:
        result(self.currentAppIconKey())
      case self.methodSetAppIcon:
        self.setAppIcon(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    appIconMethodChannel = channel
  }

  private func isAlternateIconSupported() -> Bool {
    if #available(iOS 10.3, *) {
      return UIApplication.shared.supportsAlternateIcons
    }
    return false
  }

  private func currentAppIconKey() -> String {
    if #available(iOS 10.3, *) {
      return UIApplication.shared.alternateIconName == alternateIconName ? iconKeyAlt : iconKeyDefault
    }
    return iconKeyDefault
  }

  private func setAppIcon(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard isAlternateIconSupported() else {
      result(
        FlutterError(
          code: "NOT_SUPPORTED",
          message: "Alternate app icon is not supported on this device.",
          details: nil))
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let icon = arguments["icon"] as? String
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Missing icon argument.",
          details: nil))
      return
    }

    let targetIconName: String? = icon == iconKeyAlt ? alternateIconName : nil
    DispatchQueue.main.async {
      UIApplication.shared.setAlternateIconName(targetIconName) { error in
        if let error {
          result(
            FlutterError(
              code: "SET_ICON_FAILED",
              message: error.localizedDescription,
              details: nil))
          return
        }
        result(nil as Any?)
      }
    }
  }

  private func payloadFromURL(_ url: URL) -> [String: Any]? {
    guard url.isFileURL else {
      return nil
    }

    let startedSecurityScopedAccess = url.startAccessingSecurityScopedResource()
    defer {
      if startedSecurityScopedAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    guard let data = try? Data(contentsOf: url), !data.isEmpty else {
      return nil
    }

    let label = resolvePayloadLabel(from: url)
    return [
      "bytes": FlutterStandardTypedData(bytes: data),
      "label": label,
    ]
  }

  private func resolvePayloadLabel(from url: URL) -> String {
    let name = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? defaultPayloadLabel : name
  }
}
