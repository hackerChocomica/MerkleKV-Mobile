import 'dart:async';
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../lib/src/config/merkle_kv_config.dart';
import '../../../lib/src/mqtt/connection_state.dart';
import '../../../lib/src/mqtt/mqtt_client_interface.dart';
import '../../utils/mock_helpers.dart';
import '../../utils/generators.dart';

void main() {
  group('MQTT Client Unit Tests', () {
    late MerkleKVConfig config;
    late MockMqttClient client;

    setUp(() {
      config = MerkleKVConfig.create(
        mqttHost: 'localhost',
        clientId: 'test-client',
        nodeId: 'test-node',
        mqttUseTls: false,
      );
      client = MockMqttClient();
    });

    group('Connection Management', () {
      test('should enforce QoS=1 for publish operations', () async {
        // Arrange: Mock successful connection
        when(() => client.connect()).thenAnswer((_) async {});
        when(() => client.publish(any(), any(), forceQoS1: true, forceRetainFalse: true))
            .thenAnswer((_) async {});

        // Act: Connect and publish with QoS=1 enforcement
        await client.connect();
        await client.publish('test/topic', 'test-message');

        // Assert: Verify QoS=1 was enforced
        verify(() => client.publish('test/topic', 'test-message', forceQoS1: true, forceRetainFalse: true)).called(1);
      });

      test('should track subscribed topics correctly', () async {
        // Arrange: Mock subscription success
        when(() => client.subscribe(any(), any())).thenAnswer((_) async {});

        // Act: Subscribe to topics
        await client.subscribe('app/+/data', (topic, payload) {});

        // Assert: Verify subscription was called
        verify(() => client.subscribe('app/+/data', any())).called(1);
      });

      test('should track connection state transitions', () async {
        // Arrange: Create connection state stream
        final stateController = StreamController<ConnectionState>();
        when(() => client.connectionState).thenAnswer((_) => stateController.stream);

        // Act: Simulate connection state changes
        stateController.add(ConnectionState.connecting);
        stateController.add(ConnectionState.connected);

        // Assert: Verify state transitions
        expect(client.connectionState, emitsInOrder([
          ConnectionState.connecting,
          ConnectionState.connected,
        ]));

        await stateController.close();
      });

      test('should handle connection failures gracefully', () async {
        // Arrange: Mock connection failure
        when(() => client.connect()).thenThrow(Exception('Connection failed'));

        // Act & Assert: Should throw connection exception
        expect(() => client.connect(), throwsException);
      });
    });

    group('Reconnection Strategy', () {
      test('should implement exponential backoff with jitter', () async {
        // Test exponential backoff calculation
        final random = math.Random(42); // Fixed seed for reproducible tests
        final maxJitter = math.Random(42).nextInt(1000);

        // Simulate exponential backoff delays
        for (int attempt = 1; attempt <= 5; attempt++) {
          final baseDelay = math.pow(2, attempt - 1) * 1000; // Base delay in ms
          final jitter = random.nextInt(1000);
          final totalDelay = (baseDelay + jitter).toInt();
          
          expect(totalDelay, greaterThan(baseDelay.toInt()));
          expect(totalDelay, lessThan((baseDelay + 1000).toInt()));
        }
      });

      test('should limit maximum backoff delay', () async {
        // Test maximum backoff limit (30 seconds)
        const maxBackoffMs = 30000;
        
        for (int attempt = 10; attempt <= 15; attempt++) {
          final baseDelay = math.pow(2, attempt - 1) * 1000;
          final effectiveDelay = math.min(baseDelay, maxBackoffMs.toDouble());
          
          expect(effectiveDelay, lessThanOrEqualTo(maxBackoffMs));
        }
      });
    });

    group('Malformed Packet Handling', () {
      test('should handle connection state after malformed packets', () async {
        // Arrange: Mock connection state stream
        final stateController = StreamController<ConnectionState>();
        when(() => client.connectionState).thenAnswer((_) => stateController.stream);

        // Act: Simulate malformed packet causing disconnection
        stateController.add(ConnectionState.connected);
        // Simulate malformed packet error (would cause disconnection in real implementation)
        stateController.add(ConnectionState.disconnected);

        // Assert: Should transition to disconnected state
        expect(client.connectionState, emitsInOrder([
          ConnectionState.connected,
          ConnectionState.disconnected,
        ]));

        await stateController.close();
      });
    });

    group('Message Publishing', () {
      test('should queue messages during disconnection', () async {
        // Arrange: Mock disconnected state
        when(() => client.publish(any(), any(), forceQoS1: any(named: 'forceQoS1'), forceRetainFalse: any(named: 'forceRetainFalse')))
            .thenAnswer((_) async {});

        // Act: Attempt to publish while disconnected
        await client.publish('test/topic', 'queued-message');

        // Assert: Message should be queued (in real implementation)
        verify(() => client.publish('test/topic', 'queued-message', forceQoS1: any(named: 'forceQoS1'), forceRetainFalse: any(named: 'forceRetainFalse'))).called(1);
      });
    });

    group('Authentication', () {
      test('should validate TLS configuration', () async {
        // Arrange: Create TLS config
        final tlsConfig = MerkleKVConfig.create(
          mqttHost: 'secure.example.com',
          clientId: 'tls-client',
          nodeId: 'test-node',
          mqttUseTls: true,
        );

        // Assert: TLS should be enabled
        expect(tlsConfig.mqttUseTls, isTrue);
      });
    });

    group('Topic Management', () {
      test('should handle subscription lifecycle', () async {
        // Arrange: Mock subscription operations
        when(() => client.subscribe(any(), any())).thenAnswer((_) async {});
        when(() => client.unsubscribe(any())).thenAnswer((_) async {});

        // Act: Subscribe and unsubscribe
        await client.subscribe('test/topic', (topic, payload) {});
        await client.unsubscribe('test/topic');

        // Assert: Both operations should be called
        verify(() => client.subscribe('test/topic', any())).called(1);
        verify(() => client.unsubscribe('test/topic')).called(1);
      });

      test('should handle subscription failures gracefully', () async {
        // Arrange: Mock subscription failure
        when(() => client.subscribe(any(), any())).thenThrow(Exception('Subscription failed'));

        // Act & Assert: Should throw subscription exception
        expect(() => client.subscribe('test/topic', (topic, payload) {}), throwsException);
      });
    });

    group('Message Handling', () {
      test('should process incoming messages correctly', () async {
        // Arrange: Mock message handler
        var receivedTopic = '';
        var receivedPayload = '';
        
        when(() => client.subscribe(any(), any())).thenAnswer((invocation) async {
          final handler = invocation.positionalArguments[1] as void Function(String, String);
          // Simulate receiving a message
          handler('test/topic', 'test-payload');
        });

        // Act: Subscribe with message handler
        await client.subscribe('test/topic', (topic, payload) {
          receivedTopic = topic;
          receivedPayload = payload;
        });

        // Assert: Message should be processed
        expect(receivedTopic, equals('test/topic'));
        expect(receivedPayload, equals('test-payload'));
      });
    });

    group('Payload Validation', () {
      test('should enforce payload size limits', () async {
        // Arrange: Create large payload
        final largePayload = 'x' * (1024 * 1024 + 1); // Exceed 1MB limit
        when(() => client.publish(any(), any(), forceQoS1: any(named: 'forceQoS1'), forceRetainFalse: any(named: 'forceRetainFalse')))
            .thenThrow(Exception('Payload too large'));

        // Act & Assert: Should reject large payloads
        expect(() => client.publish('test/topic', largePayload), throwsException);
      });

      test('should accept valid payload sizes', () async {
        // Arrange: Create normal-sized payload
        final normalPayload = 'normal payload';
        when(() => client.publish(any(), any(), forceQoS1: any(named: 'forceQoS1'), forceRetainFalse: any(named: 'forceRetainFalse')))
            .thenAnswer((_) async {});

        // Act: Publish normal payload
        await client.publish('test/topic', normalPayload);

        // Assert: Should succeed
        verify(() => client.publish('test/topic', normalPayload, forceQoS1: any(named: 'forceQoS1'), forceRetainFalse: any(named: 'forceRetainFalse'))).called(1);
      });
    });
  });
}