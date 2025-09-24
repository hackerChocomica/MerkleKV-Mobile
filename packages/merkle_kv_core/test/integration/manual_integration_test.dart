import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

import 'test_config.dart';
import '../utils/test_broker_helper.dart';

void main() {
  group('Basic Manual Integration Tests', () {
    setUpAll(() async {
      await TestBrokerHelper.ensureBroker(port: IntegrationTestConfig.mosquittoPort);
    });
    test('MQTT client basic lifecycle', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'manual-test-client',
        nodeId: 'manual-test-node',
      );

      final mqttClient = MqttClientImpl(config);

      try {
        // Test connection
        await mqttClient.connect();

        // Wait for connection to establish
        await Future.delayed(Duration(milliseconds: 200));

        // Test basic publish
        await mqttClient.publish('test/manual', 'manual test message');

        // Test disconnection
        await mqttClient.disconnect();
      } catch (e) {
        try {
          await mqttClient.disconnect();
        } catch (_) {}
        rethrow;
      }
    });

    test('Storage operations basic functionality', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'manual-storage-client',
        nodeId: 'manual-storage-node',
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();

      final testKey = 'manual-test-key';
      final testValue = 'manual test value';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Test PUT operation
      final entry = StorageEntry.value(
        key: testKey,
        value: testValue,
        timestampMs: timestamp,
        nodeId: config.nodeId,
        seq: 1,
      );

      await storage.put(testKey, entry);

      // Test GET operation
      final retrievedEntry = await storage.get(testKey);
      expect(retrievedEntry, isNotNull);
      expect(retrievedEntry!.value, equals(testValue));
      expect(retrievedEntry.key, equals(testKey));

      // Test DELETE operation
      await storage.delete(testKey, timestamp + 1000, config.nodeId, 2);

      final deletedEntry = await storage.get(testKey);
      expect(deletedEntry, isNull);
    });

    test('Topic scheme basic functionality', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'manual-topic-client',
        nodeId: 'manual-topic-node',
      );

      final topicScheme =
          TopicScheme.create(config.topicPrefix, config.clientId);

      // Test topic generation
      final commandTopic = topicScheme.commandTopic;
      final responseTopic = topicScheme.responseTopic;
      final replicationTopic = topicScheme.replicationTopic;

      // Verify topics are properly formed
      expect(commandTopic, contains(config.clientId));
      expect(commandTopic, contains('cmd'));

      expect(responseTopic, contains(config.clientId));
      expect(responseTopic, contains('res'));

      expect(replicationTopic, contains('replication'));
      expect(replicationTopic, contains('events'));

      // All topics should be non-empty
      expect(commandTopic, isNotEmpty);
      expect(responseTopic, isNotEmpty);
      expect(replicationTopic, isNotEmpty);
    });

    test('Command and response basic serialization', () async {
      // Test command creation and serialization
      final command = Command.set(
        id: 'manual-cmd-123',
        key: 'manual-key',
        value: 'manual value',
      );

      final commandJson = command.toJsonString();
      expect(commandJson, contains('manual-cmd-123'));
      expect(commandJson, contains('SET'));
      expect(commandJson, contains('manual-key'));

      // Test command deserialization
      final parsedCommand = Command.fromJsonString(commandJson);
      expect(parsedCommand.id, equals(command.id));
      expect(parsedCommand.op, equals(command.op));
      expect(parsedCommand.key, equals(command.key));

      // Test response creation and serialization
      final response = Response.ok(
        id: 'manual-resp-123',
        value: 'manual response value',
      );

      final responseJson = response.toJsonString();
      expect(responseJson, contains('manual-resp-123'));
      expect(responseJson, contains('OK'));

      // Test response deserialization
      final parsedResponse = Response.fromJsonString(responseJson);
      expect(parsedResponse.id, equals(response.id));
      expect(parsedResponse.status, equals(response.status));
      expect(parsedResponse.value, equals(response.value));
    });

    test('Integration environment validation', () async {
      // Verify test configuration is valid
      expect(IntegrationTestConfig.mosquittoHost, isNotEmpty);
      expect(IntegrationTestConfig.mosquittoPort, greaterThan(0));
      expect(IntegrationTestConfig.mosquittoPort, lessThan(65536));

      // Test data generator works
      final clientId = TestDataGenerator.generateClientId('test');
      final nodeId = TestDataGenerator.generateNodeId('test');

      expect(clientId, isNotEmpty);
      expect(nodeId, isNotEmpty);
      expect(clientId, contains('test'));
      expect(nodeId, contains('test'));
    });

    test('Error handling basic scenarios', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'manual-error-client',
        nodeId: 'manual-error-node',
      );

      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);

      // Test GET on non-existent key
      final getResponse = await processor.get('nonexistent-key', 'error-cmd-1');
      expect(getResponse.status, equals(ResponseStatus.error));
      expect(getResponse.id, equals('error-cmd-1'));

      // Test that error responses contain proper information
      expect(getResponse.error, isNotNull);
      expect(getResponse.errorCode, isNotNull);

      // Test that valid operations still work after errors
      final setResponse =
          await processor.set('valid-key', 'valid-value', 'error-cmd-2');
      expect(setResponse.status, equals(ResponseStatus.ok));
      expect(setResponse.id, equals('error-cmd-2'));
    });
  });
}
