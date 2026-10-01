import 'package:flutter_device_insights/flutter_device_insights.dart';
import 'package:flutter_device_insights/flutter_device_insights_pigeon.dart';
import 'package:flutter_device_insights/flutter_device_insights_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterDeviceInsightsPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDeviceInsightsPlatform {
  @override
  Future<int> getBatteryLevel() => Future.value(42);

  @override
  Future<String> getDeviceModel() => Future.value('Test Model');

  @override
  Future<int> getCacheSizeBytes() => Future.value(2048);

  @override
  Future<void> openAppSettings() => Future.value();

  @override
  Stream<BatteryState> get batteryStateStream =>
      Stream.value(const BatteryState(level: 42, status: BatteryStatus.charging));

  @override
  Stream<ThermalStatus> get thermalStatusStream => Stream.value(ThermalStatus.light);
}

void main() {
  final initialPlatform = FlutterDeviceInsightsPlatform.instance;

  test('$PigeonFlutterDeviceInsights is the default instance', () {
    expect(initialPlatform, isInstanceOf<PigeonFlutterDeviceInsights>());
  });

  test('delegates to the platform instance', () async {
    FlutterDeviceInsightsPlatform.instance = MockFlutterDeviceInsightsPlatform();
    final plugin = FlutterDeviceInsights();

    expect(await plugin.getBatteryLevel(), 42);
    expect(await plugin.getDeviceModel(), 'Test Model');
    expect(await plugin.getCacheSizeBytes(), 2048);
    await plugin.openAppSettings();
    expect(
      await plugin.batteryStateStream.first,
      const BatteryState(level: 42, status: BatteryStatus.charging),
    );
    expect(await plugin.thermalStatusStream.first, ThermalStatus.light);
  });
}
