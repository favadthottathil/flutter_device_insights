import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'battery_state.dart';
import 'flutter_device_insights_pigeon.dart';
import 'thermal_status.dart';

abstract class FlutterDeviceInsightsPlatform extends PlatformInterface {
  /// Constructs a FlutterDeviceInsightsPlatform.
  FlutterDeviceInsightsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDeviceInsightsPlatform _instance = PigeonFlutterDeviceInsights();

  /// The default instance of [FlutterDeviceInsightsPlatform] to use.
  ///
  /// Defaults to [PigeonFlutterDeviceInsights].
  static FlutterDeviceInsightsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDeviceInsightsPlatform] when
  /// they register themselves.
  static set instance(FlutterDeviceInsightsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Battery charge as a percentage in the range 0-100.
  Future<int> getBatteryLevel() {
    throw UnimplementedError('getBatteryLevel() has not been implemented.');
  }

  /// Manufacturer and model, e.g. `Google Pixel 8`.
  Future<String> getDeviceModel() {
    throw UnimplementedError('getDeviceModel() has not been implemented.');
  }

  /// Total size in bytes of the app's cache directory.
  Future<int> getCacheSizeBytes() {
    throw UnimplementedError('getCacheSizeBytes() has not been implemented.');
  }

  /// Opens the system settings screen for this app.
  Future<void> openAppSettings() {
    throw UnimplementedError('openAppSettings() has not been implemented.');
  }

  /// Broadcast stream of battery changes. Emits the current state on listen.
  Stream<BatteryState> get batteryStateStream {
    throw UnimplementedError('batteryStateStream has not been implemented.');
  }

  /// Broadcast stream of thermal status changes. Emits the current status on
  /// listen.
  Stream<ThermalStatus> get thermalStatusStream {
    throw UnimplementedError('thermalStatusStream has not been implemented.');
  }
}
