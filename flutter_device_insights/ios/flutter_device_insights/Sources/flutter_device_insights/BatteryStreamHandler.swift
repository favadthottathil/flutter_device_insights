import UIKit

/// Streams battery level/status. Observers are added in `onListen` and always
/// removed in `onCancel` or `stop()`; battery monitoring is switched back off
/// if this handler was the one that switched it on.
///
/// UIKit posts both notifications on the main thread, which is where
/// `FlutterEventSink` must be called.
final class BatteryStreamHandler: BatteryStateStreamHandler {
  private var observers: [NSObjectProtocol] = []
  private var restoreMonitoring = false
  private var lastEmitted: BatteryStateMessage?

  /// Maps `UIDevice.batteryLevel` (0.0-1.0, or -1 when unknown) to 0-100.
  static func percent(from level: Float) -> Int64? {
    guard level >= 0 else { return nil }
    return Int64((level * 100).rounded())
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<BatteryStateMessage>) {
    // A second onListen without onCancel replaces the sink; drop the old
    // observers first so we never hold two.
    stop()

    let device = UIDevice.current
    restoreMonitoring = !device.isBatteryMonitoringEnabled
    device.isBatteryMonitoringEnabled = true

    let center = NotificationCenter.default
    for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
      observers.append(
        center.addObserver(forName: name, object: device, queue: .main) { [weak self] _ in
          self?.emit(sink)
        })
    }
    // Unlike Android's sticky broadcast, UIKit sends nothing on subscribe, so
    // push the current value ourselves.
    emit(sink)
  }

  override func onCancel(withArguments arguments: Any?) {
    stop()
  }

  /// Idempotent. Also called when the plugin detaches from the engine.
  func stop() {
    guard !observers.isEmpty else { return }
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
    lastEmitted = nil
    if restoreMonitoring {
      UIDevice.current.isBatteryMonitoringEnabled = false
      restoreMonitoring = false
    }
  }

  private func emit(_ sink: PigeonEventSink<BatteryStateMessage>) {
    let device = UIDevice.current
    // Level is unknown (e.g. simulator): nothing meaningful to report.
    guard let level = Self.percent(from: device.batteryLevel) else { return }

    let message = BatteryStateMessage(level: level, status: Self.status(from: device.batteryState))
    guard message != lastEmitted else { return }
    lastEmitted = message
    sink.success(message)
  }

  /// iOS has no "not charging" state, so `.notCharging` is never produced.
  private static func status(from state: UIDevice.BatteryState) -> BatteryStatusMessage {
    switch state {
    case .charging: return .charging
    case .unplugged: return .discharging
    case .full: return .full
    case .unknown: return .unknown
    @unknown default: return .unknown
    }
  }
}
