import 'battery_state.dart';
import 'flutter_device_insights_platform_interface.dart';
import 'thermal_status.dart';

export 'battery_state.dart';
export 'device_insights_exception.dart';
export 'thermal_status.dart';

class FlutterDeviceInsights {
  /// Battery charge as a percentage in the range 0-100.
  Future<int> getBatteryLevel() {
    return FlutterDeviceInsightsPlatform.instance.getBatteryLevel();
  }

  /// Manufacturer and model, e.g. `Google Pixel 8`.
  Future<String> getDeviceModel() {
    return FlutterDeviceInsightsPlatform.instance.getDeviceModel();
  }

  /// Total size in bytes of the app's cache directory (Android `cacheDir`, iOS
  /// `Library/Caches`). The native side walks the whole tree on a background
  /// queue, so a large cache does not block the UI, but the call itself can
  /// take noticeable time. Calls are serialised natively.
  Future<int> getCacheSizeBytes() {
    return FlutterDeviceInsightsPlatform.instance.getCacheSizeBytes();
  }

  /// Opens the system settings screen for this app.
  Future<void> openAppSettings() {
    return FlutterDeviceInsightsPlatform.instance.openAppSettings();
  }

  /// Battery changes as a broadcast stream. Emits the current state first.
  /// The native receiver is registered on the first listener and unregistered
  /// when the last one cancels.
  Stream<BatteryState> get batteryStateStream {
    return FlutterDeviceInsightsPlatform.instance.batteryStateStream;
  }

  /// Thermal status changes as a broadcast stream. Emits the current status
  /// first. Errors with `UNAVAILABLE` below Android 10 (API 29).
  Stream<ThermalStatus> get thermalStatusStream {
    return FlutterDeviceInsightsPlatform.instance.thermalStatusStream;
  }
}
