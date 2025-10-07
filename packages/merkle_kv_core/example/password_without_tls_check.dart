import 'dart:async';

import 'package:merkle_kv_core/src/config/merkle_kv_config.dart';
import 'package:merkle_kv_core/src/mqtt/connection_state.dart';
import 'package:merkle_kv_core/src/mqtt/mqtt_client_impl.dart';

Future<void> main() async {
  // Print security warnings to stdout for visibility
  MerkleKVConfig.setSecurityWarningHandler((msg) {
    print('SECURITY WARNING: $msg');
  });

  final config = MerkleKVConfig(
    mqttHost: '127.0.0.1',
    mqttPort: 1883,
    mqttUseTls: false,
    // Username is intentionally null to simulate token-only in password
    password: 'dummy-token',
    clientId: 'local-password-no-tls-test',
    nodeId: 'node-local',
    topicPrefix: 'merkle_kv/test',
    keepAliveSeconds: 5,
    connectionTimeoutSeconds: 5,
  );

  final client = MqttClientImpl(config);
  final events = <ConnectionState>[];
  final sub = client.connectionState.listen((s) {
    events.add(s);
    print('State: $s');
  });

  try {
    await client.connect();
    // Give some time for state propagation
    await Future.delayed(const Duration(milliseconds: 200));
    if (client.currentConnectionState == ConnectionState.connected) {
      print('✅ Connected successfully without TLS using password-only.');
    } else {
      print('❌ Unexpected state: ${client.currentConnectionState}');
    }
  } catch (e) {
    print('❌ Connect failed: $e');
    rethrow;
  } finally {
    await client.disconnect();
    await sub.cancel();
  }
}
