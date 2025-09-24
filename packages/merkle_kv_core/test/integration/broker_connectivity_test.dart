import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import 'test_config.dart';
import '../utils/test_broker_helper.dart';

void main() {
  group('Basic MQTT Broker Connectivity', () {
    setUpAll(() async {
      // Ensure broker present (start embedded if needed, unless IT_REQUIRE_BROKER=1)
      await TestBrokerHelper.ensureBroker(port: IntegrationTestConfig.mosquittoPort);
      // Validate test environment
      expect(IntegrationTestConfig.mosquittoHost, isNotEmpty,
          reason: 'MQTT broker host must be configured');
      expect(IntegrationTestConfig.mosquittoPort, greaterThan(0),
          reason: 'MQTT broker port must be valid');
    });

    test('MQTT connection establishment with Mosquitto broker', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'test-client-basic',
        nodeId: 'test-node-basic',
      );

      final mqttClient = MqttClientImpl(config);

      // Test connection
      await mqttClient.connect();

      // Wait a moment for connection to establish
      await Future.delayed(Duration(milliseconds: 100));

      // Test disconnection
      await mqttClient.disconnect();
    });

    test('storage operations with in-memory backend', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'test-storage-client-basic',
        nodeId: 'test-storage-node-basic',
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();

      // Test basic storage operations
      final testKey = 'test-storage-key';
      final testValue = 'test-storage-value';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Test PUT operation
      final setEntry = StorageEntry.value(
        key: testKey,
        value: testValue,
        timestampMs: timestamp,
        nodeId: config.nodeId,
        seq: 1,
      );

      await storage.put(testKey, setEntry);

      // Test GET operation
      final retrievedEntry = await storage.get(testKey);
      expect(retrievedEntry, isNotNull);
      expect(retrievedEntry!.value, equals(testValue));
      expect(retrievedEntry.key, equals(testKey));

      // Test DELETE operation (tombstone)
      final deleteEntry = StorageEntry.tombstone(
        key: testKey,
        timestampMs: timestamp + 1000,
        nodeId: config.nodeId,
        seq: 2,
      );

      await storage.put(testKey, deleteEntry);

      final deletedEntry = await storage.get(testKey);
      expect(deletedEntry, isNull); // Tombstones return null on get
    });

    test('topic scheme creation and validation', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'test-topic-client-basic',
        nodeId: 'test-topic-node-basic',
      );

      final topicScheme =
          TopicScheme.create(config.topicPrefix, config.clientId);

      // Test topic generation
      final commandTopic = topicScheme.commandTopic;
      final responseTopic = topicScheme.responseTopic;
      final replicationTopic = topicScheme.replicationTopic;

      expect(commandTopic, contains('cmd'));
      expect(responseTopic, contains('res'));
      expect(replicationTopic, contains('replication'));

      // Test topic validation (check that they're non-empty valid strings)
      expect(commandTopic, isNotEmpty);
      expect(responseTopic, isNotEmpty);
      expect(replicationTopic, isNotEmpty);
    });

    test('command processor basic functionality', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'test-processor-client-basic',
        nodeId: 'test-processor-node-basic',
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);

      // Test GET command on non-existent key
      final getResponse = await processor.get('nonexistent-key', 'test-id-1');
      expect(getResponse.status, equals(ResponseStatus.error));

      // Test SET command
      final setResponse =
          await processor.set('test-key', 'test-value', 'test-id-2');
      expect(setResponse.status, equals(ResponseStatus.ok));

      // Test GET command on existing key
      final getResponse2 = await processor.get('test-key', 'test-id-3');
      expect(getResponse2.status, equals(ResponseStatus.ok));
      expect(getResponse2.value, equals('test-value'));

      // Test DELETE command
      final deleteResponse = await processor.delete('test-key', 'test-id-4');
      expect(deleteResponse.status, equals(ResponseStatus.ok));

      // Test GET command on deleted key
      final getResponse3 = await processor.get('test-key', 'test-id-5');
      expect(getResponse3.status, equals(ResponseStatus.error));
    });
  });
}
