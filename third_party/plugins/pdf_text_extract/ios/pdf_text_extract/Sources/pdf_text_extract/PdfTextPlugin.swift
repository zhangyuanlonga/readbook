import Flutter

public class PdfTextPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    SwiftPdfTextPlugin.register(with: registrar)
  }
}
