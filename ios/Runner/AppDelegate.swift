import Flutter
import AVFoundation
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let sourceImportChannelName = "com.jiangyan.shuxiangread/source_import_intent"
  private let methodGetInitialImportPayload = "getInitialImportPayload"
  private let methodOnImportPayload = "onImportPayload"
  private let readerVolumeKeyChannelName = "com.jiangyan.shuxiangread/reader_volume_keys"
  private let readerVolumeKeyEventChannelName = "com.jiangyan.shuxiangread/reader_volume_keys/events"
  private let methodSetInterceptVolumeKeys = "setInterceptVolumeKeys"
  private let defaultPayloadLabel = "外部书源"
  private let readerVolumeBaseline: Float = 0.5

  private var sourceImportMethodChannel: FlutterMethodChannel?
  private var readerVolumeKeyMethodChannel: FlutterMethodChannel?
  private var readerVolumeKeyEventChannel: FlutterEventChannel?
  private let readerVolumeKeyStreamHandler = ReaderVolumeKeyStreamHandler()
  private var pendingInitialPayload: [String: Any]?
  private var interceptReaderVolumeKeys = false
  private var volumeObservation: NSKeyValueObservation?
  private var hiddenVolumeView: MPVolumeView?
  private weak var hiddenVolumeSlider: UISlider?
  private var suppressObservedVolumeChange = false
  private var lastObservedOutputVolume = AVAudioSession.sharedInstance().outputVolume

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let launchURL = launchOptions?[.url] as? URL {
      pendingInitialPayload = payloadFromURL(launchURL)
    }

    GeneratedPluginRegistrant.register(with: self)
    setupSourceImportMethodChannel()
    setupReaderVolumeKeyBridge()
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

  private func setupReaderVolumeKeyBridge() {
    guard let registrar = self.registrar(forPlugin: "ReaderVolumeKeyPageBridge") else {
      return
    }

    let methodChannel = FlutterMethodChannel(
      name: readerVolumeKeyChannelName,
      binaryMessenger: registrar.messenger())
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil as Any?)
        return
      }

      switch call.method {
      case self.methodSetInterceptVolumeKeys:
        self.interceptReaderVolumeKeys = (call.arguments as? Bool) ?? false
        self.updateReaderVolumeKeyInterception()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    readerVolumeKeyMethodChannel = methodChannel

    let eventChannel = FlutterEventChannel(
      name: readerVolumeKeyEventChannelName,
      binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(readerVolumeKeyStreamHandler)
    readerVolumeKeyEventChannel = eventChannel
  }

  private func updateReaderVolumeKeyInterception() {
    if interceptReaderVolumeKeys {
      activateReaderVolumeAudioSessionIfNeeded()
      ensureHiddenVolumeView()
      startObservingVolumeChangesIfNeeded()
      resetSystemVolumeToBaselineIfNeeded(force: true)
      return
    }

    stopObservingVolumeChanges()
    removeHiddenVolumeView()
  }

  private func activateReaderVolumeAudioSessionIfNeeded() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.ambient, options: [.mixWithOthers])
      try session.setActive(true, options: [])
      lastObservedOutputVolume = session.outputVolume
    } catch {
      // Ignore audio session setup failures to avoid breaking reading.
    }
  }

  private func ensureHiddenVolumeView() {
    if hiddenVolumeView != nil {
      return
    }
    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    volumeView.alpha = 0.01
    volumeView.showsRouteButton = false
    volumeView.showsVolumeSlider = true
    flutterViewController.view.addSubview(volumeView)

    hiddenVolumeView = volumeView
    hiddenVolumeSlider = findVolumeSlider(in: volumeView)
  }

  private func findVolumeSlider(in view: UIView) -> UISlider? {
    if let slider = view as? UISlider {
      return slider
    }
    for subview in view.subviews {
      if let slider = findVolumeSlider(in: subview) {
        return slider
      }
    }
    return nil
  }

  private func removeHiddenVolumeView() {
    hiddenVolumeView?.removeFromSuperview()
    hiddenVolumeView = nil
    hiddenVolumeSlider = nil
    suppressObservedVolumeChange = false
  }

  private func startObservingVolumeChangesIfNeeded() {
    if volumeObservation != nil {
      return
    }

    let session = AVAudioSession.sharedInstance()
    lastObservedOutputVolume = session.outputVolume
    volumeObservation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
      self?.handleObservedVolumeChange(oldValue: change.oldValue, newValue: change.newValue)
    }
  }

  private func stopObservingVolumeChanges() {
    volumeObservation?.invalidate()
    volumeObservation = nil
  }

  private func handleObservedVolumeChange(oldValue: Float?, newValue: Float?) {
    guard interceptReaderVolumeKeys, let newVolume = newValue else {
      return
    }

    let previousVolume = oldValue ?? lastObservedOutputVolume
    lastObservedOutputVolume = newVolume

    if suppressObservedVolumeChange {
      return
    }

    let delta = newVolume - previousVolume
    if abs(delta) < 0.0001 {
      return
    }

    readerVolumeKeyStreamHandler.emit([
      "direction": delta > 0 ? "up" : "down",
      "repeatCount": 0,
    ])
    resetSystemVolumeToBaselineIfNeeded()
  }

  private func resetSystemVolumeToBaselineIfNeeded(force: Bool = false) {
    guard let slider = hiddenVolumeSlider else {
      return
    }

    let currentVolume = AVAudioSession.sharedInstance().outputVolume
    if !force, abs(currentVolume - readerVolumeBaseline) < 0.02 {
      return
    }

    suppressObservedVolumeChange = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
      guard let self, self.interceptReaderVolumeKeys else {
        return
      }

      slider.setValue(self.readerVolumeBaseline, animated: false)
      slider.sendActions(for: .valueChanged)

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        guard let self else {
          return
        }
        self.lastObservedOutputVolume = AVAudioSession.sharedInstance().outputVolume
        self.suppressObservedVolumeChange = false
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

private final class ReaderVolumeKeyStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  func emit(_ payload: [String: Any]) {
    eventSink?(payload)
  }
}
