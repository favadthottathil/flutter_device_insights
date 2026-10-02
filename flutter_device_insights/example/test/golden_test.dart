// Golden tests for the Device Insights example app.
//
// These tests capture pixel-perfect snapshots of key UI states so that
// accidental visual regressions are caught in CI without a real device.
//
// Run once to generate the reference images:
//   flutter test --update-goldens test/golden_test.dart   (from example/)
//
// Run normally (comparison mode):
//   flutter test test/golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Minimal self-contained UI for golden tests.
//
// We do NOT import main.dart because _InsightsPage calls the real plugin via
// platform channels, which would fail in a headless widget test environment.
// Instead we build a thin copy of the same visual structure driven by plain
// value parameters so there are zero platform-channel calls.
// ──────────────────────────────────────────────────────────────────────────────

/// A standalone widget that mirrors the look of _InsightsPage without
/// touching any platform channel. All values come in as constructor params.
class InsightsPageStub extends StatelessWidget {
  const InsightsPageStub({
    super.key,
    this.outputText = 'Tap a button',
    this.listening = false,
    this.batteryText,
    this.thermalText,
  });

  final String outputText;
  final bool listening;
  final String? batteryText;
  final String? thermalText;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Disable overscroll glow so goldens are deterministic across platforms.
      scrollBehavior: const ScrollBehavior().copyWith(overscroll: false),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('Device insights')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {},
                child: const Text('Get battery level'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {},
                child: const Text('Get device model'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {},
                child: const Text('Get cache size'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {},
                child: const Text('Open app settings'),
              ),
              const SizedBox(height: 24),
              Text(outputText, textAlign: TextAlign.center),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('Listen to streams'),
                value: listening,
                onChanged: (_) {},
              ),
              if (listening) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    batteryText ?? 'Battery: waiting...',
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    thermalText ?? 'Thermal: waiting...',
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else
                const Text('Not listening', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Test helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Pumps [widget] in a 390 × 844 logical-pixel viewport (iPhone 14 size) so
/// the golden is device-independent and the layout matches the demo GIF.
Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

// ──────────────────────────────────────────────────────────────────────────────
// Golden tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('golden – initial state (tap a button)', (tester) async {
    await _pump(tester, const InsightsPageStub());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/initial_state.png'),
    );
  });

  testWidgets('golden – result shown after a call', (tester) async {
    await _pump(
      tester,
      const InsightsPageStub(outputText: 'Battery %: 78'),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/result_battery.png'),
    );
  });

  testWidgets('golden – error result shown', (tester) async {
    await _pump(
      tester,
      const InsightsPageStub(
        outputText: 'Battery % failed: UNAVAILABLE (Battery level not reported)',
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/result_error.png'),
    );
  });

  testWidgets('golden – streams section hidden (not listening)', (tester) async {
    await _pump(
      tester,
      const InsightsPageStub(listening: false),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/streams_off.png'),
    );
  });

  testWidgets('golden – streams section visible (listening)', (tester) async {
    await _pump(
      tester,
      const InsightsPageStub(
        listening: true,
        batteryText: 'Battery: BatteryState(level: 78, status: BatteryStatus.charging)',
        thermalText: 'Thermal: ThermalStatus.none',
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/streams_on.png'),
    );
  });
}
