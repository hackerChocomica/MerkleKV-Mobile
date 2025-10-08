# flutter_demo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Rich Console (Streaming Logger UI)

The demo includes a colorful, filterable console widget that renders logs from the MQTT connection stream.

Usage:

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';
import 'widgets/rich_console_view.dart';

// Create a streaming logger (UI-only: disable console mirroring)
final logger = StreamConnectionLogger(tag: 'MQTT-Core', mirrorToConsole: false);

// Wire into the MQTT client and lifecycle (optional, defaults exist)
final mqtt = MqttClientImpl(config, logger: logger);
final lifecycle = DefaultConnectionLifecycleManager(
	config: config,
	mqttClient: mqtt,
	logger: logger,
);

// Drop in the widget anywhere in your UI
RichConsoleView(
	logger: logger,
	levels: {'DEBUG', 'INFO', 'WARN', 'ERROR'},
	tag: 'MQTT-Core',
)
```

Press the Clear button to clear the in-memory buffer and the view.
