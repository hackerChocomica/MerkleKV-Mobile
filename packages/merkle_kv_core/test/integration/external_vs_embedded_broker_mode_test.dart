import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

import '../utils/test_broker_helper.dart';
import 'test_config.dart';

/// Lightweight test verifying whether we are running against a real external broker
/// (docker / existing) or the embedded stub broker.
///
/// Detection heuristics:
///   1. If env IT_REQUIRE_BROKER=1 -> expect external
///   2. Publish retained marker to a topic, disconnect, reconnect and subscribe
///      - Embedded stub does NOT implement retained message delivery, external brokers do
///   3. If retained marker not delivered but external required -> fail
///      Else classify as embedded.
void main() {
  group('Broker Mode Detection', () {
    late MerkleKVConfig cfg;
    late MqttClientImpl client;

    setUpAll(() async {
      await TestBrokerHelper.ensureBroker(
          port: IntegrationTestConfig.mosquittoPort);
      cfg = TestConfigurations.mosquittoBasic(
        clientId: 'mode-detector',
        nodeId: 'node-mode-detector',
      );
      client = MqttClientImpl(cfg);
      await client.connect();
    });

    tearDownAll(() async {
      await client.disconnect();
    });

  test('detect external vs embedded via retained message delivery', () async {
      final requireExternal = Platform.environment['IT_REQUIRE_BROKER'] == '1';
      final markerTopic = '${cfg.topicPrefix}/mode/marker';
      final markerPayload = 'mkv_mode_marker_${DateTime.now().millisecondsSinceEpoch}';

      // Publish retained marker (only external real broker will honor retain)
      await client.publish(markerTopic, markerPayload, retain: true);
      await client.disconnect();
      await Future.delayed(const Duration(milliseconds: 150));
      await client.connect();

      final retained = Completer<String?>();
      await client.subscribe(markerTopic, (t, p) {
        if (!retained.isCompleted) retained.complete(p);
      });
      final delivered = await retained.future
          .timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      final isExternal = delivered == markerPayload;

      if (requireExternal) {
        expect(isExternal, isTrue,
            reason: 'IT_REQUIRE_BROKER=1 set but retained message not delivered (embedded stub detected)');
      }
      if (isExternal) {
        // Clean retained message
        await client.publish(markerTopic, '', retain: true);
      }
    });
  });
}
