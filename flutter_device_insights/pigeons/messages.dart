// Single source of truth for the Dart <-> native contract.
// Regenerate after any change:
//   dart run pigeon --input pigeons/messages.dart
// The generated files are committed, so consumers never need pigeon installed.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_device_insights',
    kotlinOut: 'android/src/main/kotlin/dev/favad/flutter_device_insights/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.favad.flutter_device_insights'),
    swiftOut: 'ios/flutter_device_insights/Sources/flutter_device_insights/Messages.g.swift',
  ),
)
/// Mirrors the public `BatteryStatus`. Pigeon enums cross the wire by index, so
/// both sides must be regenerated together (they ship in one package version).
enum BatteryStatusMessage { charging, discharging, full, notCharging, unknown }

/// Mirrors the public `ThermalStatus`.
enum ThermalStatusMessage { none, light, moderate, severe, critical, emergency, shutdown, unknown }

class BatteryStateMessage {
  BatteryStateMessage({required this.level, required this.status});

  /// Charge percentage, 0-100.
  final int level;
  final BatteryStatusMessage status;
}

@HostApi()
abstract class DeviceInsightsHostApi {
  /// Throws a `FlutterError('UNAVAILABLE', ...)` on the native side when the
  /// device does not report a level.
  int getBatteryLevel();

  String getDeviceModel();

  /// Throws `NO_ACTIVITY` when no settings screen can be resolved.
  void openAppSettings();

  /// Total size in bytes of the app's cache directory. The native side walks
  /// the whole tree, so the cost grows with the number of files. It runs on a
  /// serial background queue (not the platform thread), so a large cache cannot
  /// drop frames. Throws `UNAVAILABLE` when the directory cannot be resolved.
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  int getCacheSizeBytes();
}

@EventChannelApi()
abstract class DeviceInsightsEvents {
  BatteryStateMessage batteryState();

  ThermalStatusMessage thermalStatus();
}
