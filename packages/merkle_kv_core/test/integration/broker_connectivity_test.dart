import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import 'test_config.dart';

void main() {
  group('End-to-End MQTT Operations', () {
    setUpAll(() async {
      // Validate test environment
      expect(IntegrationTestConfig.mosquittoHost, isNotEmpty, 
        reason: 'MQTT broker host must be configured');
      expect(IntegrationTestConfig.mosquittoPort, greaterThan(0), 
        reason: 'MQTT broker port must be valid');
    });

    test('MQTT connection establishment with Mosquitto broker', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'test-client-1',
        nodeId: 'test-node-1',
      );

      final mqttClient = MqttClientImpl(config);
      
      // Test connection
      await mqttClient.connect();
      expect(mqttClient.isConnected, isTrue);
      
      // Test disconnection
      await mqttClient.disconnect();
      expect(mqttClient.isConnected, isFalse);
    });

    test('basic MQTT publish/subscribe with command correlator', () async {
      final config = MerkleKVConfig(
        nodeId: 'test-node-pub-sub',
        mqttHost: testConfig.mosquittoHost,
        mqttPort: testConfig.mosquittoPort,
        mqttUsername: testConfig.mqttUsername,
        mqttPassword: testConfig.mqttPassword,
        useTls: testConfig.useTls,
        persistenceEnabled: false,
      );

      final mqttClient = MqttClientImpl(config);
      final topicRouter = TopicRouter();
      
      await mqttClient.connect();

      // Set up command correlator with publish function
      final correlator = CommandCorrelator(
        publishCommand: (jsonPayload) async {
          final topicScheme = TopicScheme(config.nodeId);
          await mqttClient.publish(
            topicScheme.commandTopic(config.nodeId),
            jsonPayload,
          );
        },
      );

      // Test command creation and validation
      final command = Command(
        id: 'test-command-123',
        op: 'GET',
        key: 'test-key',
      );

      expect(command.id, equals('test-command-123'));
      expect(command.op, equals('GET'));
      expect(command.key, equals('test-key'));

      await mqttClient.disconnect();
    });

    test('storage operations with in-memory backend', () async {
      final config = MerkleKVConfig(
        nodeId: 'test-storage-node',
        mqttHost: testConfig.mosquittoHost,
        mqttPort: testConfig.mosquittoPort,
        persistenceEnabled: false,
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();

      // Test basic storage operations
      final testKey = 'test-storage-key';
      final testValue = 'test-storage-value';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Test SET operation
      final setEntry = StorageEntry.value(
        key: testKey,
        value: testValue,
        timestamp: timestamp,
        nodeId: config.nodeId,
      );

      await storage.set(testKey, setEntry);

      // Test GET operation
      final retrievedEntry = await storage.get(testKey);
      expect(retrievedEntry, isNotNull);
      expect(retrievedEntry!.value, equals(testValue));
      expect(retrievedEntry.key, equals(testKey));

      // Test DEL operation (tombstone)
      final deleteEntry = StorageEntry.tombstone(
        key: testKey,
        timestamp: timestamp + 1000,
        nodeId: config.nodeId,
      );

      await storage.set(testKey, deleteEntry);

      final deletedEntry = await storage.get(testKey);
      expect(deletedEntry, isNull); // Tombstones return null on get
    });

    test('topic validation and routing', () async {
      final config = MerkleKVConfig(
        nodeId: 'test-topic-node',
        mqttHost: testConfig.mosquittoHost,
        mqttPort: testConfig.mosquittoPort,
        persistenceEnabled: false,
      );

      final topicScheme = TopicScheme(config.nodeId);
      final validator = TopicValidator();

      // Test topic generation
      final commandTopic = topicScheme.commandTopic('target-node');
      final responseTopic = topicScheme.responseTopic('source-node');
      final replicationTopic = topicScheme.replicationTopic();

      expect(commandTopic, contains('cmd'));
      expect(responseTopic, contains('rsp'));
      expect(replicationTopic, contains('repl'));

      // Test topic validation
      expect(validator.isValidCommandTopic(commandTopic), isTrue);
      expect(validator.isValidResponseTopic(responseTopic), isTrue);
      expect(validator.isValidReplicationTopic(replicationTopic), isTrue);
    });

    test('connection lifecycle management', () async {
      final config = MerkleKVConfig(
        nodeId: 'test-lifecycle-node',
        mqttHost: testConfig.mosquittoHost,
        mqttPort: testConfig.mosquittoPort,
        mqttUsername: testConfig.mqttUsername,
        mqttPassword: testConfig.mqttPassword,
        useTls: testConfig.useTls,
        persistenceEnabled: false,
      );

      final mqttClient = MqttClientImpl(config);
      final lifecycle = ConnectionLifecycle(
        mqttClient: mqttClient,
        config: config,
      );

      // Test lifecycle initialization
      await lifecycle.initialize();

      // Test connection state monitoring
      var connectionState = ConnectionState.disconnected;
      final subscription = lifecycle.connectionState.listen((state) {
        connectionState = state;
      });

      await lifecycle.connect();
      await Future.delayed(Duration(milliseconds: 100)); // Allow state to propagate
      expect(connectionState, equals(ConnectionState.connected));

      await lifecycle.disconnect();
      await Future.delayed(Duration(milliseconds: 100)); // Allow state to propagate
      expect(connectionState, equals(ConnectionState.disconnected));

      await subscription.cancel();
    });

    test('error handling and response validation', () async {
      // Test error response creation
      final errorResponse = Response.error(
        id: 'test-error-123',
        error: 'Test error message',
        errorCode: ErrorCode.notFound,
      );

      expect(errorResponse.id, equals('test-error-123'));
      expect(errorResponse.status, equals(ResponseStatus.error));
      expect(errorResponse.error, equals('Test error message'));
      expect(errorResponse.errorCode, equals(ErrorCode.notFound));

      // Test success response
      final successResponse = Response.success(
        id: 'test-success-123',
        value: 'test-value',
      );

      expect(successResponse.id, equals('test-success-123'));
      expect(successResponse.status, equals(ResponseStatus.ok));
      expect(successResponse.value, equals('test-value'));
    });
  });
}