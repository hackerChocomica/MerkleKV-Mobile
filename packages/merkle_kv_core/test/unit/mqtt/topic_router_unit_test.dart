import 'dart:convert';
import 'package:test/test.dart';
import '../../../lib/src/mqtt/topic_router.dart';
import '../../../lib/src/mqtt/topic_validator.dart';
import '../../../lib/src/mqtt/topic_permissions.dart';
import '../../../lib/src/mqtt/topic_authz_metrics.dart';
import '../../../lib/src/mqtt/connection_state.dart';
import '../../../lib/src/config/merkle_kv_config.dart';
import '../../../lib/src/config/invalid_config_exception.dart';
import '../../../lib/src/commands/error_classifier.dart';
import '../../utils/generators.dart';
import '../../utils/mock_helpers.dart';

void main() {
  group('Topic Router Unit Tests', () {
    late MerkleKVConfig config;
    late MockMqttClient mockClient;
    late TopicRouterImpl router;

    setUp(() {
      config = MerkleKVConfig.create(
        mqttHost: 'localhost',
        clientId: 'test-client',
        nodeId: 'test-node',
        topicPrefix: 'test/prefix',
      );
      mockClient = MockMqttClient();
      router = TopicRouterImpl(config, mockClient);
    });

    tearDown(() async {
      try {
        await mockClient.disconnect();
        await router.dispose();
        await mockClient.dispose();
        await Future.delayed(const Duration(milliseconds: 5));
      } catch (e) {
        // Ensure tearDown doesn't fail tests
      }
    });

    group('Basic Functionality', () {
      test('can create router with valid config', () {
        expect(router, isNotNull);
      });

      test('can publish command messages', () async {
        await router.publishCommand('target-device', 'test-command');
        expect(mockClient.publishCalls, hasLength(1));
        final call = mockClient.publishCalls.first;
        expect(call.topic, contains('test/prefix'));
        expect(call.payload, equals('test-command'));
      });

      test('can publish response messages', () async {
        await router.publishResponse('test-response');
        expect(mockClient.publishCalls, hasLength(1));
        final call = mockClient.publishCalls.first;
        expect(call.topic, contains('test/prefix'));
        expect(call.payload, equals('test-response'));
      });

      test('can publish replication messages', () async {
        await router.publishReplication('test-replication');
        expect(mockClient.publishCalls, hasLength(1));
        final call = mockClient.publishCalls.first;
        expect(call.topic, contains('test/prefix'));
        expect(call.payload, equals('test-replication'));
      });

      test('can subscribe to commands', () async {
        await router.subscribeToCommands((topic, payload) {});
        expect(mockClient.subscribedTopics, hasLength(1));
        expect(mockClient.subscribedTopics.first, contains('test/prefix'));
        expect(mockClient.subscribedTopics.first, contains('cmd'));
      });

      test('can subscribe to replication', () async {
        await router.subscribeToReplication((topic, payload) {});
        expect(mockClient.subscribedTopics, hasLength(1));
        expect(mockClient.subscribedTopics.first, contains('test/prefix'));
        expect(mockClient.subscribedTopics.first, contains('replication'));
      });

      test('handlers receive messages correctly', () async {
        String? receivedTopic;
        String? receivedPayload;
        
        await router.subscribeToCommands((topic, payload) {
          receivedTopic = topic;
          receivedPayload = payload;
        });
        
        mockClient.simulateMessage('test/prefix/test-client/cmd', 'test-command');
        
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(receivedTopic, equals('test/prefix/test-client/cmd'));
        expect(receivedPayload, equals('test-command'));
      });

      test('disposal works correctly', () async {
        await router.dispose();
        
        // Operations after disposal should still work (disposal only cleans up subscriptions)
        expect(
          () => router.publishCommand('target', 'payload'),
          returnsNormally,
        );
      });
    });

    group('Client-side topic authorization', () {
      test('controller allows cross-client publish, non-controller denied', () async {
        final canonicalCfg = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-1',
          nodeId: 'node-1',
          topicPrefix: 'merkle_kv',
          replicationAccess: ReplicationAccess.readWrite,
        ).copyWith(isController: false);
        final client = MockMqttClient();
        final canonicalRouter = TopicRouterImpl(canonicalCfg, client);

        // Non-controller cross-client should throw ApiException (code 300)
        expect(
          () => canonicalRouter.publishCommand('other-device', 'cmd'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 300)),
        );
        expect(canonicalRouter.authzMetrics.commandDenied, 1);

  // Self-target is allowed
        await canonicalRouter.publishCommand('device-1', 'cmd');
        expect(client.publishCalls, hasLength(1));

  // Controller config
  final controllerCfg = canonicalCfg.copyWith(isController: true);
  final controllerClient = MockMqttClient();
  final controllerRouter = TopicRouterImpl(controllerCfg, controllerClient);
  await controllerRouter.publishCommand('other-device', 'cmd'); // allowed
  expect(controllerRouter.authzMetrics.commandAllowed, 1);

  await controllerRouter.dispose();
  await controllerClient.dispose();

        await canonicalRouter.dispose();
        await client.dispose();
      });

      test('response subscription: controller can subscribe to others; device denied', () async {
        final base = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-A',
          nodeId: 'node-A',
          topicPrefix: 'merkle_kv',
          replicationAccess: ReplicationAccess.readWrite,
        ).copyWith(isController: false);
        final clientA = MockMqttClient();
        final routerA = TopicRouterImpl(base, clientA);

        // Denied attempt (subscribe to device-B responses)
        expect(
          () => routerA.subscribeToResponsesOf('device-B', (_, __) {}),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 302)),
        );
        expect(routerA.authzMetrics.responseSubscribeDenied, 1);

        // Controller allowed
        final controllerCfg = base.copyWith(isController: true, clientId: 'controller-1');
        final controllerClient = MockMqttClient();
        final controllerRouter = TopicRouterImpl(controllerCfg, controllerClient);
        await controllerRouter.subscribeToResponsesOf('device-B', (_, __) {});
        expect(controllerRouter.authzMetrics.responseSubscribeAllowed, 1);

        await controllerRouter.dispose();
        await controllerClient.dispose();
        await routerA.dispose();
        await clientA.dispose();
      });

      test('does not restrict non-canonical prefixes', () async {
        final nonCanonicalCfg = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-1',
          nodeId: 'node-1',
          topicPrefix: 'test/prefix',
        );
        final client = MockMqttClient();
        final nonCanonicalRouter = TopicRouterImpl(nonCanonicalCfg, client);

        await nonCanonicalRouter.publishCommand('other-device', 'cmd');
        expect(client.publishCalls, hasLength(1));

        await nonCanonicalRouter.dispose();
        await client.dispose();
      });

      test('denies replication publish when replicationAccess is none', () async {
        final cfg = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-1',
          nodeId: 'node-1',
          topicPrefix: 'merkle_kv',
          replicationAccess: ReplicationAccess.none,
        );
        final client = MockMqttClient();
        final routerDenied = TopicRouterImpl(cfg, client);

        expect(
          () => routerDenied.publishReplication('evt'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 301)),
        );

        await routerDenied.dispose();
        await client.dispose();
      });

      test('denies replication publish when replicationAccess is read (read-only)', () async {
        final cfg = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-1',
          nodeId: 'node-1',
          topicPrefix: 'merkle_kv',
          replicationAccess: ReplicationAccess.read,
        );
        final client = MockMqttClient();
        final routerDenied = TopicRouterImpl(cfg, client);

        expect(
          () => routerDenied.publishReplication('evt'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 301)),
        );

        await routerDenied.dispose();
        await client.dispose();
      });

      test('allows replication publish when replicationAccess is readWrite', () async {
        final cfg = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-1',
          nodeId: 'node-1',
          topicPrefix: 'merkle_kv',
          replicationAccess: ReplicationAccess.readWrite,
        );
        final client = MockMqttClient();
        final routerAllowed = TopicRouterImpl(cfg, client);

        await routerAllowed.publishReplication('evt');
        expect(client.publishCalls, hasLength(1));
        expect(routerAllowed.authzMetrics.replicationAllowed, 1);

        await routerAllowed.dispose();
        await client.dispose();
      });

      test('metrics accumulate for multiple decisions', () async {
        final cfg = MerkleKVConfig.create(
          mqttHost: 'localhost',
          clientId: 'device-1',
          nodeId: 'node-1',
          topicPrefix: 'merkle_kv',
          replicationAccess: ReplicationAccess.none,
        );
        final client = MockMqttClient();
        final router = TopicRouterImpl(cfg, client);

        for (var i = 0; i < 2; i++) {
          expect(
            () => router.publishReplication('evt'),
            throwsA(isA<ApiException>().having((e) => e.code, 'code', 301)),
          );
        }

        expect(
          () => router.publishCommand('other-device', 'cmd'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 300)),
        );

        expect(router.authzMetrics.replicationDenied, 2);
        expect(router.authzMetrics.commandDenied, 1);

        await router.dispose();
        await client.dispose();
      });
    });
  });
}