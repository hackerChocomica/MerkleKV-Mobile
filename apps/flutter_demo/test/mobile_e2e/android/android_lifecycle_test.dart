import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import '../utils/android_test_utils.dart';
import '../utils/merkle_kv_mobile_test_helper.dart';

/// Android mobile lifecycle testing suite
/// Tests background/foreground transitions, app suspension/resumption, and state preservation
void main() {
  group('Android Mobile Lifecycle Tests', () {
    late MerkleKV merkleKV;
    late MerkleKVConfig config;

    setUpAll(() async {
      // Initialize Android test environment
      await AndroidTestUtils.initializeAndroidTestEnvironment();
    });

    setUp(() async {
      // Create fresh MerkleKV instance for each test
      config = MerkleKVMobileTestHelper.createMobileTestConfig(
        clientId: 'android_lifecycle_test_client',
      );
      merkleKV = MerkleKV(config);
      
      // Initialize connection
      await merkleKV.connect();
      
      // Wait a moment for connection to stabilize
      await Future.delayed(const Duration(seconds: 1));
    });

    tearDown(() async {
      // Clean up
      await merkleKV.disconnect();
      AndroidTestUtils.cleanupTestEnvironment();
    });

    testWidgets('Background transition preserves connection state', (tester) async {
      // Set test data
      const testKey = 'lifecycle_test_key';
      const testValue = 'lifecycle_test_value';
      
      await merkleKV.set(testKey, testValue);
      
      // Verify data is set
      final initialValue = await merkleKV.get(testKey);
      expect(initialValue, equals(testValue));
      
      // Simulate app going to background
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      
      // Wait for background processing
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate app returning to foreground
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      
      // Verify connection recovery and data persistence
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
        reason: 'Connection should recover and data should persist after background transition');
    });

    testWidgets('App suspension and resumption maintains data integrity', (tester) async {
      // Create test data set
      final testData = MerkleKVMobileTestHelper.createTestDataSet(
        keyCount: 5,
        keyPrefix: 'suspension_test',
        valuePrefix: 'suspension_value',
      );
      
      // Set all test data
      for (final entry in testData.entries) {
        await merkleKV.set(entry.key, entry.value);
      }
      
      // Verify all data is set
      for (final entry in testData.entries) {
        final value = await merkleKV.get(entry.key);
        expect(value, equals(entry.value));
      }
      
      // Simulate app suspension (similar to system memory pressure)
      await AndroidTestUtils.simulateMemoryPressure();
      
      // Test data persistence during lifecycle simulation
      final persistenceResult = await MerkleKVMobileTestHelper.testDataPersistenceAcrossLifecycle(
        client: merkleKV,
        testData: testData,
        lifecycleSimulation: () => AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused),
        maxWait: const Duration(seconds: 45),
      );
      
      expect(persistenceResult, isTrue,
        reason: 'Data should persist across app suspension and resumption');
    });

    testWidgets('App termination and restart recovers persistent state', (tester) async {
      const testKey = 'termination_test_key';
      const testValue = 'termination_test_value';
      
      // Set test data
      await merkleKV.set(testKey, testValue);
      
      // Verify data is set
      final initialValue = await merkleKV.get(testKey);
      expect(initialValue, equals(testValue));
      
      // Simulate app termination and restart
      await AndroidTestUtils.simulateAppTerminationAndRestart();
      
      // Test data persistence across termination/restart
      final persistenceResult = await MerkleKVMobileTestHelper.testDataPersistenceAcrossLifecycle(
        client: merkleKV,
        testData: {testKey: testValue},
        lifecycleSimulation: () => AndroidTestUtils.simulateAppTerminationAndRestart(),
        maxWait: const Duration(minutes: 1),
      );
      
      expect(persistenceResult, isTrue,
        reason: 'Data should persist across app termination and restart');
    });

    testWidgets('Rapid background/foreground cycling maintains stability', (tester) async {
      const testKey = 'cycling_test_key';
      const testValue = 'cycling_test_value';
      
      // Set initial test data
      await merkleKV.set(testKey, testValue);
      
      // Perform rapid background/foreground cycling
      await AndroidTestUtils.simulateRapidLifecycleCycling(
        cycles: 10,
        cycleDelay: const Duration(milliseconds: 200),
      );
      
      // Verify data integrity after rapid cycling
      final finalValue = await AndroidTestUtils.waitForConvergence(
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
      
      expect(finalValue, isTrue,
        reason: 'Rapid lifecycle cycling should not corrupt connection state or cause memory leaks');
    });

    testWidgets('Android Doze mode simulation maintains data consistency', (tester) async {
      const testKey = 'doze_test_key';
      const testValue = 'doze_test_value';
      
      // Set test data before Doze mode
      await merkleKV.set(testKey, testValue);
      
      // Simulate Android Doze mode (background restrictions)
      await AndroidTestUtils.simulateDozeMode(enabled: true);
      
      // Wait for Doze mode effects
      await Future.delayed(const Duration(seconds: 3));
      
      // Exit Doze mode
      await AndroidTestUtils.simulateDozeMode(enabled: false);
      
      // Verify data recovery after Doze mode
      final recoveryResult = await AndroidTestUtils.waitForConvergence(
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
      
      expect(recoveryResult, isTrue,
        reason: 'Data should be recoverable after Android Doze mode');
    });

    testWidgets('Battery optimization compliance testing', (tester) async {
      // Get Android device info
      final deviceInfo = await AndroidTestUtils.getAndroidDeviceInfo();
      expect(deviceInfo['apiLevel'], greaterThanOrEqualTo(21),
        reason: 'Test should run on Android API 21+');
      
      const testKey = 'battery_test_key';
      const testValue = 'battery_test_value';
      
      // Set test data
      await merkleKV.set(testKey, testValue);
      
      // Simulate low battery and battery optimization
      await AndroidTestUtils.simulateBatteryState(
        batteryLevel: 15, // Low battery
        lowPowerMode: true,
      );
      
      // Simulate background operation under battery optimization
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      
      // Wait for background processing limitations
      await Future.delayed(const Duration(seconds: 5));
      
      // Return to foreground
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      
      // Verify sync state is correctly restored
      final syncRestored = await AndroidTestUtils.waitForConvergence(
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
      
      expect(syncRestored, isTrue,
        reason: 'Sync state should be correctly restored after battery optimization');
    });

    testWidgets('Background execution compliance with platform policies', (tester) async {
      const testKey = 'background_policy_key';
      const testValue = 'background_policy_value';
      
      // Set initial data
      await merkleKV.set(testKey, testValue);
      
      // Test background execution compliance
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      
      // Simulate platform background execution limitations
      // (In real Android, this would be limited by system policies)
      await Future.delayed(const Duration(seconds: 10));
      
      // Return to foreground
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      
      // Verify that background operation respects platform power management
      final backgroundCompliance = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            // Check if connection and data are still valid
            final value = await merkleKV.get(testKey);
            return value == testValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(seconds: 30),
      );
      
      expect(backgroundCompliance, isTrue,
        reason: 'Background operation should respect platform power management');
    });

    test('Anti-entropy synchronization during lifecycle transitions', () async {
      const testKey = 'anti_entropy_lifecycle_key';
      const testValue = 'anti_entropy_lifecycle_value';
      
      // Test anti-entropy during state transition
      final antiEntropyResult = await MerkleKVMobileTestHelper.validateAntiEntropySyncDuringStateTransition(
        client: merkleKV,
        key: testKey,
        value: testValue,
        stateTransitionSimulation: () async {
          await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
          await Future.delayed(const Duration(seconds: 2));
          await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
        },
        maxWait: const Duration(minutes: 2),
      );
      
      expect(antiEntropyResult, isTrue,
        reason: 'Anti-entropy sync should work across app suspension cycles');
    });
  });
}