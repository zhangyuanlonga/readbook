import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let sourceImportChannelName = "com.jiangyan.shuxiangread/source_import_intent"
  private let methodGetInitialImportPayload = "getInitialImportPayload"
  private let methodOnImportPayload = "onImportPayload"
  private let defaultPayloadLabel = "外部书源"

  private var sourceImportMethodChannel: FlutterMethodChannel?
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
