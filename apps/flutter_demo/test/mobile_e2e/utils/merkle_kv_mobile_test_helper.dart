import 'dart:async';
import 'dart:math';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for MerkleKV integration testing on mobile platforms
class MerkleKVMobileTestHelper {
  static const String defaultTopicPrefix = 'merkle_kv_test';
  static const String defaultBrokerHost = 'localhost';
  static const int defaultBrokerPort = 1883;

  /// Create a test MerkleKV configuration for mobile testing
  static MerkleKVConfig createMobileTestConfig({
    String? clientId,
    String topicPrefix = defaultTopicPrefix,
    String brokerHost = defaultBrokerHost,
    int brokerPort = defaultBrokerPort,
    Duration? antiEntropyIntervalMs,
    bool enablePersistence = true,
  }) {
    final config = MerkleKVConfig(
      clientId: clientId ?? _generateTestClientId(),
      topicPrefix: topicPrefix,
      brokerHost: brokerHost,
      brokerPort: brokerPort,
      // Use reasonable intervals for mobile testing - not hard-coded latency targets
      antiEntropyIntervalMs: antiEntropyIntervalMs?.inMilliseconds ?? 60000, // 1 minute
      // Mobile-optimized timeouts based on Locked Spec
      singleKeyTimeoutMs: 10000, // 10 seconds
      multiKeyTimeoutMs: 20000,  // 20 seconds
      syncTimeoutMs: 30000,      // 30 seconds
      enablePersistence: enablePersistence,
      // Mobile-friendly connection settings
      maxReconnectionDelay: const Duration(minutes: 1),
      connectionTimeout: const Duration(seconds: 30),
      keepAliveInterval: const Duration(seconds: 60),
    );

    return config;
  }

  /// Create multiple test clients for multi-device testing
  static List<MerkleKVConfig> createMultiDeviceConfigs({
    required int clientCount,
    String topicPrefix = defaultTopicPrefix,
    String brokerHost = defaultBrokerHost,
    int brokerPort = defaultBrokerPort,
  }) {
    return List.generate(clientCount, (index) {
      return createMobileTestConfig(
        clientId: 'mobile_test_client_$index',
        topicPrefix: topicPrefix,
        brokerHost: brokerHost,
        brokerPort: brokerPort,
      );
    });
  }

  /// Wait for convergence between multiple clients without hard-coded timing
  static Future<bool> waitForMultiClientConvergence({
    required List<MerkleKV> clients,
    required String key,
    required String expectedValue,
    Duration maxWait = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < maxWait) {
      bool allConverged = true;

      for (final client in clients) {
        try {
          final value = await client.get(key);
          if (value != expectedValue) {
            allConverged = false;
            break;
          }
        } catch (e) {
          // Client might not have the key yet
          allConverged = false;
          break;
        }
      }

      if (allConverged) {
        return true;
      }

      await Future.delayed(pollInterval);
    }

    return false;
  }

  /// Validate anti-entropy synchronization during mobile state transitions
  static Future<bool> validateAntiEntropySyncDuringStateTransition({
    required MerkleKV client,
    required String key,
    required String value,
    required Future<void> Function() stateTransitionSimulation,
    Duration maxWait = const Duration(minutes: 3),
  }) async {
    // Set a value before state transition
    await client.set(key, value);
    
    // Perform state transition (e.g., background/foreground, network change)
    await stateTransitionSimulation();
    
    // Wait for anti-entropy to complete synchronization
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxWait) {
      try {
        final retrievedValue = await client.get(key);
        if (retrievedValue == value) {
          return true;
        }
      } catch (e) {
        // Continue waiting if operation fails during state transition
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }
    
    return false;
  }

  /// Test operation queuing and replay after network restoration
  static Future<bool> testOperationQueueingAndReplay({
    required MerkleKV client,
    required List<MapEntry<String, String>> operations,
    required Future<void> Function() networkInterruption,
    Duration maxWait = const Duration(minutes: 2),
  }) async {
    final operationFutures = <Future<void>>[];
    
    // Start operations before network interruption
    for (final operation in operations) {
      operationFutures.add(
        client.set(operation.key, operation.value).catchError((e) {
          // Operations might fail during network interruption
          return null;
        })
      );
    }
    
    // Simulate network interruption
    await networkInterruption();
    
    // Wait for all operations to complete or fail
    await Future.wait(operationFutures);
    
    // Wait for network restoration and operation replay
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxWait) {
      bool allOperationsCompleted = true;
      
      for (final operation in operations) {
        try {
          final value = await client.get(operation.key);
          if (value != operation.value) {
            allOperationsCompleted = false;
            break;
          }
        } catch (e) {
          allOperationsCompleted = false;
          break;
        }
      }
      
      if (allOperationsCompleted) {
        return true;
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }
    
    return false;
  }

