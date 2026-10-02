# flutter_device_insights

[![CI](https://github.com/favadthottathil/flutter_device_insights/actions/workflows/ci.yml/badge.svg)](https://github.com/favadthottathil/flutter_device_insights/actions/workflows/ci.yml)
[![iOS build](https://github.com/favadthottathil/flutter_device_insights/actions/workflows/ios.yml/badge.svg)](https://github.com/favadthottathil/flutter_device_insights/actions/workflows/ios.yml)

![Device Insights demo running on Android 16](https://raw.githubusercontent.com/favadthottathil/flutter_device_insights/main/demo.gif)

Battery level, device model, cache size, app settings shortcut, and live battery
and thermal streams for Flutter. Android is tested on a real device. The iOS
(Swift) side compiles in CI (`flutter build ios --no-codesign` on a macOS
runner) but has never been run on a simulator or device. Treat iOS behaviour as
untested.

The native contract is defined once in [`pigeons/messages.dart`](pigeons/messages.dart)
and generated for Dart, Kotlin and Swift with [Pigeon](https://pub.dev/packages/pigeon).

```dart
final insights = FlutterDeviceInsights();

final level = await insights.getBatteryLevel();      // 0-100
final model = await insights.getDeviceModel();       // manufacturer + model
final bytes = await insights.getCacheSizeBytes();    // walks the cache dir off the main thread
insights.batteryStateStream.listen(print);           // BatteryState(80%, charging)
insights.thermalStatusStream.listen(print);          // ThermalStatus.light
```

Every failure reaches Dart as a `DeviceInsightsException` with a `code`:
`UNAVAILABLE`, `NO_ACTIVITY`, `NO_CONTEXT`, `NOT_IMPLEMENTED`, `NULL_RESULT`.

## Changing the native API

```
dart run pigeon --input pigeons/messages.dart
```

The generated files (`lib/src/messages.g.dart`, `android/.../Messages.g.kt`,
`ios/.../Messages.g.swift`) are committed, so consumers do not need Pigeon.

## Platform differences

| | Android | iOS |
|---|---|---|
| `getDeviceModel` | `Manufacturer Model` | `Apple <hardware id>`, e.g. `Apple iPhone15,2` (not the marketing name) |
| Battery status | all five values | never `notCharging` |
| Thermal status | seven levels (API 29+) | `none`, `light`, `severe`, `critical` only |
| `getBatteryLevel` | `UNAVAILABLE` if unreported | `UNAVAILABLE` if unknown (always on the simulator) |
| `getCacheSizeBytes` | sum of `File.length()` under `cacheDir` | sum of logical file sizes under `Library/Caches` |
| `openAppSettings` | `NO_ACTIVITY` if unresolvable | fire-and-forget; cannot report a failed open |

## Raw channels vs Pigeon

Weeks 1-2 used raw `MethodChannel`/`EventChannel`; Week 3 moved the same API to
Pigeon. Same behaviour, verified by the same device integration tests.

| | Raw channels | Pigeon |
|---|---|---|
| Method names | strings on both sides (`'getBatteryLevel'`) | generated, one definition |
| Event payload | `Map` with `'level'` / `'status'` keys, cast by hand | `BatteryStateMessage` class, enums |
| Channel names, codecs | hand-written, must match | generated |
| Native return type | any `Object`, checked at runtime | `Long`, `String`, `Unit`, compile-checked |
| Native errors | `result.error(...)` | `throw FlutterError(...)` |
| Null result for a non-null type | hand-written check | `null-error` generated |
| No native handler | `MissingPluginException` | `PlatformException('channel-error')` |
| Hand-written hot path | switch on `call.method` | none, interface methods |

Measured hand-written size (generated files excluded):

| File | Raw | Pigeon |
|---|---|---|
| Dart platform implementation | 103 lines | 88 lines |
| Kotlin plugin class | 119 lines | 122 lines (adds `ActivityAware`) |
| Pigeon definition | 0 | 48 lines |

These were measured in Week 3, before `getCacheSizeBytes` and the Swift side
were added, so they are not re-measured against the current code.

So Pigeon did **not** shrink the hand-written code here; the Dart side lost
the string-keyed parsing but the definition file replaced it. What it removed
is the class of bug where the two sides disagree: renaming a method or field
now fails to compile on Kotlin instead of failing at runtime on a device.

Trade-offs seen in this plugin:

- Pigeon enums cross the wire **by index**. Dart and Kotlin are regenerated
  together and ship in one package version, so that is safe here. The raw
  version sent names and fell back to `unknown` for names it did not know.
- The generated Dart `batteryState()` builds a new `EventChannel` per call, so
  the implementation caches the stream; otherwise each listener would register
  its own native receiver.
- The generated Kotlin `register(...)` for streams does not return the
  `EventChannel`, so the stream handler cannot be unset on detach. The plugin
  calls `stop()` on both handlers instead, which is what releases the native
  listeners.
- `dartTestOut` (Pigeon's Dart test handler) is deprecated in the version used
  here, so the Dart tests fake the generated `DeviceInsightsHostApi` instead.
