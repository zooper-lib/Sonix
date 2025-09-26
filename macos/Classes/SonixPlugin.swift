import Cocoa
import FlutterMacOS

public class SonixPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // No method channel needed - Sonix uses FFI directly
    // This plugin exists only to bundle libsonix_native.dylib
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}