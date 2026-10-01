# Progress

Started: 2026-10-01

## Week 1: Channel fundamentals (Kotlin)
- [x] MethodChannel: getBatteryLevel (code written, debug APK compiles)
- [x] MethodChannel: getDeviceModel (code written, debug APK compiles)
- [x] MethodChannel: openAppSettings (code written, debug APK compiles)
- [x] Error path (result.error, notImplemented, PlatformException) with 8 Dart unit tests
- [x] Threading notes written in NOTES.md
- [ ] Run the example on a real Android phone and confirm all three buttons
- [x] Run `flutter test integration_test` on the device (I2302, Android 16: 2/2 passed, 2026-10-01)

## Week 2: EventChannel and lifecycle
- [x] Battery state EventChannel with BroadcastReceiver (code written, compiles, 12 Dart tests pass)
- [x] onListen/onCancel unregister verified on device via logcat (I2302, 2026-10-01: 5 registrations, 5 matching unregister/remove lines)
- [x] Second stream: thermal status (code written, compiles)
- [x] Run new stream integration tests on the I2302 (5/5 passed, 2026-10-01)
- [ ] Toggle "Listen to streams" in the example app and watch logcat

## Week 3: Plugin structure and Pigeon
- [x] Code moved into plugin (FlutterPlugin, ActivityAware; Activity reference cleared on every detach)
- [x] Pigeon API defined and generated (Dart + Kotlin): `@HostApi` for 3 methods, `@EventChannelApi` for 2 streams
- [x] Raw vs Pigeon comparison in README (measured line counts)
- [x] 11 Dart tests pass; analyze clean; 5/5 integration tests pass on the I2302 with Pigeon (2026-10-01); register/unregister pairs still match
- [ ] `openAppSettings` through the Activity checked by hand on the phone
- [ ] Did not use `@async` (all three host methods are cheap and sync; revisit if one blocks)

## Week 4: Swift basics
- [x] Swift Pigeon output generated; iOS implementation written (host API + battery and thermal streams)
- [x] Dart analyze clean and 11 Dart tests still pass after regenerating
- [x] Compiles in CI on macos-latest: `iOS build` workflow green on b9e8f64 (2026-10-02), including `flutter build ios --debug --no-codesign` with the Swift code
- [ ] Not run or device-tested on iOS; claim "compiles in CI" at most, never "tested on iOS"

## Week 5: Testing and quality
- [x] Dart channel tests (13: host API, error mapping, stream lifecycle)
- [x] Kotlin unit tests: 28 pass locally (battery handler 12, thermal 3, plugin 13) with JUnit + mockito-kotlin; stale template test replaced
- [x] `.github/workflows/ci.yml` written (analyze, Dart tests, example APK, Kotlin tests); not run yet
- [x] Advanced topic: Pigeon `@TaskQueue` (serial background thread) on a new `getCacheSizeBytes` method (Kotlin, Swift, Dart written; 4 new Kotlin tests, 2 new Dart tests, 2 integration tests added; see NOTES.md)
- [x] `flutter test integration_test` on the I2302: 7/7 pass, including the 2 MiB write-then-count test (2026-10-02)
- [x] `getCacheSizeBytes` confirmed off the main thread on the I2302 (`flutter-worker-0`, via a temporary log, removed; no automated thread assertion)
- [ ] Swift `getCacheSizeBytes` not compiled (no toolchain; CI has not run)
- [x] CI green with badges: `CI` (analyze, 13 Dart tests, example APK, 28 Kotlin tests) and `iOS build` both succeeded on b9e8f64. Repo: https://github.com/favadthottathil/flutter_device_insights (public)
- Gaps: Thermal API 29+ listener path is not unit-tested (JVM SDK_INT is 0); only covered on device. `dart format` would change 8 files, so no format gate yet.

## Week 6: Ship
- [x] README refreshed (iOS stated as untested, Swift output, cache size); CHANGELOG 0.1.0 written; version set to 0.1.0
- [ ] Demo GIF (not made: needs a screen recording plus a converter such as ffmpeg, which is not installed here)
- [x] `flutter pub publish --dry-run`: found and fixed a real error (generated code imports `meta`, now a dependency). Remaining: 1 warning, no `repository` field (GitHub URL unknown)
- [x] LICENSE: MIT, "Copyright (c) 2026 Favad" (change the name if it should read differently)
- [x] Git repo at the workspace root, pushed to the public GitHub repo above (branch main)
- [ ] Integrated into a real app (not done: the app is not in this workspace)
- [x] 5 interview answers written in `docs/INTERVIEW.md`, from real events in this project
- [x] v0.1.0 published to pub.dev (https://pub.dev/packages/flutter_device_insights, confirmed via the pub.dev API) and tagged `v0.1.0` on the commit it was published from

## Can claim on resume
Safe now (true today):
- Published a Flutter plugin to pub.dev (flutter_device_insights 0.1.0) with a public GitHub repo. Never put the flutter_metrics_sdk/pub.dev link in job applications; for this plugin, share the GitHub repo link rather than the pub.dev one unless you decide otherwise.
- Built a Flutter plugin bridging Dart to native Android (Kotlin) with MethodChannel, EventChannel and Pigeon-generated type-safe APIs, tested on a physical Android 16 device.
- Implemented lifecycle-safe event streams (BroadcastReceiver registered on first listener, released on last cancel; 5/5 register/unregister pairs checked in logcat) and moved blocking disk work onto a Pigeon TaskQueue background thread (confirmed off the main thread).
- Unit-tested the channel layer: 13 Dart tests, 28 Kotlin tests, 7 on-device integration tests.
- Wrote a Swift implementation of the same API (basic level) that compiles in GitHub Actions on macOS.
- Set up GitHub Actions CI for the plugin (analyze, Dart tests, Kotlin unit tests, Android and iOS builds), green on the public repo.

Do not claim yet:
- "iOS tested" or "iOS support": it compiles in CI but was never run.
- "CI/CD pipeline": this is CI only; there is no release automation for the plugin.
- "Integrated into a production app": not done.
