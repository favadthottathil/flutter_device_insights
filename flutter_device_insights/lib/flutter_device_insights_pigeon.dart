import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'battery_state.dart';
import 'device_insights_exception.dart';
import 'flutter_device_insights_platform_interface.dart';
import 'src/messages.g.dart' as messages;
import 'thermal_status.dart';

/// [FlutterDeviceInsightsPlatform] backed by the Pigeon-generated channels in
/// `src/messages.g.dart`. The channel names, codecs and (de)serialisation are
/// generated from `pigeons/messages.dart`, so this class only maps generated
/// types and errors to the public API.
class PigeonFlutterDeviceInsights extends FlutterDeviceInsightsPlatform {
  PigeonFlutterDeviceInsights({@visibleForTesting messages.DeviceInsightsHostApi? hostApi})
    : _hostApi = hostApi ?? messages.DeviceInsightsHostApi();

  final messages.DeviceInsightsHostApi _hostApi;

  // Built once and shared. The generated `batteryState()` creates a new
  // EventChannel per call, and native `onListen` runs when the first listener
  // subscribes and `onCancel` when the last cancels. N Dart listeners must
  // cost one native receiver, so the stream is created lazily and reused.
  @override
  late final Stream<BatteryState> batteryStateStream = _events(
    messages.batteryState(),
    (message) => BatteryState(
      level: message.level,
      status: BatteryStatus.fromName(message.status.name),
    ),
  );

  @override
  late final Stream<ThermalStatus> thermalStatusStream = _events(
    messages.thermalStatus(),
    (message) => ThermalStatus.fromName(message.name),
  );

  @override
  Future<int> getBatteryLevel() => _call(_hostApi.getBatteryLevel);

  @override
  Future<String> getDeviceModel() => _call(_hostApi.getDeviceModel);

  @override
  Future<int> getCacheSizeBytes() => _call(_hostApi.getCacheSizeBytes);

  @override
  Future<void> openAppSettings() => _call(_hostApi.openAppSettings);

  Future<T> _call<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw _fromPlatformException(e);
    }
  }

  /// Maps generated events to public types and `events.error` payloads to
  /// [DeviceInsightsException]. A missing native handler does NOT surface here:
  /// [EventChannel] reports a failed `listen` through `FlutterError.reportError`
  /// and the stream then never emits.
  Stream<T> _events<M, T>(Stream<M> source, T Function(M message) parse) {
    return source.transform(
      StreamTransformer<M, T>.fromHandlers(
        handleData: (message, sink) => sink.add(parse(message)),
        handleError: (error, stackTrace, sink) {
          sink.addError(
            error is PlatformException ? _fromPlatformException(error) : error,
            stackTrace,
          );
        },
      ),
    );
  }

  /// Pigeon reports its own failures with fixed codes: `channel-error` when no
  /// native handler answers (the old `MissingPluginException`) and `null-error`
  /// when native returns null for a non-null result. Everything else is a
  /// `FlutterError` thrown by the native implementation.
  DeviceInsightsException _fromPlatformException(PlatformException e) => switch (e.code) {
    'channel-error' => DeviceInsightsException(
      code: 'NOT_IMPLEMENTED',
      message: 'Not implemented on this platform: ${e.message}',
    ),
    'null-error' => DeviceInsightsException(code: 'NULL_RESULT', message: e.message),
    _ => DeviceInsightsException(code: e.code, message: e.message),
  };
}
