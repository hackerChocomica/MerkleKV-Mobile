import 'dart:io';
import 'embedded_mqtt_broker.dart';

/// Ensures an MQTT broker is available for integration tests.
/// If no broker is listening on localhost:1883, starts an embedded broker.
class TestBrokerHelper {
  static EmbeddedMqttBroker? _broker;

  static Future<void> ensureBroker({int port = 1883}) async {
    // Honor environment override to require external broker
    final require = Platform.environment['IT_REQUIRE_BROKER'] == '1';
    if (require) return; // Do not start embedded broker in this mode

    final (started, broker) = await EmbeddedMqttBroker.startIfNeeded(port: port);
    if (started) {
      _broker = broker;
    }
  }

  static Future<void> stopBroker() async {
    await _broker?.stop();
    _broker = null;
  }
}
