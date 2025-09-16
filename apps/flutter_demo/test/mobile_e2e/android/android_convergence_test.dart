import 'package:flutter_test/flutter_test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import '../utils/android_test_utils.dart';
import '../utils/merkle_kv_mobile_test_helper.dart';

/// Android convergence validation testing suite
/// Tests anti-entropy synchronization during mobile state transitions without hard-coded latency targets
void main() {
  group('Android Convergence Validation Tests', () {
    late List<MerkleKV> testClients;
    late List<MerkleKVConfig> testConfigs;

    setUpAll(() async {
      // Initialize Android test environment
      await AndroidTestUtils.initializeAndroidTestEnvironment();
    });

    setUp(() async {
      // Create multiple test clients for convergence testing
      testConfigs = MerkleKVMobileTestHelper.createMultiDeviceConfigs(
        clientCount: 3,
        topicPrefix: 'android_convergence_test',
      );
      
      testClients = [];
      for (final config in testConfigs) {
        final client = MerkleKV(config);
        await client.connect();
        testClients.add(client);
      }
      
      // Wait for all clients to stabilize
      await Future.delayed(const Duration(seconds: 2));
    });

    tearDown(() async {
      // Clean up all clients
      for (final client in testClients) {
        await client.disconnect();
      }
      testClients.clear();
      AndroidTestUtils.cleanupTestEnvironment();
    });

    test('Anti-entropy synchronization during background/foreground transitions', () async {
      const testKey = 'anti_entropy_bg_fg_key';
      const testValue = 'anti_entropy_bg_fg_value';
      
      // Set data on first client
      await testClients[0].set(testKey, testValue);
      
      // Simulate background transition on all clients
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      
      // Wait for background processing
      await Future.delayed(const Duration(seconds: 3));
      
      // Return to foreground
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      
      // Verify convergence across all clients without hard-coded timing
      final convergenceResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: testClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 3), // Allow reasonable time for convergence
        pollInterval: const Duration(seconds: 2),
      );
      
      expect(convergenceResult, isTrue,
        reason: 'Anti-entropy should ensure convergence across clients after background/foreground transitions');
    });

    test('Anti-entropy synchronization during network state changes', () async {
      const testKey = 'anti_entropy_network_key';
      const testValue = 'anti_entropy_network_value';
      
      // Set data on second client while network is stable
      await testClients[1].set(testKey, testValue);
      
      // Simulate network state changes
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
      await Future.delayed(const Duration(seconds: 1));
      
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'none');
      await Future.delayed(const Duration(seconds: 2));
      
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'ConvergenceTestWiFi',
      );
      
      // Verify convergence occurs after network restoration
      final networkConvergenceResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: testClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
        pollInterval: const Duration(seconds: 3),
      );
      
      expect(networkConvergenceResult, isTrue,
        reason: 'Anti-entropy should ensure convergence after network state changes');
    });

    test('Convergence validation with spec-compliant behavior', () async {
      // Create test operations for spec compliance validation
      final testOperations = {
        'spec_compliant_key_1': 'spec_compliant_value_1',
        'spec_compliant_key_2': 'spec_compliant_value_2',
        'spec_compliant_key_3': 'spec_compliant_value_3',
        'spec_compliant_key_4': 'spec_compliant_value_4',
        'spec_compliant_key_5': 'spec_compliant_value_5',
      };
      
      // Validate payload limits compliance
      for (final entry in testOperations.entries) {
        expect(
          () => MerkleKVMobileTestHelper.validatePayloadLimits(
            key: entry.key,
            value: entry.value,
          ),
          returnsNormally,
          reason: 'All test operations should comply with Locked Spec payload limits',
        );
      }
      
      // Test spec-compliant convergence
      final specComplianceResult = await MerkleKVMobileTestHelper.validateSpecCompliantConvergence(
        clients: testClients,
        testOperations: testOperations,
        maxConvergenceTime: const Duration(minutes: 3),
      );
      
      expect(specComplianceResult, isTrue,
        reason: 'Convergence should comply with Locked Specification requirements');
    });

    test('Anti-entropy during airplane mode simulation', () async {
      const testKey = 'anti_entropy_airplane_key';
      const testValue = 'anti_entropy_airplane_value';
      
      // Set data on third client
      await testClients[2].set(testKey, testValue);
      
      // Simulate airplane mode on and off
      await AndroidTestUtils.simulateAirplaneModeToggle(enabled: true);
      await Future.delayed(const Duration(seconds: 3));
      await AndroidTestUtils.simulateAirplaneModeToggle(enabled: false);
      
      // Verify convergence after airplane mode toggle
      final airplaneModeConvergence = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: testClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
        pollInterval: const Duration(seconds: 2),
      );
      
      expect(airplaneModeConvergence, isTrue,
        reason: 'Anti-entropy should ensure convergence after airplane mode toggle');
    });

    test('Convergence during concurrent mobile state transitions', () async {
      final concurrentOperations = {
        'concurrent_conv_1': 'concurrent_value_1',
        'concurrent_conv_2': 'concurrent_value_2',
        'concurrent_conv_3': 'concurrent_value_3',
      };
      
      // Perform operations on different clients
      final futures = <Future<void>>[];
      int clientIndex = 0;
      
      for (final entry in concurrentOperations.entries) {
        final client = testClients[clientIndex % testClients.length];
        futures.add(client.set(entry.key, entry.value));
        clientIndex++;
      }
      
      // Simulate concurrent state transitions while operations are in progress
      Future.delayed(const Duration(milliseconds: 500), () async {
        await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      });
      
      Future.delayed(const Duration(milliseconds: 1000), () async {
        await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
      });
      
      Future.delayed(const Duration(milliseconds: 1500), () async {
        await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      });
      
      // Wait for operations to complete
      await Future.wait(futures);
      
      // Verify convergence despite concurrent state transitions
      for (final entry in concurrentOperations.entries) {
        final convergenceResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
          clients: testClients,
          key: entry.key,
          expectedValue: entry.value,
          maxWait: const Duration(minutes: 2),
        );
        
        expect(convergenceResult, isTrue,
          reason: 'Convergence should occur for key ${entry.key} despite concurrent state transitions');
      }
    });

    test('Anti-entropy with Android Doze mode simulation', () async {
      const testKey = 'anti_entropy_doze_key';
      const testValue = 'anti_entropy_doze_value';
      
      // Set data before Doze mode
      await testClients[0].set(testKey, testValue);
      
      // Simulate Android Doze mode (background app limitations)
      await AndroidTestUtils.simulateDozeMode(enabled: true);
      
      // Wait for Doze mode effects
      await Future.delayed(const Duration(seconds: 5));
      
      // Exit Doze mode
      await AndroidTestUtils.simulateDozeMode(enabled: false);
      
      // Verify anti-entropy works after Doze mode
      final dozeConvergenceResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: testClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
      );
      
      expect(dozeConvergenceResult, isTrue,
        reason: 'Anti-entropy should work correctly after Android Doze mode');
    });

    test('Convergence validation during rapid lifecycle cycling', () async {
      const testKey = 'rapid_cycle_convergence_key';
      const testValue = 'rapid_cycle_convergence_value';
      
      // Set initial data
      await testClients[1].set(testKey, testValue);
      
      // Perform rapid lifecycle cycling while testing convergence
      final cyclingFuture = AndroidTestUtils.simulateRapidLifecycleCycling(
        cycles: 8,
        cycleDelay: const Duration(milliseconds: 250),
      );
      
      // Wait for cycling to complete
      await cyclingFuture;
      
      // Verify convergence is maintained through rapid cycling
      final rapidCycleConvergence = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: testClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 1),
      );
      
      expect(rapidCycleConvergence, isTrue,
        reason: 'Convergence should be maintained through rapid lifecycle cycling');
    });

    test('Anti-entropy interval compliance during mobile scenarios', () async {
      // Use anti-entropy interval from configuration (60 seconds)
      final antiEntropyInterval = Duration(
        milliseconds: testConfigs[0].antiEntropyIntervalMs,
      );
      
      const testKey = 'interval_compliance_key';
      const testValue = 'interval_compliance_value';
      
      // Set data and measure convergence time
      final stopwatch = Stopwatch()..start();
      await testClients[0].set(testKey, testValue);
      
      // Simulate mobile scenario during anti-entropy
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      await Future.delayed(const Duration(seconds: 2));
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      
      // Wait for convergence
      final convergenceAchieved = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: testClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: Duration(milliseconds: antiEntropyInterval.inMilliseconds * 2),
      );
      
      stopwatch.stop();
      
      expect(convergenceAchieved, isTrue,
        reason: 'Convergence should occur within reasonable time relative to anti-entropy interval');
      
      // Verify convergence occurs within reasonable bounds (not hard-coded latency)
      expect(stopwatch.elapsed.inSeconds, lessThan(antiEntropyInterval.inSeconds * 3),
        reason: 'Convergence should complete within reasonable multiple of anti-entropy interval');
    });

    test('Multi-device convergence with mixed mobile scenarios', () async {
      final mixedScenarioOperations = {
        'mixed_scenario_1': 'mixed_value_1',
        'mixed_scenario_2': 'mixed_value_2',
        'mixed_scenario_3': 'mixed_value_3',
      };
      
      // Simulate different mobile scenarios on different clients
      final scenarioFutures = <Future<void>>[];
      
      // Client 0: Network state changes
      scenarioFutures.add(Future(() async {
        await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
        await Future.delayed(const Duration(seconds: 1));
        await AndroidTestUtils.simulateNetworkChange(connectivityType: 'wifi', wifiName: 'TestNet');
      }));
      
      // Client 1: Lifecycle transitions
      scenarioFutures.add(Future(() async {
        await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
        await Future.delayed(const Duration(seconds: 2));
        await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      }));
      
      // Client 2: Battery optimization
      scenarioFutures.add(Future(() async {
        await AndroidTestUtils.simulateBatteryState(batteryLevel: 20, lowPowerMode: true);
        await Future.delayed(const Duration(seconds: 1));
        await AndroidTestUtils.simulateBatteryState(batteryLevel: 80, lowPowerMode: false);
      }));
      
      // Perform operations while scenarios are running
      int clientIndex = 0;
      for (final entry in mixedScenarioOperations.entries) {
        await testClients[clientIndex % testClients.length].set(entry.key, entry.value);
        clientIndex++;
      }
      
      // Wait for all scenarios to complete
      await Future.wait(scenarioFutures);
      
      // Verify convergence across all mixed scenarios
      final mixedScenarioResult = await MerkleKVMobileTestHelper.validateSpecCompliantConvergence(
        clients: testClients,
        testOperations: mixedScenarioOperations,
        maxConvergenceTime: const Duration(minutes: 3),
      );
      
      expect(mixedScenarioResult, isTrue,
        reason: 'Convergence should occur across clients experiencing different mobile scenarios');
    });
  });
}