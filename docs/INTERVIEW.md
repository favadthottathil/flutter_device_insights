# Interview answers (Problem / Action / Result)

Every number and event below comes from this project. If a follow-up goes past what is written here, say so rather than improvise.

## 1. Why Pigeon over raw channels?

- **Problem.** With raw `MethodChannel`/`EventChannel`, method names, map keys and channel names are strings on both sides. A rename on one side fails at runtime, on a device.
- **Action.** I built the plugin on raw channels first (Weeks 1-2), then moved the same API to Pigeon (Week 3) and checked behaviour with the same device integration tests.
- **Result.** Honest finding: Pigeon did not shrink the hand-written code (Dart 103 to 88 lines, Kotlin 119 to 122, plus a 48-line definition). What it removed is the disagreement class of bug: renaming a field now fails to compile in Kotlin. Costs I hit: enums cross the wire by index (safe only because both sides ship in one version), and the generated stream `register` does not return the channel, so handlers cannot be unset on detach.

## 2. How do you prevent a stream leak?

- **Problem.** A battery stream backed by a `BroadcastReceiver` leaks the receiver if `onCancel` never runs. Detaching an engine does not call `onCancel`, and the generated Dart `batteryState()` creates a new `EventChannel` per call, so each Dart listener could register its own receiver.
- **Action.** Register in `onListen`, unregister in `onCancel`. The Dart side builds the stream once and reuses it, so N listeners cost one native receiver. The plugin calls an idempotent `stop()` on engine detach. A second `onListen` releases the first receiver, and `stop()` tolerates a receiver that is already gone.
- **Result.** On the I2302, 5 registrations matched 5 unregister lines in logcat. 12 Kotlin tests cover cancel, repeated stop, double listen and the already-unregistered case.

## 3. What is the threading model?

- **Problem.** Channel handlers run on the platform (main) thread. Anything that blocks there drops frames.
- **Action.** Most calls are cheap and stay on the main thread. `getCacheSizeBytes` walks the cache directory, so it is annotated with Pigeon `@TaskQueue(serialBackgroundThread)`. It stays a plain synchronous method, not `@async`, because it blocks and returns a value. Because it now reads state off the main thread, `applicationContext` is `@Volatile`.
- **Result.** I confirmed on the device with a temporary log that it runs on `flutter-worker-0` and not the main looper. Limits: the queue is serial, so rapid calls run full walks one after another, and no automated test asserts the thread.

## 4. How do you handle plugin errors?

- **Problem.** `PlatformException` codes from native are free-form, and Pigeon adds its own (`channel-error`, `null-error`). Callers should not parse those.
- **Action.** Native throws `FlutterError` with a small set of stable codes (`UNAVAILABLE`, `NO_ACTIVITY`, `NO_CONTEXT`). The Dart layer maps everything to one `DeviceInsightsException`, translating `channel-error` to `NOT_IMPLEMENTED` and `null-error` to `NULL_RESULT`. Streams map their errors the same way.
- **Result.** One error type in the public API. Known gap: a missing native stream handler does not reach the stream as an error. `EventChannel` reports it through `FlutterError.reportError` and the stream stays silent. iOS `openAppSettings` cannot report failure at all, because `UIApplication.open` completes after the reply.

## 5. How did you test a plugin?

- **Problem.** The code that matters runs in native platform APIs, which unit tests on the JVM cannot reach.
- **Action.** Three layers. Dart: 13 tests against a fake of the generated host API, plus mock stream handlers. Kotlin: 28 JVM tests with Mockito for the handlers and plugin lifecycle (needed `isReturnDefaultValues` because Android classes are stubs). Device: 7 integration tests on a real phone.
- **Result.** All pass locally. Bugs the layers caught: a Mockito stubbing mistake (a mock created inside `whenever(...)`), and a wrong test assumption that `Directory.systemTemp` is the cache directory (on Android it is `code_cache`; the plugin was correct). Gaps I state up front: the Android 10+ thermal path is only covered on a device, the Swift code compiles in CI on a macOS runner but was never run on a simulator or device.
