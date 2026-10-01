# Native Platform Channels Plan (6 weeks, Kotlin first, Swift basics)

**End deliverable:** a public Flutter plugin repo, `flutter_device_insights`, using MethodChannel, EventChannel and Pigeon. Kotlin implementation, basic Swift implementation, tests and CI, an example app, and a README with a demo GIF. Publishing to pub.dev is optional. Use the GitHub link in applications, not the flutter_metrics_sdk pub.dev link.

**Why this plugin:** battery state, thermal state and connectivity changes are small enough to finish, and they exercise every channel type: one-shot calls, a stream, and typed APIs.

## Time budget
About 8-10 hrs/week. Riverpod (roadmap item 4) can run in parallel at about 1 hr/week. The Play/App Store half of item 1 slips to after this plan.

## Week 1: Channel fundamentals (Kotlin)
- Learn the platform channel architecture (binary messenger, codecs, threading), the main thread rule on Android, and `MissingPluginException`.
- Build a `MethodChannel` with 3 methods: `getBatteryLevel`, `getDeviceModel`, `openAppSettings`.
- Cover the error path: `result.error`, `notImplemented`, and `PlatformException` handling in Dart.
- **Deliverable:** working example app plus a short notes file on the threading rules (`NOTES.md`).

## Week 2: EventChannel and lifecycle
- Build an `EventChannel` streaming battery state changes with a `BroadcastReceiver`.
- Implement `StreamHandler.onListen`/`onCancel` properly and unregister the receiver (leaks here are a classic interview question).
- Dart side: a `Stream` wrapper; cancel the subscription on dispose.
- Add a second stream (connectivity or thermal status).
- Coroutines: `Dispatchers.IO` for work, then post the result back to the main thread.
- **Deliverable:** stream demo with a leak-free lifecycle, verified by profiler or register/unregister logging.

## Week 3: Plugin structure and Pigeon
- Move the Week 1-2 code into the plugin, using `FlutterPlugin` and `ActivityAware`.
- Add Pigeon: define the API in `pigeons/messages.dart`, generate Dart and Kotlin, replace string method names with typed data classes and enums, use `@async` and `@EventChannelApi` where supported.
- Compare the raw-channel and Pigeon versions in the README.
- **Deliverable:** plugin on Pigeon with the Kotlin side complete.

## Week 4: Swift basics
- Learn only what the plugin needs: Swift syntax and optionals, `FlutterPlugin` registration, `UIDevice.batteryLevel`, `ProcessInfo.thermalState`, `FlutterStreamHandler`.
- Implement the same Pigeon API on iOS.
- No Mac or Apple account: use a `macos-latest` GitHub runner with `flutter build ios --no-codesign`, or a borrowed Mac. Without a simulator, say "iOS implementation compiled in CI, not device-tested".
- **Deliverable:** Swift implementation compiling in CI.

## Week 5: Testing, quality, advanced topics
- Dart unit tests that mock the channel with `TestDefaultBinaryMessengerBinding` (or the Pigeon test API).
- Kotlin unit tests with JUnit and Mockito for handler logic.
- Pick one advanced topic: background isolates and `BinaryMessenger.TaskQueue`, `PlatformView` basics, or FFI/JNI vs channels.
- CI workflow reusing the item 1 setup: analyze, test, example APK build.
- **Deliverable:** green CI with a badge (public repo, unlike Navarasami).

## Week 6: Ship and package
- README, API docs, CHANGELOG, example app, demo GIF.
- `flutter pub publish --dry-run`; publish only if wanted.
- Integrate into one real app (for example Navarasami) behind a small feature, such as device info in Crashlytics custom keys.
- Prepare 5 Problem/Action/Result interview answers: why Pigeon over raw channels, preventing a stream leak, the threading model, handling plugin errors, testing a plugin.
- **Deliverable:** release v0.1.0 and the resume bullets below.

## Resume bullets (claim only after done)
- Built and published a Flutter plugin bridging Dart to native Android (Kotlin) and iOS (Swift) with MethodChannel, EventChannel and Pigeon-generated type-safe APIs.
- Implemented lifecycle-safe event streams (BroadcastReceiver registration/cleanup) and unit-tested the channel layer in Dart and Kotlin.
- Do not write "production iOS" or "tested on iOS devices" unless true.
- Skills line: Kotlin, Swift (basics), platform channels, Pigeon, plugin development.

## Risks and rules
- Kotlin first. Don't start Swift before Week 4 and don't go deep on it.
- If behind, cut the second stream and the advanced topic, not the tests or the Pigeon step.
- Test on a real Android phone from Week 1.
