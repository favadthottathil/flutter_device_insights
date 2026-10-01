# Pigeon definitions

`messages.dart` is the single source of truth for the Dart <-> native contract.

```
dart run pigeon --input pigeons/messages.dart
```

Generates `lib/src/messages.g.dart`, the Kotlin `Messages.g.kt` and the Swift
`Messages.g.swift` (under `ios/flutter_device_insights/Sources/`).
