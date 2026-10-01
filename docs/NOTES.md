# Notes

## Threading rules (Week 1)
- Channel handlers are invoked on the platform thread, which is the Android main (UI) thread. Blocking work in `onMethodCall` freezes the UI.
- `Result.success/error/notImplemented` must be called on the main thread, and exactly once. Calling it twice throws. Not calling it leaves the Dart `Future` hanging forever.
- For slow work: run it off the main thread (executor or coroutine on `Dispatchers.IO`), then post the reply back with `Handler(Looper.getMainLooper())`. Week 2 covers this.
- The Dart side is never blocked: `invokeMethod` returns a `Future`, and the Dart UI isolate keeps rendering while native works.
- Our three Week 1 methods (battery property, `Build.*`, `startActivity`) are all cheap, so they stay on the main thread.

## Error shapes on the Dart side
| Native call | Dart sees |
|---|---|
| `result.success(v)` | `v` (null for `void`) |
| `result.error(code, msg, details)` | `PlatformException(code, msg, details)` |
| `result.notImplemented()` | `MissingPluginException` |
| no handler registered (plugin not attached, wrong channel name) | `MissingPluginException` |

`MethodChannelFlutterDeviceInsights._invoke` maps both exception types to `DeviceInsightsException`, so callers catch one type.

## Why `applicationContext`, not an Activity
`openAppSettings` runs from the application context with `FLAG_ACTIVITY_NEW_TASK`, which avoids `ActivityAware` for now. Week 3 moves to `ActivityAware` when an Activity is needed.

## Pigeon error shapes (Week 3, replaces the table above for the current code)
| Native | Dart sees (before mapping) | Public API |
|---|---|---|
| `throw FlutterError(code, msg, details)` | `PlatformException(code, msg, details)` | `DeviceInsightsException(code, msg)` |
| no handler registered | `PlatformException('channel-error')` | `NOT_IMPLEMENTED` |
| null for a non-null return | `PlatformException('null-error')` | `NULL_RESULT` |
| `sink.error(...)` | stream error `PlatformException` | `DeviceInsightsException` |
| no stream handler | silent stream (reported via `FlutterError.reportError`) | n/a |

## iOS (Week 4)
Swift implements the same Pigeon API. Compiled in CI only (`.github/workflows/ios.yml`); never run on a simulator or device.
- Swift Pigeon types are internal and `register(...)` again does not return the channel, so `detachFromEngine` calls `stop()` on both handlers.
- Observers (`UIDevice` battery notifications, `ProcessInfo.thermalStateDidChangeNotification`) use `queue: .main` so the `FlutterEventSink` is called on the platform thread. Removed in `onCancel`/`stop()`, same three cleanup paths as Android.
- UIKit does not replay current state on subscribe (Android's battery broadcast is sticky), so `onListen` emits the current value itself.
- `UIDevice.isBatteryMonitoringEnabled` is app-global: each user restores what it found.
- `openAppSettings` cannot report failure: `UIApplication.open` completes after the reply.
- Unverified on iOS: that `batteryLevel` is valid immediately after enabling monitoring in `getBatteryLevel`.

## ActivityAware (Week 3)
`openAppSettings` launches from the Activity when one is attached (opens in the app's task) and falls back to the application context with `FLAG_ACTIVITY_NEW_TASK` otherwise. The plugin nulls its Activity reference in `onDetachedFromActivity` and `onDetachedFromActivityForConfigChanges` so a rotation or destroyed Activity is not retained.

## Stream lifecycle (Week 2)
- `EventChannel.receiveBroadcastStream()` calls native `onListen` on the first Dart listener and `onCancel` when the last one cancels. The stream is built once (`late final` in `MethodChannelFlutterDeviceInsights`) so many listeners share one native receiver. A new stream per getter call would register a receiver per call.
- Android `BroadcastReceiver` registered in `onListen`, unregistered in `onCancel`. A leaked receiver keeps the Context and `EventSink` alive after Dart stopped listening.
- Three cleanup paths, all idempotent through `stop()`:
  1. `onCancel` (normal: Dart cancelled).
  2. A second `onListen` without `onCancel` (engine replaced the sink): `stop()` runs first.
  3. `onDetachedFromEngine`: `setStreamHandler(null)` does NOT call `onCancel`, so the plugin calls `stop()` itself.
- `ACTION_BATTERY_CHANGED` is sticky: registering returns the current value, so the first event arrives immediately. It also fires for voltage/temperature changes, so the handler de-duplicates on (level, status).
- Android 14+ requires a receiver export flag: `RECEIVER_NOT_EXPORTED` for this system broadcast.
- Thermal: `PowerManager.addThermalStatusListener` (API 29+) on `context.mainExecutor`, so the `EventSink` is only used on the main thread. Below API 29 the handler sends `UNAVAILABLE` then `endOfStream`.
- Errors: `events.error(...)` arrives as a `PlatformException` stream error (mapped to `DeviceInsightsException`). A missing native handler does NOT arrive as a stream error: `EventChannel` reports the failed `listen` via `FlutterError.reportError` and the stream stays silent. This is what iOS does until Week 4.
- Verify lifecycle: `adb logcat -s DeviceInsights:I`; expect "registered" on listen and "unregistered/removed" on cancel.
- Lifecycle logs use `Log.i`, not `Log.d`: on the iQOO I2302 (Android 16) `Log.d` lines from the app never appeared in logcat, while `Log.i` did. The cause is likely a vendor log filter; I did not confirm it.

## TaskQueue (Week 5 advanced topic)
Nothing in the original API blocked, so `getCacheSizeBytes` was added as the first method that does: it walks the whole cache directory, so its cost grows with the file count.

- **Mechanism.** `@TaskQueue(type: TaskQueueType.serialBackgroundThread)` on the Pigeon method. The generated code calls `binaryMessenger.makeBackgroundTaskQueue()` (Kotlin) / `makeBackgroundTaskQueue?()` (Swift) and passes the queue to that one channel only. The other host methods stay on the platform thread. I read this in the generated output; I did not write the queue code by hand.
- **Why not `@async`.** The native code is blocking and returns a value, so it stays a plain synchronous method running on the queue. `@async` is for work that completes later through a callback (a listener, a network client). It is still unused here.
- **Serial, not concurrent.** Calls are queued one after another, so ten rapid calls mean ten full walks in sequence. Dart callers that need one result should share a single in-flight future; this plugin does not.
- **Thread-safety consequence.** The handler now reads `applicationContext` off the main thread while attach/detach write it on the main thread, so the field is `@Volatile`. Reading `cacheDir` into a local first avoids a detach landing between two reads.
- **Walk behaviour.** Unreadable or concurrently deleted entries are skipped, not errors. Symlinked directories are not specially handled; cache directories do not normally contain them.
- **Verified on the I2302.** The integration test writes two 1 MiB files into the cache and the plugin reports exactly +2 MiB. **Thread verified too (2026-10-02):** a temporary `Log.i` showed all three calls running on `flutter-worker-0` with `Looper.myLooper() != mainLooper`; the log line was removed afterwards. No automated test asserts the thread, so a regression there would not be caught.
- **Test pitfall.** The first version of that test wrote to `Directory.systemTemp` and failed with 0 bytes. On Android that is `code_cache`, not `cache`. Use `path_provider`'s `getTemporaryDirectory()`, which is `cacheDir` (Android) and `Library/Caches` (iOS).
- **Alternative not taken.** Coroutines (`Dispatchers.IO`, then a main-thread reply) would also work but need a dependency; the task queue is built into the engine.
