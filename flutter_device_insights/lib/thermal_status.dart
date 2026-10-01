/// Device thermal state, ordered from coolest to hottest.
enum ThermalStatus {
  none,
  light,
  moderate,
  severe,
  critical,
  emergency,
  shutdown,
  unknown;

  static final Map<String, ThermalStatus> _byName = values.asNameMap();

  /// Parses the name sent by the native side; unrecognised names map to
  /// [unknown].
  static ThermalStatus fromName(Object? name) => _byName[name] ?? unknown;
}
