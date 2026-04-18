import Flutter
import AVFoundation
import MediaPlayer
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let sourceImportChannelName = "com.jiangyan.selune/source_import_intent"
  private let methodGetInitialImportPayload = "getInitialImportPayload"
  private let methodOnImportPayload = "onImportPayload"
  private let methodCacheExternalFileFromUri = "cacheExternalFileFromUri"
  private let readerVolumeKeyChannelName = "com.jiangyan.selune/reader_volume_keys"
  private let readerVolumeKeyEventChannelName = "com.jiangyan.selune/reader_volume_keys/events"
  private let methodSetInterceptVolumeKeys = "setInterceptVolumeKeys"
  private let defaultPayloadLabel = "外部导入"
  private let payloadTypeLocalBook = "localBook"
  private let payloadTypeScriptSource = "scriptSource"
  private let payloadTypeAdvancedTheme = "advancedTheme"
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

  private func logSourceImport(_ message: String) {
    NSLog("[SourceImport] %@", message)
  }

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
      case self.methodCacheExternalFileFromUri:
        guard let arguments = call.arguments as? [String: Any] else {
          result(nil as Any?)
          return
        }
        result(self.cacheExternalFileFromUri(arguments))
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
      logSourceImport("Ignored non-file url: \(url.absoluteString)")
      return nil
    }

    let startedSecurityScopedAccess = url.startAccessingSecurityScopedResource()
    defer {
      if startedSecurityScopedAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let label = resolvePayloadLabel(from: url)
    let mimeType = resolveMimeType(from: url)
    let payloadType = classifyPayloadType(
      url: url,
      mimeType: mimeType
    )

    logSourceImport(
      "Resolved external file url=\(url.absoluteString) label=\(label) mime=\(mimeType ?? "nil") payloadType=\(payloadType ?? "nil")"
    )

    switch payloadType {
    case payloadTypeLocalBook:
      return [
        "type": payloadTypeLocalBook,
        "uri": url.absoluteString,
        "label": label,
        "mimeType": mimeType ?? "",
      ]
    case payloadTypeAdvancedTheme:
      return [
        "type": payloadTypeAdvancedTheme,
        "uri": url.absoluteString,
        "label": label,
        "mimeType": mimeType ?? "",
      ]
    case payloadTypeScriptSource:
      return [
        "type": payloadTypeScriptSource,
        "uri": url.absoluteString,
        "label": label,
        "mimeType": mimeType ?? "",
      ]
    default:
      logSourceImport("Unsupported external file type for url=\(url.absoluteString)")
      return nil
    }
  }


  private func classifyPayloadType(
    url: URL,
    mimeType: String?
  ) -> String? {
    let extensionName = url.pathExtension.lowercased()
    let normalizedMimeType = mimeType?.lowercased()

    if extensionName == "epub" || normalizedMimeType == "application/epub+zip" {
      return payloadTypeLocalBook
    }
    if extensionName == "txt" ||
      normalizedMimeType == "text/plain" ||
      normalizedMimeType == "application/octet-stream" {
      return payloadTypeLocalBook
    }
    if extensionName == "js" ||
      extensionName == "mjs" ||
      normalizedMimeType == "text/javascript" ||
      normalizedMimeType == "application/javascript" {
      return payloadTypeScriptSource
    }
    if extensionName == "json" ||
      normalizedMimeType == "application/json" {
      return payloadTypeAdvancedTheme
    }
    return nil
  }

  private func resolveMimeType(from url: URL) -> String? {
    let extensionName = url.pathExtension
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    if extensionName.isEmpty {
      return nil
    }
    if #available(iOS 14.0, *) {
      return UTType(filenameExtension: extensionName)?.preferredMIMEType
    }
    return nil
  }

  private func cacheExternalFileFromUri(_ arguments: [String: Any]) -> [String: Any]? {
    guard
      let rawUri = (arguments["uri"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawUri.isEmpty,
      let uri = URL(string: rawUri),
      uri.isFileURL
    else {
      logSourceImport("cacheExternalFileFromUri rejected invalid uri payload=\(arguments)")
      return nil
    }

    let rawLabel = (arguments["label"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let label = (rawLabel?.isEmpty == false) ? rawLabel! : resolvePayloadLabel(from: uri)
    let rawMimeType = (arguments["mimeType"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let mimeType = (rawMimeType?.isEmpty == false) ? rawMimeType! : (resolveMimeType(from: uri) ?? "")
    guard let extensionName = resolveExternalImportExtension(
      url: uri,
      label: label,
      mimeType: mimeType
    ) else {
      logSourceImport("Unable to resolve extension for uri=\(uri.absoluteString) label=\(label) mime=\(mimeType)")
      return nil
    }

    let startedSecurityScopedAccess = uri.startAccessingSecurityScopedResource()
    defer {
      if startedSecurityScopedAccess {
        uri.stopAccessingSecurityScopedResource()
      }
    }

    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: uri.path) else {
      logSourceImport("External file does not exist at path=\(uri.path)")
      return nil
    }

    let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let baseDirectory = cacheRoot else {
      return nil
    }
    let outputDirectory = baseDirectory.appendingPathComponent("external_imports", isDirectory: true)
    do {
      try fileManager.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      logSourceImport("Failed to create external import cache directory error=\(error.localizedDescription)")
      return nil
    }

    let baseName = sanitizeFileToken((label as NSString).deletingPathExtension)
    let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
    let outputUrl = outputDirectory.appendingPathComponent(
      "\(timestamp)_\(baseName)\(extensionName)",
      isDirectory: false
    )

    do {
      if fileManager.fileExists(atPath: outputUrl.path) {
        try fileManager.removeItem(at: outputUrl)
      }
      try fileManager.copyItem(at: uri, to: outputUrl)
      logSourceImport("Copied external import file to cache path=\(outputUrl.path)")
    } catch {
      logSourceImport("copyItem failed for uri=\(uri.absoluteString), fallback to Data write, error=\(error.localizedDescription)")
      do {
        let data = try Data(contentsOf: uri)
        try data.write(to: outputUrl, options: .atomic)
        logSourceImport("Wrote external import file via Data fallback path=\(outputUrl.path) bytes=\(data.count)")
      } catch {
        logSourceImport("Failed to cache external file uri=\(uri.absoluteString) error=\(error.localizedDescription)")
        return nil
      }
    }

    let normalizedLabel = label.lowercased().hasSuffix(extensionName) ? label : "\(label)\(extensionName)"
    logSourceImport("Prepared cached external import label=\(normalizedLabel) path=\(outputUrl.path) mime=\(mimeType)")
    return [
      "path": outputUrl.path,
      "label": normalizedLabel,
      "mimeType": mimeType,
    ]
  }

  private func resolveExternalImportExtension(
    url: URL,
    label: String,
    mimeType: String?
  ) -> String? {
    let urlExtension = url.pathExtension
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let lowerLabel = label.lowercased()
    let normalizedMimeType = mimeType?.lowercased() ?? ""
    if urlExtension == "txt" {
      return ".txt"
    }
    if urlExtension == "epub" {
      return ".epub"
    }
    if urlExtension == "js" {
      return ".js"
    }
    if urlExtension == "mjs" {
      return ".mjs"
    }
    if lowerLabel.hasSuffix(".txt") {
      return ".txt"
    }
    if lowerLabel.hasSuffix(".epub") {
      return ".epub"
    }
    if lowerLabel.hasSuffix(".js") {
      return ".js"
    }
    if lowerLabel.hasSuffix(".mjs") {
      return ".mjs"
    }
    if normalizedMimeType == "application/epub+zip" {
      return ".epub"
    }
    if normalizedMimeType == "text/plain" || normalizedMimeType == "application/octet-stream" {
      return ".txt"
    }
    if normalizedMimeType == "text/javascript" || normalizedMimeType == "application/javascript" {
      return ".js"
    }
    return nil
  }

  private func sanitizeFileToken(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let sanitized = trimmed.replacingOccurrences(
      of: #"[\\/:*?"<>|]"#,
      with: "_",
      options: .regularExpression
    ).replacingOccurrences(
      of: #"\s+"#,
      with: "_",
      options: .regularExpression
    )
    return sanitized.isEmpty ? "external_book" : sanitized
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
