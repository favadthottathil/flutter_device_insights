import 'package:flutter/services.dart';
import 'package:flutter_device_insights/device_insights_exception.dart';
import 'package:flutter_device_insights/flutter_device_insights_pigeon.dart';
import 'package:flutter_device_insights/src/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pigeon's own test handler is deprecated; the supported way is to fake the
/// generated Dart class, which `PigeonFlutterDeviceInsights` accepts.
class _FakeHostApi implements DeviceInsightsHostApi {
  Future<int> Function() battery = () async => 87;
  Future<String> Function() model = () async => 'Google Pixel 8';
  Future<void> Function() settings = () async {};
  Future<int> Function() cacheSize = () async => 4096;

  @override
  Future<int> getBatteryLevel() => battery();

  @override
  Future<int> getCacheSizeBytes() => cacheSize();

  @override
  Future<String> getDeviceModel() => model();

  @override
  Future<void> openAppSettings() => settings();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TypeMatcher<DeviceInsightsException> _exception(String code) =>
    isA<DeviceInsightsException>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakeHostApi host;
  late PigeonFlutterDeviceInsights platform;

  setUp(() {
    host = _FakeHostApi();
    platform = PigeonFlutterDeviceInsights(hostApi: host);
  });

  group('host api', () {
    test('returns native values', () async {
      expect(await platform.getBatteryLevel(), 87);
      expect(await platform.getDeviceModel(), 'Google Pixel 8');
    });

    test('getCacheSizeBytes returns the native byte count', () async {
      expect(await platform.getCacheSizeBytes(), 4096);
    });

    test('getCacheSizeBytes maps a native UNAVAILABLE', () {
      host.cacheSize = () async => throw PlatformException(code: 'UNAVAILABLE', message: 'no cache dir');
      expect(platform.getCacheSizeBytes(), throwsA(_exception('UNAVAILABLE')));
    });

    test('openAppSettings reaches native', () async {
      var called = false;
      host.settings = () async => called = true;
      await platform.openAppSettings();
      expect(called, isTrue);
    });

    test('a native FlutterError keeps its code and message', () {
      host.battery = () async => throw PlatformException(code: 'UNAVAILABLE', message: 'no battery');
      expect(
        platform.getBatteryLevel(),
        throwsA(_exception('UNAVAILABLE').having((e) => e.message, 'message', 'no battery')),
      );
    });

    test('no native handler maps to NOT_IMPLEMENTED', () {
      // The real generated class with nothing listening: Pigeon reports an
      // unanswered channel as `channel-error`.
      expect(
        PigeonFlutterDeviceInsights().getBatteryLevel(),
        throwsA(_exception('NOT_IMPLEMENTED')),
      );
    });

    test('a null reply for a non-null result maps to NULL_RESULT', () {
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.flutter_device_insights.DeviceInsightsHostApi.getDeviceModel',
        DeviceInsightsHostApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler<Object?>(channel, (_) async => <Object?>[null]);
      addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
      expect(PigeonFlutterDeviceInsights().getDeviceModel(), throwsA(_exception('NULL_RESULT')));
    });
  });

  group('streams', () {
    final batteryChannel = EventChannel(
      'dev.flutter.pigeon.flutter_device_insights.DeviceInsightsEvents.batteryState',
      pigeonMethodCodec,
    );
    final thermalChannel = EventChannel(
      'dev.flutter.pigeon.flutter_device_insights.DeviceInsightsEvents.thermalStatus',
      pigeonMethodCodec,
    );

    tearDown(() {
      messenger.setMockStreamHandler(batteryChannel, null);
      messenger.setMockStreamHandler(thermalChannel, null);
    });

    test('battery events become BatteryState', () {
      messenger.setMockStreamHandler(
        batteryChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(BatteryStateMessage(level: 80, status: BatteryStatusMessage.charging));
            events.success(BatteryStateMessage(level: 79, status: BatteryStatusMessage.unknown));
            events.endOfStream();
          },
        ),
      );
      expect(
        platform.batteryStateStream.map((s) => '${s.level}:${s.status.name}'),
        emitsInOrder(['80:charging', '79:unknown', emitsDone]),
      );
    });

    test('thermal events become ThermalStatus', () {
      messenger.setMockStreamHandler(
        thermalChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(ThermalStatusMessage.none);
            events.success(ThermalStatusMessage.severe);
            events.endOfStream();
          },
        ),
      );
      expect(
        platform.thermalStatusStream.map((s) => s.name),
        emitsInOrder(['none', 'severe', emitsDone]),
      );
    });

    test('stream errors map to DeviceInsightsException', () {
      messenger.setMockStreamHandler(
        thermalChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) => events.error(code: 'UNAVAILABLE', message: 'nope'),
        ),
      );
      expect(
        platform.thermalStatusStream,
        emitsError(_exception('UNAVAILABLE').having((e) => e.message, 'message', 'nope')),
      );
    });

    test('native listens once for many listeners and cancels after the last', () async {
      var listens = 0;
      var cancels = 0;
      messenger.setMockStreamHandler(
        batteryChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            listens++;
            events.success(BatteryStateMessage(level: 50, status: BatteryStatusMessage.full));
          },
          onCancel: (arguments) => cancels++,
        ),
      );

      final first = platform.batteryStateStream.listen((_) {});
      final second = platform.batteryStateStream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(listens, 1);

      await first.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(cancels, 0, reason: 'a listener is still subscribed');

      await second.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(cancels, 1);
    });
  });
}
