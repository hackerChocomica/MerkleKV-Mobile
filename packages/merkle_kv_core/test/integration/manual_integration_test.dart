#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';
import 'package:merkle_kv_core/merkle_kv_core.dart';

/// Manual integration test script to validate MQTT broker connectivity
/// This script tests the integration with real brokers without using the broken dart test framework
void main() async {
  print('🚀 Starting MQTT Broker Integration Tests');
  
  // Test configuration
  final mosquittoHost = 'localhost';
  final mosquittoPort = 1883;
  final timeout = Duration(seconds: 10);
  
  print('\n📡 Testing Mosquitto broker connectivity...');
  
  try {
    // Test basic MQTT connection
    await _testMosquittoConnection(mosquittoHost, mosquittoPort, timeout);
    
    // Test MQTT publish/subscribe
    await _testMqttPubSub(mosquittoHost, mosquittoPort, timeout);
    
    // Test storage operations
    await _testStorageOperations();
    
    // Test command/response flow
    await _testCommandResponseFlow(mosquittoHost, mosquittoPort, timeout);
    
    print('\n✅ All integration tests passed!');
    print('🎉 MQTT broker integration is working correctly');
    
  } catch (e, stackTrace) {
    print('\n❌ Integration test failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

/// Test basic MQTT connection to Mosquitto broker
Future<void> _testMosquittoConnection(String host, int port, Duration timeout) async {
  print('  • Testing connection to $host:$port...');
  
  final config = MerkleKVConfig(
    nodeId: 'integration-test-node',
    mqttHost: host,
    mqttPort: port,
    useTls: false,
    persistenceEnabled: false,
  );

  final mqttClient = MqttClientImpl(config);
  
  try {
    await mqttClient.connect().timeout(timeout);
    
    if (!mqttClient.isConnected) {
      throw Exception('Connection failed - client reports disconnected');
    }
    
    print('    ✅ Connected successfully');
    
    await mqttClient.disconnect();
    
    if (mqttClient.isConnected) {
      throw Exception('Disconnection failed - client still reports connected');
    }
    
    print('    ✅ Disconnected successfully');
    
  } catch (e) {
    throw Exception('MQTT connection test failed: $e');
  }
}

/// Test MQTT publish/subscribe functionality
Future<void> _testMqttPubSub(String host, int port, Duration timeout) async {
  print('  • Testing MQTT publish/subscribe...');
  
  final config = MerkleKVConfig(
    nodeId: 'pubsub-test-node',
    mqttHost: host,
    mqttPort: port,
    useTls: false,
    persistenceEnabled: false,
  );

  final mqttClient = MqttClientImpl(config);
  final topicScheme = TopicScheme(config.nodeId);
  
  try {
    await mqttClient.connect().timeout(timeout);
    
    // Set up subscription
    final receivedMessages = <String>[];
    final testTopic = topicScheme.commandTopic('test-target');
    
    await mqttClient.subscribe(testTopic, (topic, payload) {
      receivedMessages.add(payload);
    });
    
    print('    ✅ Subscribed to topic: $testTopic');
    
    // Publish test message
    final testMessage = '{"test": "integration", "timestamp": ${DateTime.now().millisecondsSinceEpoch}}';
    await mqttClient.publish(testTopic, testMessage);
    
    print('    ✅ Published test message');
    
    // Wait for message delivery
    await Future.delayed(Duration(milliseconds: 500));
    
    if (receivedMessages.isEmpty) {
      throw Exception('No messages received - pub/sub not working');
    }
    
    if (receivedMessages.first != testMessage) {
      throw Exception('Message content mismatch - expected: $testMessage, got: ${receivedMessages.first}');
    }
    
    print('    ✅ Message received correctly');
    
    await mqttClient.disconnect();
    
  } catch (e) {
    throw Exception('MQTT pub/sub test failed: $e');
  }
}

/// Test storage operations
Future<void> _testStorageOperations() async {
  print('  • Testing storage operations...');
  
  final config = MerkleKVConfig(
    nodeId: 'storage-test-node',
    persistenceEnabled: false,
  );

  final storage = InMemoryStorage(config);
  await storage.initialize();
  
  try {
    // Test SET operation
    final testKey = 'integration:test:key';
    final testValue = {'data': 'integration test', 'timestamp': DateTime.now().millisecondsSinceEpoch};
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final setEntry = StorageEntry.value(
      key: testKey,
      value: testValue,
      timestamp: timestamp,
      nodeId: config.nodeId,
    );

    await storage.set(testKey, setEntry);
    print('    ✅ SET operation successful');
    
    // Test GET operation
    final retrievedEntry = await storage.get(testKey);
    if (retrievedEntry == null) {
      throw Exception('GET operation failed - entry not found');
    }
    
    if (retrievedEntry.key != testKey) {
      throw Exception('GET operation failed - key mismatch');
    }
    
    print('    ✅ GET operation successful');
    
    // Test DELETE operation (tombstone)
    final deleteEntry = StorageEntry.tombstone(
      key: testKey,
      timestamp: timestamp + 1000,
      nodeId: config.nodeId,
    );

    await storage.set(testKey, deleteEntry);
    
    final deletedEntry = await storage.get(testKey);
    if (deletedEntry != null) {
      throw Exception('DELETE operation failed - entry still exists');
    }
    
    print('    ✅ DELETE operation successful');
    
  } catch (e) {
    throw Exception('Storage operations test failed: $e');
  }
}

/// Test command/response flow
Future<void> _testCommandResponseFlow(String host, int port, Duration timeout) async {
  print('  • Testing command/response flow...');
  
  final config = MerkleKVConfig(
    nodeId: 'command-test-node',
    mqttHost: host,
    mqttPort: port,
    useTls: false,
    persistenceEnabled: false,
  );

  final mqttClient = MqttClientImpl(config);
  final topicScheme = TopicScheme(config.nodeId);
  
  try {
    await mqttClient.connect().timeout(timeout);
    
    // Test command creation and validation
    final command = Command(
      id: 'integration-test-command-123',
      op: 'GET',
      key: 'test-key',
    );

    if (command.id != 'integration-test-command-123') {
      throw Exception('Command creation failed - ID mismatch');
    }
    
    if (command.op != 'GET') {
      throw Exception('Command creation failed - operation mismatch');
    }
    
    if (command.key != 'test-key') {
      throw Exception('Command creation failed - key mismatch');
    }
    
    print('    ✅ Command creation successful');
    
    // Test command serialization
    final commandJson = command.toJsonString();
    if (!commandJson.contains('integration-test-command-123')) {
      throw Exception('Command serialization failed');
    }
    
    print('    ✅ Command serialization successful');
    
    // Test response creation
    final successResponse = Response.success(
      id: command.id,
      value: 'test-response-value',
    );

    if (successResponse.id != command.id) {
      throw Exception('Response creation failed - ID mismatch');
    }
    
    if (successResponse.status != ResponseStatus.ok) {
      throw Exception('Response creation failed - status mismatch');
    }
    
    print('    ✅ Response creation successful');
    
    // Test error response
    final errorResponse = Response.error(
      id: command.id,
      error: 'Test error message',
      errorCode: ErrorCode.notFound,
    );

    if (errorResponse.status != ResponseStatus.error) {
      throw Exception('Error response creation failed - status mismatch');
    }
    
    if (errorResponse.errorCode != ErrorCode.notFound) {
      throw Exception('Error response creation failed - error code mismatch');
    }
    
    print('    ✅ Error response creation successful');
    
    await mqttClient.disconnect();
    
  } catch (e) {
    throw Exception('Command/response flow test failed: $e');
  }
}