import Foundation

/// Streams `ProcessInfo.thermalState`. The observer is added in `onListen` and
/// always removed in `onCancel` or `stop()`.
///
/// Delivered on the main queue: the notification can be posted from any
/// thread, but `FlutterEventSink` must be called on the platform thread.
final class ThermalStreamHandler: ThermalStatusStreamHandler {
  private var observer: NSObjectProtocol?
  private var lastEmitted: ThermalStatusMessage?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ThermalStatusMessage>) {
    stop()

    observer = NotificationCenter.default.addObserver(
      forName: ProcessInfo.thermalStateDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emit(sink)
    }
    emit(sink)
  }

  override func onCancel(withArguments arguments: Any?) {
    stop()
  }

  /// Idempotent. Also called when the plugin detaches from the engine.
  func stop() {
    guard let current = observer else { return }
    NotificationCenter.default.removeObserver(current)
    observer = nil
    lastEmitted = nil
  }

  private func emit(_ sink: PigeonEventSink<ThermalStatusMessage>) {
    let message = Self.status(from: ProcessInfo.processInfo.thermalState)
    guard message != lastEmitted else { return }
    lastEmitted = message
    sink.success(message)
  }

  /// iOS reports four levels against Android's seven, so the mapping is
  /// coarser: `.light`, `.moderate`, `.emergency` and `.shutdown` never occur.
  private static func status(from state: ProcessInfo.ThermalState) -> ThermalStatusMessage {
    switch state {
    case .nominal: return .none
    case .fair: return .light
    case .serious: return .severe
    case .critical: return .critical
    @unknown default: return .unknown
    }
  }
}
