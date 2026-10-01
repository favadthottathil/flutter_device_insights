import Flutter
import UIKit

public class FlutterDeviceInsightsPlugin: NSObject, FlutterPlugin, DeviceInsightsHostApi {
  private var batteryHandler: BatteryStreamHandler?
  private var thermalHandler: ThermalStreamHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterDeviceInsightsPlugin()
    let messenger = registrar.messenger()

    DeviceInsightsHostApiSetup.setUp(binaryMessenger: messenger, api: instance)

    let battery = BatteryStreamHandler()
    let thermal = ThermalStreamHandler()
    BatteryStateStreamHandler.register(with: messenger, streamHandler: battery)
    ThermalStatusStreamHandler.register(with: messenger, streamHandler: thermal)
    instance.batteryHandler = battery
    instance.thermalHandler = thermal

    // Keeps the instance (and so the handlers) alive for the engine's lifetime.
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    DeviceInsightsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    // The generated register(...) does not return the channel, so the stream
    // handlers cannot be unset; stop() releases the observers instead.
    batteryHandler?.stop()
    thermalHandler?.stop()
    batteryHandler = nil
    thermalHandler = nil
  }

  // MARK: DeviceInsightsHostApi

  func getBatteryLevel() throws -> Int64 {
    // Battery monitoring is app-global; restore what we found so a one-shot
    // read does not leave it switched on.
    let device = UIDevice.current
    let wasEnabled = device.isBatteryMonitoringEnabled
    device.isBatteryMonitoringEnabled = true
    defer { device.isBatteryMonitoringEnabled = wasEnabled }

    // -1 means the level is unknown, which is always the case on the simulator.
    guard let percent = BatteryStreamHandler.percent(from: device.batteryLevel) else {
      throw PigeonError(code: "UNAVAILABLE", message: "Battery level is not available.", details: nil)
    }
    return percent
  }

  func getDeviceModel() throws -> String {
    // UIDevice.model is just "iPhone"; the hardware identifier ("iPhone15,2")
    // is the closest equivalent of Android's manufacturer + model. It is not
    // the marketing name.
    var info = utsname()
    uname(&info)
    let identifier = withUnsafeBytes(of: &info.machine) { raw in
      String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
    }
    return "Apple \(identifier)"
  }

  // Runs on the Pigeon background queue (FlutterTaskQueue), not the main thread.
  // FileManager is documented as safe to use from a background thread.
  func getCacheSizeBytes() throws -> Int64 {
    guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      throw PigeonError(code: "UNAVAILABLE", message: "Cache directory not available.", details: nil)
    }
    // Logical size, to match Android's File.length(); not blocks on disk.
    let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
    // The error handler returns true to keep going past unreadable entries.
    guard
      let enumerator = FileManager.default.enumerator(
        at: cacheDir,
        includingPropertiesForKeys: Array(keys),
        options: [],
        errorHandler: { _, _ in true }
      )
    else {
      throw PigeonError(code: "UNAVAILABLE", message: "Cache directory could not be read.", details: nil)
    }
    var total: Int64 = 0
    for case let url as URL in enumerator {
      guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
      total += Int64(values.fileSize ?? 0)
    }
    return total
  }

  func openAppSettings() throws {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      throw PigeonError(code: "NO_ACTIVITY", message: "Could not resolve the app settings screen.", details: nil)
    }
    // Host calls run on the platform (main) thread, as UIApplication requires.
    // open(_:) reports success asynchronously, after this call has replied.
    UIApplication.shared.open(url)
  }
}
