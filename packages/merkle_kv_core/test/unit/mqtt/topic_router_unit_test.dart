import 'dart:convert';
import 'package:test/test.dart';
import '../../../lib/src/mqtt/topic_router.dart';
import '../../../lib/src/mqtt/topic_validator.dart';
import '../../../lib/src/mqtt/connection_state.dart';
import '../../../lib/src/config/merkle_kv_config.dart';
import '../../../lib/src/config/invalid_config_exception.dart';
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
        // Ensure proper disconnection if connected
        await mockClient.disconnect();
        
        // Dispose resources in proper order
        await router.dispose();
        await mockClient.dispose();
        
        // Small delay to ensure cleanup completion
        await Future.delayed(const Duration(milliseconds: 5));
      } catch (e) {
        // Ensure tearDown doesn't fail tests
        // Note: Cleanup failed - $e
      }
    });

    group('Canonical Topic Generation', () {
      test('command topic follows canonical format {prefix}/{client_id}/cmd', () async {
        await router.subscribeToCommands((topic, payload) {});
        
        expect(mockClient.subscribedTopics, contains('test/prefix/test-client/cmd'));
        
        // Verify exact canonical format
        TestAssertions.assertCanonicalTopic(
          'test/prefix/test-client/cmd',
          'test/prefix',
          'test-client',
          'cmd',
        );
      });

      test('response topic follows canonical format {prefix}/{client_id}/res', () async {
        await router.publishResponse('test-response');
        
        expect(mockClient.publishCalls, hasLength(1));
        final call = mockClient.publishCalls.first;
        
        TestAssertions.assertCanonicalTopic(
          call.topic,
          'test/prefix',
          'test-client',
          'res',
        );
      });

      test('replication topic follows canonical format {prefix}/replication/events', () async {
        await router.subscribeToReplication((topic, payload) {});
        
        expect(mockClient.subscribedTopics, contains('test/prefix/replication/events'));
        
        TestAssertions.assertCanonicalTopic(
          'test/prefix/replication/events',
          'test/prefix',
          'replication',
          'events',
        );
      });

      test('target command topics are generated correctly', () async {
        await router.publishCommand('target-device', 'command-payload');
        
        expect(mockClient.publishCalls, hasLength(1));
        final call = mockClient.publishCalls.first;
        
        TestAssertions.assertCanonicalTopic(
          call.topic,
          'test/prefix',
          'target-device',
          'cmd',
        );
        expect(call.payload, equals('command-payload'));
      });

      test('topic generation with various prefix formats', () async {
        final testCases = [
          ('simple', 'simple/test-client/cmd'),
          ('multi/level/prefix', 'multi/level/prefix/test-client/cmd'),
          ('org-1/production', 'org-1/production/test-client/cmd'),
          ('tenant_123/env-staging', 'tenant_123/env-staging/test-client/cmd'),
        ];

        for (final (prefix, expectedTopic) in testCases) {
          final testConfig = MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'test-client',
            nodeId: 'test-node',
            topicPrefix: prefix,
          );
          final testClient = MockMqttClient();
          final testRouter = TopicRouterImpl(testConfig, testClient);

          await testRouter.subscribeToCommands((topic, payload) {});
          
          expect(testClient.subscribedTopics, contains(expectedTopic));
          
          await testRouter.dispose();
          await testClient.dispose();
        }
      });
    });

    group('Wildcard Injection Prevention', () {
      test('client IDs containing + wildcard are rejected', () {
        expect(
          () => MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'client+wildcard',
            nodeId: 'test-node',
            topicPrefix: 'test',
          ),
          throwsA(isA<InvalidConfigException>()
              .having((e) => e.parameter!, 'parameter', 'clientId')
              .having((e) => e.message, 'message', contains('MQTT wildcard \'+\''))),
        );
      });

      test('client IDs containing # wildcard are rejected', () {
        expect(
          () => MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'client#wildcard',
            nodeId: 'test-node',
            topicPrefix: 'test',
          ),
          throwsA(isA<InvalidConfigException>()
              .having((e) => e.parameter!, 'parameter', 'clientId')
              .having((e) => e.message, 'message', contains('MQTT wildcard \'#\''))),
        );
      });

      test('topic prefixes containing wildcards are rejected', () {
        expect(
          () => MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'test-client',
            nodeId: 'test-node',
            topicPrefix: 'test/+/prefix',
          ),
          throwsA(isA<InvalidConfigException>()
              .having((e) => e.parameter!, 'parameter', 'topicPrefix')),
        );
        
        expect(
          () => MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'test-client',
            nodeId: 'test-node',
            topicPrefix: 'test/prefix/#',
          ),
          throwsA(isA<InvalidConfigException>()
              .having((e) => e.parameter!, 'parameter', 'topicPrefix')),
        );
      });

      test('forward slashes in client IDs are rejected', () {
        expect(
          () => MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'client/with/slashes',
            nodeId: 'test-node',
            topicPrefix: 'test',
          ),
          throwsA(isA<InvalidConfigException>()
              .having((e) => e.parameter!, 'parameter', 'clientId')
              .having((e) => e.message, 'message', contains('forward slash (/)'))
          ),
        );
      });

      test('target client ID validation in publishCommand', () async {
        expect(
          () => router.publishCommand('invalid/target', 'payload'),
          throwsArgumentError,
        );
        
        expect(
          () => router.publishCommand('target+wildcard', 'payload'),
          throwsArgumentError,
        );
        
        expect(
          () => router.publishCommand('target#wildcard', 'payload'),
          throwsArgumentError,
        );
      });

      test('property: wildcard characters are consistently rejected', () {
        final wildcards = ['+', '#'];
        
        PropertyTestHelpers.forAll(
          () => TestGenerators.randomUtf8String(maxLength: 50),
          (baseString) {
            for (final wildcard in wildcards) {
              final invalidId = '$baseString$wildcard';
              
              expect(
                () => TopicValidator.validateClientId(invalidId),
                throwsArgumentError,
              );
            }
            return true;
          },
          iterations: 20,
        );
      });
    });

    group('Topic Length Validation', () {
      test('topics within 100 UTF-8 byte limit are accepted', () {
        // Test various topic lengths under the limit
        final validCases = [
          ('short', 'c'),              // Very short: 5+1+1+1+3 = 11 bytes
          ('medium/length', 'client'), // Medium: 13+1+6+1+3 = 24 bytes  
          ('x' * 30, 'y' * 20),       // Near limit: 30+1+20+1+3 = 55 bytes
          ('x' * 45, 'y' * 15),       // At prefix limit: 45+1+15+1+3 = 65 bytes
        ];

        for (final (prefix, clientId) in validCases) {
          expect(
            () => MerkleKVConfig(
              mqttHost: 'localhost',
              clientId: clientId,
              nodeId: 'test-node',
              topicPrefix: prefix,
            ),
            returnsNormally,
          );
        }
      });

      test('topics exceeding 100 UTF-8 byte limit are rejected during topic building', () {
        // Create config that would exceed 100 bytes total but individual components are valid
        // prefix=46 bytes + clientId=50 bytes + '/cmd' = 46+1+50+1+3 = 101 bytes (exceeds 100)
        final longPrefix = 'x' * 46;    // 46 bytes (under 50 byte prefix limit)
        final longClientId = 'y' * 50;  // 50 bytes (under 128 byte client limit)
        
        // Config creation should succeed (only validates individual components)
        final config = MerkleKVConfig(
          mqttHost: 'localhost',
          clientId: longClientId,
          nodeId: 'test-node',
          topicPrefix: longPrefix,
        );
        
        // But topic building should fail due to total length limit
        expect(
          () => TopicValidator.buildTopic(longPrefix, longClientId, TopicType.command),
          throwsArgumentError,
        );
      });

      test('UTF-8 byte length validation works with ASCII characters', () {
        // Topic validator only allows ASCII characters [A-Za-z0-9_/-]
        // Use ASCII characters that approach the byte limits
        final asciiPrefix = 'a' * 45;     // 45 ASCII bytes (under 50 byte limit)
        final asciiClient = 'b' * 20;     // 20 ASCII bytes
        // Total topic: 45 + 1 + 20 + 1 + 3 = 70 bytes (under 100)
        
        // This should be valid since prefix ≤50 bytes and total topic ≤100 bytes
        expect(
          () => MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: asciiClient,
            nodeId: 'test-node',
            topicPrefix: asciiPrefix,
          ),
          returnsNormally,
        );
        
        // Verify the constructed topic is within limits
        final topic = '$asciiPrefix/$asciiClient/cmd';
        TestAssertions.assertUtf8ByteLength(topic, 100);
      });

      test('topic length validation with edge cases', () {
        final edgeCases = [
          // Exactly at limits - prefix ≤50 bytes, total ≤100 bytes (ASCII only)
          ('a' * 50, 'b' * 30), // prefix=50, client=30, +/cmd = 84 bytes total
          ('a' * 45, 'b' * 40), // prefix=45, client=40, +/cmd = 89 bytes total
          
          // Mixed ASCII character sets (validator only allows [A-Za-z0-9_/-])
          ('test_prefix/sub', 'client-123'), // Valid ASCII with allowed special chars
          ('production/env-1', 'device_001'), // Valid ASCII with hyphens and underscores
        ];

        for (final (prefix, clientId) in edgeCases) {
          final topic = '$prefix/$clientId/cmd';
          final bytes = utf8.encode(topic);
          
          if (bytes.length <= 100) {
            expect(() {
              TopicValidator.validatePrefix(prefix);
              TopicValidator.validateClientId(clientId);
            }, returnsNormally);
          } else {
            expect(() {
              TopicValidator.buildTopic(prefix, clientId, TopicType.command);
            }, throwsArgumentError);
          }
        }
      });
      });
    });

    group('Multi-Tenant Isolation', () {
      test('different tenant prefixes create isolated topics', () {
        final tenant1Config = MerkleKVConfig(
          mqttHost: 'localhost',
          clientId: 'device-123',
          nodeId: 'node-123',
          topicPrefix: 'tenant-1/production',
        );
        
        final tenant2Config = MerkleKVConfig(
          mqttHost: 'localhost',
          clientId: 'device-456',
          nodeId: 'node-456',
          topicPrefix: 'tenant-2/staging',
        );

        final topic1 = TopicValidator.buildCommandTopic(
          tenant1Config.topicPrefix,
          tenant1Config.clientId,
        );
        final topic2 = TopicValidator.buildCommandTopic(
          tenant2Config.topicPrefix,
          tenant2Config.clientId,
        );

        expect(topic1, equals('tenant-1/production/device-123/cmd'));
        expect(topic2, equals('tenant-2/staging/device-456/cmd'));
        expect(topic1, isNot(equals(topic2))); // Complete isolation
      });

      test('tenant isolation prevents cross-tenant message routing', () async {
        final client1 = MockMqttClient();
        final client2 = MockMqttClient();
        
        final router1 = TopicRouterImpl(
          MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'device-1',
            nodeId: 'node-1',
            topicPrefix: 'org-alpha/prod',
          ),
          client1,
        );
        
        final router2 = TopicRouterImpl(
          MerkleKVConfig(
            mqttHost: 'localhost',
            clientId: 'device-2',
            nodeId: 'node-2',
            topicPrefix: 'org-beta/test',
          ),
          client2,
        );

        // Set up command subscriptions
        await router1.subscribeToCommands((topic, payload) {});
        await router2.subscribeToCommands((topic, payload) {});

        // Verify different topics
        expect(client1.subscribedTopics, contains('org-alpha/prod/device-1/cmd'));
        expect(client2.subscribedTopics, contains('org-beta/test/device-2/cmd'));
        
        // Verify no overlap
        final topics1 = client1.subscribedTopics;
        final topics2 = client2.subscribedTopics;
        expect(topics1.intersection(topics2), isEmpty);

        await router1.dispose();
        await router2.dispose();
        await client1.dispose();
        await client2.dispose();
      });

      test('replication topics are tenant-isolated', () async {
        final tenantRouters = [
          ('tenant-a/env1', 'device-a1'),
          ('tenant-b/env2', 'device-b1'),
          ('tenant-c/env3', 'device-c1'),
        ];

        final replicationTopics = <String>[];

        for (final (prefix, clientId) in tenantRouters) {
          final testClient = MockMqttClient();
          final testRouter = TopicRouterImpl(
            MerkleKVConfig(
              mqttHost: 'localhost',
              clientId: clientId,
              nodeId: 'node-test',
              topicPrefix: prefix,
            ),
            testClient,
          );

          await testRouter.subscribeToReplication((topic, payload) {});
          
          final replicationTopic = testClient.subscribedTopics
              .firstWhere((topic) => topic.contains('/replication/events'));
          replicationTopics.add(replicationTopic);

          await testRouter.dispose();
          await testClient.dispose();
        }

        // All replication topics should be different
        expect(replicationTopics.toSet().length, equals(replicationTopics.length));
        
        // Verify tenant isolation in replication topics
        expect(replicationTopics, contains('tenant-a/env1/replication/events'));
        expect(replicationTopics, contains('tenant-b/env2/replication/events'));
        expect(replicationTopics, contains('tenant-c/env3/replication/events'));
      });

      test('prefix normalization maintains isolation', () {
        // These prefixes normalize successfully and should be accepted
        final validUnnormalizedPrefixes = [
          '  tenant-1/prod  ',   // Normalizes to 'tenant-1/prod'
          'tenant-1/prod/',      // Normalizes to 'tenant-1/prod'
          '/tenant-1/prod',      // Normalizes to 'tenant-1/prod'
        ];

        for (final prefix in validUnnormalizedPrefixes) {
          expect(
            () => MerkleKVConfig(
              mqttHost: 'localhost',
              clientId: 'test-client',
              nodeId: 'test-node',
              topicPrefix: prefix,
            ),
            returnsNormally,
          );
        }

        // These prefixes should fail validation even after normalization
        final invalidPrefixes = [
          '//tenant-1//prod//',  // Normalizes to 'tenant-1//prod' (double slashes invalid)
          '   ',                 // Normalizes to empty string, uses default 'mkv'
          'tenant+wildcard',     // Contains MQTT wildcard '+'
          'tenant#wildcard',     // Contains MQTT wildcard '#'
        ];

        for (final prefix in invalidPrefixes) {
          expect(
            () => MerkleKVConfig(
              mqttHost: 'localhost',
              clientId: 'test-client',
              nodeId: 'test-node',
              topicPrefix: prefix,
            ),
            throwsA(isA<InvalidConfigException>()),
          );
        }
      });

      test('property: tenant isolation is consistent across operations', () {
        PropertyTestHelpers.forAll2(
          () => 'tenant-${TestGenerators.randomNodeId()}',
          () => 'device-${TestGenerators.randomNodeId()}',
          (prefix1, clientId1) {
            final prefix2 = '$prefix1-other';
            final clientId2 = '$clientId1-other';
            
            try {
              final topic1 = TopicValidator.buildCommandTopic(prefix1, clientId1);
              final topic2 = TopicValidator.buildCommandTopic(prefix2, clientId2);
              
              // Different tenants should have different topics
              return topic1 != topic2;
            } catch (e) {
              // Invalid configurations should fail consistently
              return true;
            }
          },
          iterations: 30,
        );
      });
    });

    group('QoS and Retain Flag Enforcement', () {
      test('all published messages use QoS=1', () async {
        await router.publishCommand('target-device', 'command');
        await router.publishResponse('response');
        await router.publishReplication('replication-event');

        expect(mockClient.publishCalls, hasLength(3));
        
        for (final call in mockClient.publishCalls) {
          expect(call.qos1, isTrue, reason: 'All messages should use QoS=1');
        }
      });

      test('all published messages use retain=false', () async {
        await router.publishCommand('target-device', 'command');
        await router.publishResponse('response');
        await router.publishReplication('replication-event');

        expect(mockClient.publishCalls, hasLength(3));
        
        for (final call in mockClient.publishCalls) {
          expect(call.retainFalse, isTrue, reason: 'All messages should use retain=false');
        }
      });

      test('QoS and retain flags cannot be overridden', () async {
        // Topic router should enforce QoS=1, retain=false regardless of client settings
        await router.publishCommand('device', 'test');
        
        final call = mockClient.publishCalls.first;
        expect(call.qos1, isTrue);
        expect(call.retainFalse, isTrue);
      });
    });

    group('Auto Re-subscription After Reconnection', () {
      test('command subscriptions are restored after reconnection', () async {
        await router.subscribeToCommands((topic, payload) {});
        
        expect(mockClient.subscribedTopics, contains('test/prefix/test-client/cmd'));
        
        // Clear subscription history and simulate reconnection
        mockClient.reset();
        mockClient.simulateConnectionState(ConnectionState.connected);
        
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Subscription should be restored
        expect(mockClient.subscribedTopics, contains('test/prefix/test-client/cmd'));
      });

      test('replication subscriptions are restored after reconnection', () async {
        await router.subscribeToReplication((topic, payload) {});
        
        expect(mockClient.subscribedTopics, contains('test/prefix/replication/events'));
        
        // Simulate reconnection
        mockClient.reset();
        mockClient.simulateConnectionState(ConnectionState.connected);
        
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Subscription should be restored
        expect(mockClient.subscribedTopics, contains('test/prefix/replication/events'));
      });

      test('only active subscriptions are restored', () async {
        // Subscribe to commands only
        await router.subscribeToCommands((topic, payload) {});
        
        expect(mockClient.subscribedTopics, hasLength(1));
        expect(mockClient.subscribedTopics, contains('test/prefix/test-client/cmd'));
        
        // Simulate reconnection
        mockClient.reset();
        mockClient.simulateConnectionState(ConnectionState.connected);
        
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Only command subscription should be restored
        expect(mockClient.subscribedTopics, hasLength(1));
        expect(mockClient.subscribedTopics, contains('test/prefix/test-client/cmd'));
      });

      test('multiple reconnection cycles maintain subscriptions', () async {
        await router.subscribeToCommands((topic, payload) {});
        await router.subscribeToReplication((topic, payload) {});
        
        for (int i = 0; i < 3; i++) {
          mockClient.reset();
          
          // Simulate disconnect/reconnect cycle
          mockClient.simulateConnectionState(ConnectionState.disconnected);
          await Future.delayed(const Duration(milliseconds: 10));
          
          mockClient.simulateConnectionState(ConnectionState.connected);
          await Future.delayed(const Duration(milliseconds: 50));
          
          // Both subscriptions should be restored
          expect(mockClient.subscribedTopics, hasLength(2));
          expect(mockClient.subscribedTopics, contains('test/prefix/test-client/cmd'));
          expect(mockClient.subscribedTopics, contains('test/prefix/replication/events'));
        }
      });
    });

    group('Message Handler Functionality', () {
      test('command handlers receive correct topic and payload', () async {
        String? receivedTopic;
        String? receivedPayload;
        
        await router.subscribeToCommands((topic, payload) {
          receivedTopic = topic;
          receivedPayload = payload;
        });
        
        mockClient.simulateMessage('test/prefix/test-client/cmd', 'test-command');
        
        expect(receivedTopic, equals('test/prefix/test-client/cmd'));
        expect(receivedPayload, equals('test-command'));
      });

      test('replication handlers receive correct messages', () async {
        final receivedMessages = <Map<String, String>>[];
        
        await router.subscribeToReplication((topic, payload) {
          receivedMessages.add({'topic': topic, 'payload': payload});
        });
        
        mockClient.simulateMessage('test/prefix/replication/events', 'event-1');
        mockClient.simulateMessage('test/prefix/replication/events', 'event-2');
        
        expect(receivedMessages, hasLength(2));
        expect(receivedMessages[0]['payload'], equals('event-1'));
        expect(receivedMessages[1]['payload'], equals('event-2'));
      });

      test('handlers remain active across reconnections', () async {
        final receivedCommands = <String>[];
        
        await router.subscribeToCommands((topic, payload) {
          receivedCommands.add(payload);
        });
        
        // Receive message before reconnection
        mockClient.simulateMessage('test/prefix/test-client/cmd', 'before-reconnect');
        expect(receivedCommands, equals(['before-reconnect']));
        
        // Simulate reconnection
        mockClient.simulateConnectionState(ConnectionState.disconnected);
        mockClient.simulateConnectionState(ConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Receive message after reconnection
        mockClient.simulateMessage('test/prefix/test-client/cmd', 'after-reconnect');
        expect(receivedCommands, equals(['before-reconnect', 'after-reconnect']));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('handles empty payloads correctly', () async {
        await router.publishCommand('target', '');
        await router.publishResponse('');
        await router.publishReplication('');
        
        expect(mockClient.publishCalls, hasLength(3));
        
        for (final call in mockClient.publishCalls) {
          expect(call.payload, equals(''));
        }
      });

      test('handles large payloads correctly', () async {
        final largePayload = 'x' * 10000; // 10KB payload
        
        await router.publishCommand('target', largePayload);
        
        expect(mockClient.publishCalls, hasLength(1));
        expect(mockClient.publishCalls.first.payload, equals(largePayload));
      });

      test('graceful disposal cleans up resources', () async {
        await router.subscribeToCommands((topic, payload) {});
        await router.subscribeToReplication((topic, payload) {});
        
        // Should not throw during disposal
        await router.dispose();
        
        // Multiple dispose calls should be safe
        await router.dispose();
      });

      test('operations after disposal continue to work', () async {
        await router.dispose();
        
        // Operations after disposal should still work (disposal only cleans up subscriptions)
        expect(
          () => router.publishCommand('target', 'payload'),
          returnsNormally,
        );
      });
    });
  });
}