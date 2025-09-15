/// Integration test configuration utilities
library integration_test_config;

import 'package:merkle_kv_core/merkle_kv_core.dart';

/// Test configuration constants for integration tests
class IntegrationTestConfig {
  // Broker endpoints
  static const mosquittoHost = 'localhost';
  static const mosquittoPort = 1883;
  static const mosquittoTlsPort = 8883;
  
  static const hivemqHost = 'localhost';
  static const hivemqPort = 1884;
  static const hivemqTlsPort = 8884;
  
  // Toxiproxy endpoints for network simulation
  static const toxiproxyHost = 'localhost';
  static const toxiproxyPort = 8474;
  static const proxiedMosquittoPort = 1885;
  static const proxiedMosquittoTlsPort = 8885;
  static const proxiedHivemqPort = 1886;
  static const proxiedHivemqTlsPort = 8886;
  
  // Test credentials
  static const testUsername = 'admin';
  static const testPassword = 'admin123';
  
  // Locked Spec compliance constants
  static const maxValueSize = 256 * 1024; // 256KiB
  static const maxBulkOperationSize = 512 * 1024; // 512KiB
  static const defaultAntiEntropyInterval = Duration(seconds: 30);
  static const convergenceTimeoutVariance = 0.2; // ±20%
  
  // Test timing constants
  static const connectionTimeout = Duration(seconds: 10);
  static const operationTimeout = Duration(seconds: 5);
  static const convergenceTimeout = Duration(seconds: 60);
  static const brokerStartupDelay = Duration(seconds: 5);
}

/// Factory methods for creating test configurations
class TestConfigurations {
  /// Basic Mosquitto configuration for integration tests
  static MerkleKVConfig mosquittoBasic({
    required String clientId,
    required String nodeId,
    String topicPrefix = 'test_mkv',
  }) {
    return MerkleKVConfig(
      mqttHost: IntegrationTestConfig.mosquittoHost,
      mqttPort: IntegrationTestConfig.mosquittoPort,
      mqttUseTls: false,
      clientId: clientId,
      nodeId: nodeId,
      topicPrefix: topicPrefix,
      keepAliveSeconds: 30,
      connectionTimeoutSeconds: 10,
    );
  }
  
  /// TLS Mosquitto configuration for security tests
  static MerkleKVConfig mosquittoTls({
    required String clientId,
    required String nodeId,
    String topicPrefix = 'test_mkv_tls',
    String? username,
    String? password,
  }) {
    return MerkleKVConfig(
      mqttHost: IntegrationTestConfig.mosquittoHost,
      mqttPort: IntegrationTestConfig.mosquittoTlsPort,
      mqttUseTls: true,
      username: username,
      password: password,
      clientId: clientId,
      nodeId: nodeId,
      topicPrefix: topicPrefix,
      keepAliveSeconds: 30,
      connectionTimeoutSeconds: 10,
    );
  }
  
  /// Basic HiveMQ configuration for broker compatibility tests
  static MerkleKVConfig hivemqBasic({
    required String clientId,
    required String nodeId,
    String topicPrefix = 'test_mkv_hive',
  }) {
    return MerkleKVConfig(
      mqttHost: IntegrationTestConfig.hivemqHost,
      mqttPort: IntegrationTestConfig.hivemqPort,
      mqttUseTls: false,
      clientId: clientId,
      nodeId: nodeId,
      topicPrefix: topicPrefix,
      keepAliveSeconds: 30,
      connectionTimeoutSeconds: 10,
    );
  }
  
  /// TLS HiveMQ configuration for security tests
  static MerkleKVConfig hivemqTls({
    required String clientId,
    required String nodeId,
    String topicPrefix = 'test_mkv_hive_tls',
  }) {
    return MerkleKVConfig(
      mqttHost: IntegrationTestConfig.hivemqHost,
      mqttPort: IntegrationTestConfig.hivemqTlsPort,
      mqttUseTls: true,
      clientId: clientId,
      nodeId: nodeId,
      topicPrefix: topicPrefix,
      keepAliveSeconds: 30,
      connectionTimeoutSeconds: 10,
    );
  }
  
  /// Proxied configuration for network partition testing
  static MerkleKVConfig mosquittoProxied({
    required String clientId,
    required String nodeId,
    String topicPrefix = 'test_mkv_proxy',
  }) {
    return MerkleKVConfig(
      mqttHost: IntegrationTestConfig.toxiproxyHost,
      mqttPort: IntegrationTestConfig.proxiedMosquittoPort,
      mqttUseTls: false,
      clientId: clientId,
      nodeId: nodeId,
      topicPrefix: topicPrefix,
      keepAliveSeconds: 30,
      connectionTimeoutSeconds: 10,
    );
  }
  
  /// Configuration with anti-entropy for convergence testing
  static MerkleKVConfig withAntiEntropy({
    required String clientId,
    required String nodeId,
    Duration antiEntropyInterval = const Duration(seconds: 30),
    String topicPrefix = 'test_mkv_ae',
  }) {
    return MerkleKVConfig(
      mqttHost: IntegrationTestConfig.mosquittoHost,
      mqttPort: IntegrationTestConfig.mosquittoPort,
      mqttUseTls: false,
      clientId: clientId,
      nodeId: nodeId,
      topicPrefix: topicPrefix,
      keepAliveSeconds: 30,
      connectionTimeoutSeconds: 10,
      // Note: Anti-entropy interval would be configured at client level
    );
  }
}

/// Utility class for generating test data
class TestDataGenerator {
  /// Generate a string of specified size for payload testing
  static String generatePayload(int sizeInBytes) {
    const char = 'A';
    return char * sizeInBytes;
  }
  
  /// Generate 256KiB payload for Locked Spec compliance testing
  static String generate256KiBPayload() {
    return generatePayload(IntegrationTestConfig.maxValueSize);
  }
  
  /// Generate payload slightly over 256KiB to test limits
  static String generateOversizedPayload() {
    return generatePayload(IntegrationTestConfig.maxValueSize + 1024);
  }
  
  /// Generate bulk operation data totaling 512KiB
  static Map<String, String> generateBulkOperationData() {
    const entrySize = 10 * 1024; // 10KiB per entry
    const entryCount = 51; // 51 * 10KiB = 510KiB (under limit)
    
    final result = <String, String>{};
    for (int i = 0; i < entryCount; i++) {
      result['bulk_key_$i'] = generatePayload(entrySize);
    }
    return result;
  }
  
  /// Generate unique client ID for test isolation
  static String generateClientId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_${timestamp}_${_randomSuffix()}';
  }
  
  /// Generate unique node ID for test isolation
  static String generateNodeId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_node_${timestamp}_${_randomSuffix()}';
  }
  
  static String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecond % chars.length;
    return chars[random] + chars[(random + 1) % chars.length];
  }
}