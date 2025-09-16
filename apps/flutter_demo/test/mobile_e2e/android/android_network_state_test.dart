import 'package:flutter_test/flutter_test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import '../utils/android_test_utils.dart';
import '../utils/merkle_kv_mobile_test_helper.dart';

/// Android network state testing suite
/// Tests airplane mode simulation, WiFi/cellular switching, and network interruption
void main() {
  group('Android Network State Tests', () {
    late MerkleKV merkleKV;
    late MerkleKVConfig config;

    setUpAll(() async {
      // Initialize Android test environment
      await AndroidTestUtils.initializeAndroidTestEnvironment();
    });

    setUp(() async {
      // Create fresh MerkleKV instance for each test
      config = MerkleKVMobileTestHelper.createMobileTestConfig(
        clientId: 'android_network_test_client',
      );
      merkleKV = MerkleKV(config);
      
      // Initialize connection
      await merkleKV.connect();
      
      // Wait for connection to stabilize
      await Future.delayed(const Duration(seconds: 1));
    });

    tearDown(() async {
      // Clean up
      await merkleKV.disconnect();
      AndroidTestUtils.cleanupTestEnvironment();
    });

    testWidgets('Airplane mode toggle triggers proper reconnection', (tester) async {
      const testKey = 'airplane_mode_test_key';
      const testValue = 'airplane_mode_test_value';
      
      // Set test data while connected
      await merkleKV.set(testKey, testValue);
      
      // Verify data is set
      final initialValue = await merkleKV.get(testKey);
      expect(initialValue, equals(testValue));
      
      // Enable airplane mode
      await AndroidTestUtils.simulateAirplaneModeToggle(enabled: true);
      
      // Wait for disconnect effects
      await Future.delayed(const Duration(seconds: 3));
      
      // Disable airplane mode
      await AndroidTestUtils.simulateAirplaneModeToggle(enabled: false);
      
      // Verify automatic reconnection and operation recovery
      final reconnectionResult = await MerkleKVMobileTestHelper.validateConnectionRecovery(
        client: merkleKV,
        connectionInterruption: () => AndroidTestUtils.simulateAirplaneModeToggle(enabled: true),
        maxRecoveryTime: const Duration(minutes: 1),
      );
      
      expect(reconnectionResult, isTrue,
        reason: 'Automatic reconnection should occur after airplane mode is disabled');
      
      // Verify data is still accessible after reconnection
      final recoveredValue = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(seconds: 30),
      );
      
      expect(recoveredValue, isTrue,
        reason: 'Data should be accessible after airplane mode reconnection');
    });

    testWidgets('WiFi to cellular network switching maintains connectivity', (tester) async {
      const testKey = 'network_switch_test_key';
      const testValue = 'network_switch_test_value';
      
      // Start with WiFi connection
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'TestWiFi',
        wifiBSSID: '00:11:22:33:44:55',
      );
      
      // Set test data on WiFi
      await merkleKV.set(testKey, testValue);
      
      // Switch to cellular network
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'mobile',
      );
      
      // Verify connection adapts without data loss
      final networkSwitchResult = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(seconds: 45),
      );
      
      expect(networkSwitchResult, isTrue,
        reason: 'Connection should adapt from WiFi to cellular without data loss');
    });

    testWidgets('Cellular to WiFi network switching maintains connectivity', (tester) async {
      const testKey = 'cellular_to_wifi_test_key';
      const testValue = 'cellular_to_wifi_test_value';
      
      // Start with cellular connection
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'mobile',
      );
      
      // Set test data on cellular
      await merkleKV.set(testKey, testValue);
      
      // Switch to WiFi network
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'NewTestWiFi',
        wifiBSSID: '11:22:33:44:55:66',
      );
      
      // Verify connection adapts without data loss
      final networkSwitchResult = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(seconds: 45),
      );
      
      expect(networkSwitchResult, isTrue,
        reason: 'Connection should adapt from cellular to WiFi without data loss');
    });

    testWidgets('Network interruption and restoration with operation queuing', (tester) async {
      // Create test operations
      final testOperations = [
        const MapEntry('queue_test_1', 'value_1'),
        const MapEntry('queue_test_2', 'value_2'),
        const MapEntry('queue_test_3', 'value_3'),
      ];
      
      // Test operation queuing and replay during network interruption
      final queueingResult = await MerkleKVMobileTestHelper.testOperationQueueingAndReplay(
        client: merkleKV,
        operations: testOperations,
        networkInterruption: () async {
          // Simulate network interruption
          await AndroidTestUtils.simulateNetworkChange(connectivityType: 'none');
          await Future.delayed(const Duration(seconds: 3));
          // Restore network
          await AndroidTestUtils.simulateNetworkChange(
            connectivityType: 'wifi',
            wifiName: 'RestoredWiFi',
          );
        },
        maxWait: const Duration(minutes: 2),
      );
      
      expect(queueingResult, isTrue,
        reason: 'Operations should be queued during network interruption and replayed after restoration');
    });

    testWidgets('Poor connectivity simulation with retry mechanisms', (tester) async {
      const testKey = 'poor_connectivity_test_key';
      const testValue = 'poor_connectivity_test_value';
      
      // Simulate poor connectivity by rapid network state changes
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
      await Future.delayed(const Duration(milliseconds: 500));
      
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'none');
      await Future.delayed(const Duration(milliseconds: 300));
      
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'wifi', wifiName: 'SlowWiFi');
      await Future.delayed(const Duration(milliseconds: 500));
      
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
      
      // Try to set data during poor connectivity
      await merkleKV.set(testKey, testValue);
      
      // Restore stable connectivity
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'StableWiFi',
        wifiBSSID: 'AA:BB:CC:DD:EE:FF',
      );
      
      // Verify data integrity after poor connectivity
      final connectivityResult = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(minutes: 1),
      );
      
      expect(connectivityResult, isTrue,
        reason: 'Data should be preserved and accessible after poor connectivity conditions');
    });

    testWidgets('Multiple network interface changes in sequence', (tester) async {
      const testKey = 'multi_interface_test_key';
      const testValue = 'multi_interface_test_value';
      
      // Set initial data
      await merkleKV.set(testKey, testValue);
      
      // Simulate multiple network interface changes
      final networkSequence = [
        {'type': 'wifi', 'name': 'Home_WiFi'},
        {'type': 'mobile', 'name': null},
        {'type': 'none', 'name': null},
        {'type': 'wifi', 'name': 'Office_WiFi'},
        {'type': 'mobile', 'name': null},
        {'type': 'wifi', 'name': 'Public_WiFi'},
      ];
      
      for (final network in networkSequence) {
        await AndroidTestUtils.simulateNetworkChange(
          connectivityType: network['type'] as String,
          wifiName: network['name'] as String?,
        );
        await Future.delayed(const Duration(seconds: 1));
      }
      
      // Verify data consistency after multiple network changes
      final multiInterfaceResult = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(minutes: 1),
      );
      
      expect(multiInterfaceResult, isTrue,
        reason: 'Data should remain consistent through multiple network interface changes');
    });

    testWidgets('Network restoration after extended offline period', (tester) async {
      const testKey = 'extended_offline_test_key';
      const testValue = 'extended_offline_test_value';
      
      // Set data before going offline
      await merkleKV.set(testKey, testValue);
      
      // Simulate extended offline period
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'none');
      
      // Wait for extended offline period (simulating airplane mode during flight)
      await Future.delayed(const Duration(seconds: 10));
      
      // Restore network connectivity
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'Airport_WiFi',
      );
      
      // Verify automatic reconnection after extended offline period
      final extendedOfflineResult = await MerkleKVMobileTestHelper.validateConnectionRecovery(
        client: merkleKV,
        connectionInterruption: () async {
          await AndroidTestUtils.simulateNetworkChange(connectivityType: 'none');
          await Future.delayed(const Duration(seconds: 5));
        },
        maxRecoveryTime: const Duration(minutes: 2),
      );
      
      expect(extendedOfflineResult, isTrue,
        reason: 'Connection should recover after extended offline period');
      
      // Verify data accessibility after extended offline recovery
      final dataRecoveryResult = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(seconds: 30),
      );
      
      expect(dataRecoveryResult, isTrue,
        reason: 'Data should be accessible after extended offline recovery');
    });

    test('Network state transitions with concurrent operations', () async {
      // Create multiple concurrent operations
      final concurrentOperations = List.generate(10, (index) =>
        MapEntry('concurrent_$index', 'value_$index'));
      
      // Start concurrent operations
      final operationFutures = concurrentOperations.map((op) =>
        merkleKV.set(op.key, op.value).catchError((e) => null)).toList();
      
      // Perform network state transitions during operations
      Future.delayed(const Duration(milliseconds: 100), () async {
        await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
      });
      
      Future.delayed(const Duration(milliseconds: 300), () async {
        await AndroidTestUtils.simulateNetworkChange(connectivityType: 'wifi', wifiName: 'TestWiFi');
      });
      
      // Wait for all operations to complete
      await Future.wait(operationFutures);
      
      // Verify all operations completed successfully
      for (final operation in concurrentOperations) {
        final value = await merkleKV.get(operation.key);
        expect(value, equals(operation.value),
          reason: 'Concurrent operation ${operation.key} should complete despite network transitions');
      }
    });
  });
}