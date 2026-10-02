## 0.1.1

* Added a demo GIF to the README showing the plugin in action on an Android device.

## 0.1.0

First release.

* Host calls: `getBatteryLevel`, `getDeviceModel`, `getCacheSizeBytes`, `openAppSettings`.
* Streams: `batteryStateStream` and `thermalStatusStream`. Both emit the current value on listen. The native receiver is registered on the first Dart listener and released when the last one cancels.
* `getCacheSizeBytes` runs on a Pigeon `@TaskQueue` serial background thread.
* All failures reach Dart as `DeviceInsightsException` with a stable `code`.
* Native contract defined once in `pigeons/messages.dart` and generated for Dart, Kotlin and Swift (Pigeon 29).
* Android: tested on one device (Android 16) with integration tests, plus 28 Kotlin and 13 Dart unit tests.
* iOS: implemented in Swift and compiled in CI, but **not run on a simulator or device**. Behaviour differs from Android; see the README table.
* Thermal status requires Android 10 (API 29); below that the stream errors with `UNAVAILABLE`.
