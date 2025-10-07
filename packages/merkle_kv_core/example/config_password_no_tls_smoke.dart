import 'package:merkle_kv_core/src/config/merkle_kv_config.dart';
import 'package:merkle_kv_core/src/mqtt/mqtt_client_impl.dart';

void main() {
  MerkleKVConfig.setSecurityWarningHandler((msg) {
    print('SECURITY WARNING: $msg');
  });

  final cfg = MerkleKVConfig(
    mqttHost: 'localhost',
    mqttPort: 1883,
    mqttUseTls: false,
    password: 'token-only',
    clientId: 'smoke-password-no-tls',
    nodeId: 'node-smoke',
    topicPrefix: 'merkle_kv/test',
  );

  print('Config built. mqttUseTls=${cfg.mqttUseTls}, hasPassword=${cfg.password != null}');
  // Ensure client can be constructed without immediate TLS validation error
  final client = MqttClientImpl(cfg);
  // Reference the client so the analyzer doesn't warn about unused local variable
  print('Client initialized. Port=${cfg.mqttPort}, state=${client.currentConnectionState}');
  // Do not actually connect in this smoke test.
}
