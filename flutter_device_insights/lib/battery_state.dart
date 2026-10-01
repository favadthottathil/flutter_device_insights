import 'package:flutter/foundation.dart';

enum BatteryStatus {
  charging,
  discharging,
  full,
  notCharging,
  unknown;

  static final Map<String, BatteryStatus> _byName = values.asNameMap();

  /// Parses the name sent by the native side; unrecognised names map to
  /// [unknown] so a newer native build never breaks an older Dart build.
  static BatteryStatus fromName(Object? name) => _byName[name] ?? unknown;
}

@immutable
class BatteryState {
  const BatteryState({required this.level, required this.status});

  /// Charge percentage in the range 0-100.
  final int level;
  final BatteryStatus status;

  @override
  bool operator ==(Object other) =>
      other is BatteryState && other.level == level && other.status == status;

  @override
  int get hashCode => Object.hash(level, status);

  @override
  String toString() => 'BatteryState($level%, ${status.name})';
}