  /// Test data persistence across app lifecycle events
  static Future<bool> testDataPersistenceAcrossLifecycle({
    required MerkleKV client,
    required Map<String, String> testData,
    required Future<void> Function() lifecycleSimulation,
    Duration maxWait = const Duration(minutes: 1),
  }) async {
    // Set test data
    for (final entry in testData.entries) {
      await client.set(entry.key, entry.value);
    }
    
    // Simulate lifecycle event (e.g., app termination/restart)
    await lifecycleSimulation();
    
    // Verify data persistence
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxWait) {
      bool allDataPersisted = true;
      
      for (final entry in testData.entries) {
        try {
          final value = await client.get(entry.key);
          if (value != entry.value) {
            allDataPersisted = false;
            break;
          }
        } catch (e) {
          allDataPersisted = false;
          break;
        }
      }
      
      if (allDataPersisted) {
        return true;
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return false;
  }

  /// Validate connection recovery within configured timeout
  static Future<bool> validateConnectionRecovery({
    required MerkleKV client,
    required Future<void> Function() connectionInterruption,
    Duration maxRecoveryTime = const Duration(minutes: 1),
  }) async {
    // Interrupt connection
    await connectionInterruption();
    
    // Wait for connection recovery
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxRecoveryTime) {
      try {
        // Try a simple operation to test connectivity
        await client.get('connection_test_key');
        return true;
      } catch (e) {
        // Connection not yet recovered
      }
      
      await Future.delayed(const Duration(seconds: 1));
    }
    
    return false;
  }

  /// Generate unique client ID for testing
  static String _generateTestClientId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'mobile_test_${timestamp}_$random';
  }

  /// Create test data sets for various scenarios
  static Map<String, String> createTestDataSet({
    int keyCount = 10,
    String keyPrefix = 'test_key',
    String valuePrefix = 'test_value',
  }) {
    final testData = <String, String>{};
    
    for (int i = 0; i < keyCount; i++) {
      testData['${keyPrefix}_$i'] = '${valuePrefix}_$i';
    }
    
    return testData;
  }

  /// Validate payload limits compliance (per Locked Spec §11)
  static bool validatePayloadLimits({
    required String key,
    required String value,
  }) {
    // Key size limit: ≤256 bytes
    if (key.length > 256) {
      throw ArgumentError('Key size exceeds 256 bytes limit');
    }
    
    // Value size limit: ≤256 KiB
    if (value.length > 256 * 1024) {
      throw ArgumentError('Value size exceeds 256 KiB limit');
    }
    
    return true;
  }

  /// Validate spec-compliant convergence behavior
  static Future<bool> validateSpecCompliantConvergence({
    required List<MerkleKV> clients,
    required Map<String, String> testOperations,
    Duration maxConvergenceTime = const Duration(minutes: 3),
  }) async {
    // Perform operations on different clients
    final futures = <Future<void>>[];
    final clientCount = clients.length;
    
    int clientIndex = 0;
    for (final entry in testOperations.entries) {
      final client = clients[clientIndex % clientCount];
      futures.add(client.set(entry.key, entry.value));
      clientIndex++;
    }
    
    // Wait for all operations to complete
    await Future.wait(futures);
    
    // Wait for convergence across all clients
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxConvergenceTime) {
      bool allClientsConverged = true;
      
      for (final entry in testOperations.entries) {
        for (final client in clients) {
          try {
            final value = await client.get(entry.key);
            if (value != entry.value) {
              allClientsConverged = false;
              break;
            }
          } catch (e) {
            allClientsConverged = false;
            break;
          }
        }
        
        if (!allClientsConverged) break;
      }
      
      if (allClientsConverged) {
        return true;
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }
    
    return false;
  }
}