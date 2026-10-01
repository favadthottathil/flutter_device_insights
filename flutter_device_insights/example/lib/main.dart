import 'package:flutter/material.dart';
import 'package:flutter_device_insights/flutter_device_insights.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _InsightsPage());
  }
}

class _InsightsPage extends StatefulWidget {
  const _InsightsPage();

  @override
  State<_InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<_InsightsPage> {
  final _plugin = FlutterDeviceInsights();
  // Only the result text rebuilds when a call completes, not the whole page.
  final _output = ValueNotifier<String>('Tap a button');
  // Removing the StreamBuilders below cancels their subscriptions, which makes
  // the native side unregister. Watch: adb logcat -s DeviceInsights
  final _listening = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _output.dispose();
    _listening.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Object?> Function() call, String label) async {
    try {
      final value = await call();
      _output.value = value == null ? '$label: done' : '$label: $value';
    } on DeviceInsightsException catch (e) {
      _output.value = '$label failed: ${e.code} (${e.message})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device insights')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => _run(_plugin.getBatteryLevel, 'Battery %'),
              child: const Text('Get battery level'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _run(_plugin.getDeviceModel, 'Model'),
              child: const Text('Get device model'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _run(_plugin.getCacheSizeBytes, 'Cache bytes'),
              child: const Text('Get cache size'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _run(_plugin.openAppSettings, 'Settings'),
              child: const Text('Open app settings'),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<String>(
              valueListenable: _output,
              builder: (context, text, _) => Text(text, textAlign: TextAlign.center),
            ),
            const Divider(height: 32),
            ValueListenableBuilder<bool>(
              valueListenable: _listening,
              builder: (context, listening, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: const Text('Listen to streams'),
                    value: listening,
                    onChanged: (value) => _listening.value = value,
                  ),
                  if (listening) ...[
                    _StreamText<BatteryState>(
                      label: 'Battery',
                      stream: _plugin.batteryStateStream,
                    ),
                    _StreamText<ThermalStatus>(
                      label: 'Thermal',
                      stream: _plugin.thermalStatusStream,
                    ),
                  ] else
                    const Text('Not listening', textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamText<T> extends StatelessWidget {
  const _StreamText({required this.label, required this.stream});

  final String label;
  final Stream<T> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        final text = snapshot.hasError
            ? '$label error: ${snapshot.error}'
            : '$label: ${snapshot.hasData ? snapshot.data : 'waiting...'}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, textAlign: TextAlign.center),
        );
      },
    );
  }
}
