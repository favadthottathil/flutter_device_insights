// Runs on a real device/emulator, so it exercises the Kotlin side.
// Run with: flutter test integration_test  (from example/, device attached)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_device_insights/flutter_device_insights.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = FlutterDeviceInsights();

  testWidgets('getDeviceModel returns a non-empty string', (tester) async {
    expect((await plugin.getDeviceModel()).isNotEmpty, true);
  });

  testWidgets('getBatteryLevel is within 0-100', (tester) async {
    expect(await plugin.getBatteryLevel(), inInclusiveRange(0, 100));
  });

  testWidgets('getCacheSizeBytes is never negative', (tester) async {
    expect(await plugin.getCacheSizeBytes(), greaterThanOrEqualTo(0));
  });

  // getTemporaryDirectory is cacheDir on Android and Library/Caches on iOS,
  // the directories getCacheSizeBytes walks. Directory.systemTemp is not: on
  // Android it is code_cache, a sibling directory.
  testWidgets('getCacheSizeBytes counts files written to the cache', (tester) async {
    const payload = 1024 * 1024;
    final cache = await getTemporaryDirectory();
    final dir = await cache.createTemp('insights_cache_');
    addTearDown(() => dir.delete(recursive: true));
    final before = await plugin.getCacheSizeBytes();

    await File('${dir.path}/a.bin').writeAsBytes(Uint8List(payload));
    await Directory('${dir.path}/nested').create();
    await File('${dir.path}/nested/b.bin').writeAsBytes(Uint8List(payload));

    expect(await plugin.getCacheSizeBytes(), before + 2 * payload);
  });

  testWidgets('batteryStateStream emits the current state on listen', (tester) async {
    final state = await plugin.batteryStateStream.first;
    expect(state.level, inInclusiveRange(0, 100));
    expect(state.level, closeTo(await plugin.getBatteryLevel(), 2));
  });

  testWidgets('thermalStatusStream emits the current status on listen', (tester) async {
    final status = await plugin.thermalStatusStream.first;
    expect(status, isNot(ThermalStatus.unknown));
  });

  testWidgets('listen -> cancel -> listen again works (re-registers)', (tester) async {
    for (var i = 0; i < 3; i++) {
      final state = await plugin.batteryStateStream.first;
      expect(state.level, inInclusiveRange(0, 100));
    }
  });
}
