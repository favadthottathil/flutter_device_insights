/// Thrown when a native call fails or the platform has no implementation.
class DeviceInsightsException implements Exception {
  const DeviceInsightsException({required this.code, this.message});

  /// Machine-readable code, e.g. `UNAVAILABLE`, `NO_ACTIVITY`,
  /// `NOT_IMPLEMENTED` or `NULL_RESULT`.
  final String code;

  final String? message;

  @override
  String toString() => 'DeviceInsightsException($code, $message)';
}
