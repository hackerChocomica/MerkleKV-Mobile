import 'package:flutter_test/flutter_test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import '../utils/android_test_utils.dart';
import '../utils/merkle_kv_mobile_test_helper.dart';

/// Android multi-device synchronization testing suite
/// Tests mobile-to-mobile and mobile-to-desktop convergence scenarios
void main() {
  group('Android Multi-Device Synchronization Tests', () {
    late List<MerkleKV> mobileClients;
    late List<MerkleKV> desktopClients;
    late List<MerkleKVConfig> mobileConfigs;
    late List<MerkleKVConfig> desktopConfigs;

    setUpAll(() async {
      // Initialize Android test environment
      await AndroidTestUtils.initializeAndroidTestEnvironment();
    });

    setUp(() async {
      // Create mobile clients (Android devices)
      mobileConfigs = MerkleKVMobileTestHelper.createMultiDeviceConfigs(
        clientCount: 3,
        topicPrefix: 'android_multi_device_mobile',
      );
      
      // Create desktop clients (simulating desktop/server instances)
      desktopConfigs = MerkleKVMobileTestHelper.createMultiDeviceConfigs(
        clientCount: 2,
        topicPrefix: 'android_multi_device_desktop',
      );
      
      mobileClients = [];
      desktopClients = [];
      
      // Initialize mobile clients
      for (final config in mobileConfigs) {
        final client = MerkleKV(config);
        await client.connect();
        mobileClients.add(client);
      }
      
      // Initialize desktop clients
      for (final config in desktopConfigs) {
        final client = MerkleKV(config);
        await client.connect();
        desktopClients.add(client);
      }
      
      // Wait for all clients to stabilize
      await Future.delayed(const Duration(seconds: 3));
    });

    tearDown(() async {
      // Clean up all clients
      for (final client in [...mobileClients, ...desktopClients]) {
        await client.disconnect();
      }
      mobileClients.clear();
      desktopClients.clear();
      AndroidTestUtils.cleanupTestEnvironment();
    });

    test('Mobile-to-mobile synchronization across multiple Android devices', () async {
      const testKey = 'mobile_to_mobile_key';
      const testValue = 'mobile_to_mobile_value';
      
      // Set data on first mobile client
      await mobileClients[0].set(testKey, testValue);
      
      // Verify synchronization across all mobile clients
      final mobileToMobileResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: mobileClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
        pollInterval: const Duration(seconds: 2),
      );
      
      expect(mobileToMobileResult, isTrue,
        reason: 'Data should synchronize across all Android mobile clients');
    });

    test('Mobile-to-desktop synchronization', () async {
      const testKey = 'mobile_to_desktop_key';
      const testValue = 'mobile_to_desktop_value';
      
      // Set data on mobile client
      await mobileClients[1].set(testKey, testValue);
      
      // Verify synchronization to desktop clients
      final mobileToDesktopResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: desktopClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
        pollInterval: const Duration(seconds: 2),
      );
      
      expect(mobileToDesktopResult, isTrue,
        reason: 'Data should synchronize from Android mobile to desktop clients');
    });

    test('Desktop-to-mobile synchronization', () async {
      const testKey = 'desktop_to_mobile_key';
      const testValue = 'desktop_to_mobile_value';
      
      // Set data on desktop client
      await desktopClients[0].set(testKey, testValue);
      
      // Verify synchronization to mobile clients
      final desktopToMobileResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: mobileClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
        pollInterval: const Duration(seconds: 2),
      );
      
      expect(desktopToMobileResult, isTrue,
        reason: 'Data should synchronize from desktop to Android mobile clients');
    });

    test('Multi-device convergence with mobile client going offline/online', () async {
      const testKey = 'offline_online_convergence_key';
      const testValue = 'offline_online_convergence_value';
      
      // Set data across all clients
      await mobileClients[0].set(testKey, testValue);
      
      // Wait for initial convergence
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate mobile client going offline (airplane mode)
      await AndroidTestUtils.simulateAirplaneModeToggle(enabled: true);
      
      // Update data while mobile client is offline
      const updatedValue = 'offline_online_updated_value';
      await desktopClients[0].set(testKey, updatedValue);
      
      // Wait for desktop convergence
      await Future.delayed(const Duration(seconds: 2));
      
      // Bring mobile client back online
      await AndroidTestUtils.simulateAirplaneModeToggle(enabled: false);
      
      // Verify convergence occurs per specification when mobile client comes back online
      final allClients = [...mobileClients, ...desktopClients];
      final offlineOnlineResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: allClients,
        key: testKey,
        expectedValue: updatedValue,
        maxWait: const Duration(minutes: 3),
        pollInterval: const Duration(seconds: 3),
      );
      
      expect(offlineOnlineResult, isTrue,
        reason: 'Convergence should occur when mobile client goes offline/online per specification');
    });

    test('Concurrent operations across mobile and desktop clients', () async {
      final concurrentOperations = {
        'concurrent_mobile_1': 'concurrent_value_mobile_1',
        'concurrent_mobile_2': 'concurrent_value_mobile_2',
        'concurrent_desktop_1': 'concurrent_value_desktop_1',
        'concurrent_desktop_2': 'concurrent_value_desktop_2',
        'concurrent_mixed_1': 'concurrent_value_mixed_1',
      };
      
      // Perform concurrent operations across different client types
      final futures = <Future<void>>[];
      
      // Mobile operations
      futures.add(mobileClients[0].set('concurrent_mobile_1', concurrentOperations['concurrent_mobile_1']!));
      futures.add(mobileClients[1].set('concurrent_mobile_2', concurrentOperations['concurrent_mobile_2']!));
      
      // Desktop operations
      futures.add(desktopClients[0].set('concurrent_desktop_1', concurrentOperations['concurrent_desktop_1']!));
      futures.add(desktopClients[1].set('concurrent_desktop_2', concurrentOperations['concurrent_desktop_2']!));
      
      // Mixed operation
      futures.add(mobileClients[2].set('concurrent_mixed_1', concurrentOperations['concurrent_mixed_1']!));
      
      // Wait for all operations to complete
      await Future.wait(futures);
      
      // Verify convergence across all clients
      final allClients = [...mobileClients, ...desktopClients];
      final concurrentResult = await MerkleKVMobileTestHelper.validateSpecCompliantConvergence(
        clients: allClients,
        testOperations: concurrentOperations,
        maxConvergenceTime: const Duration(minutes: 3),
      );
      
      expect(concurrentResult, isTrue,
        reason: 'Concurrent operations should converge across mobile and desktop clients');
    });

    testWidgets('Mobile client lifecycle changes during multi-device sync', (tester) async {
      const testKey = 'lifecycle_multi_device_key';
      const testValue = 'lifecycle_multi_device_value';
      
      // Set data on desktop client
      await desktopClients[0].set(testKey, testValue);
      
      // Simulate mobile client lifecycle changes during synchronization
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.paused);
      await Future.delayed(const Duration(seconds: 2));
      await AndroidTestUtils.simulateAppLifecycleState(AppLifecycleState.resumed);
      
      // Verify mobile clients receive updates despite lifecycle changes
      final lifecycleMultiDeviceResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: mobileClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
      );
      
      expect(lifecycleMultiDeviceResult, isTrue,
        reason: 'Mobile clients should receive updates despite lifecycle changes');
    });

    test('Network switching during multi-device synchronization', () async {
      const testKey = 'network_switch_multi_key';
      const testValue = 'network_switch_multi_value';
      
      // Start with WiFi connection
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'MultiDeviceTestWiFi',
      );
      
      // Set data on mobile client
      await mobileClients[0].set(testKey, testValue);
      
      // Switch to cellular during synchronization
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'mobile');
      
      // Verify synchronization continues across network switch
      final allClients = [...mobileClients, ...desktopClients];
      final networkSwitchResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: allClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
      );
      
      expect(networkSwitchResult, isTrue,
        reason: 'Multi-device synchronization should continue across network switches');
    });

    test('Battery optimization impact on multi-device sync', () async {
      const testKey = 'battery_multi_device_key';
      const testValue = 'battery_multi_device_value';
      
      // Enable battery optimization on mobile clients
      await AndroidTestUtils.simulateBatteryState(
        batteryLevel: 20,
        lowPowerMode: true,
      );
      
      // Set data on desktop client
      await desktopClients[1].set(testKey, testValue);
      
      // Verify mobile clients sync despite battery optimization
      final batteryMultiDeviceResult = await MerkleKVMobileTestHelper.waitForMultiClientConvergence(
        clients: mobileClients,
        key: testKey,
        expectedValue: testValue,
        maxWait: const Duration(minutes: 2),
      );
      
      expect(batteryMultiDeviceResult, isTrue,
        reason: 'Multi-device sync should work despite battery optimization');
    });

    test('Rapid multi-device operations stress test', () async {
      final stressTestOperations = <String, String>{};
      
      // Generate stress test data
      for (int i = 0; i < 20; i++) {
        stressTestOperations['stress_test_$i'] = 'stress_value_$i';
      }
      
      // Perform rapid operations across all clients
      final allClients = [...mobileClients, ...desktopClients];
      final futures = <Future<void>>[];
      
      int clientIndex = 0;
      for (final entry in stressTestOperations.entries) {
        final client = allClients[clientIndex % allClients.length];
        futures.add(client.set(entry.key, entry.value));
        clientIndex++;
      }
      
      // Wait for all operations to complete
      await Future.wait(futures);
      
      // Verify convergence across all clients
      final stressTestResult = await MerkleKVMobileTestHelper.validateSpecCompliantConvergence(
        clients: allClients,
        testOperations: stressTestOperations,
        maxConvergenceTime: const Duration(minutes: 4),
      );
      
      expect(stressTestResult, isTrue,
        reason: 'Rapid multi-device operations should converge correctly');
    });

    test('Mobile device reconnection after extended offline period', () async {
      const testKey = 'extended_offline_multi_key';
      const testValue = 'extended_offline_multi_value';
      
      // Set initial data
      await mobileClients[0].set(testKey, testValue);
      
      // Wait for initial sync
      await Future.delayed(const Duration(seconds: 2));
      
      // Take mobile client offline for extended period
      await AndroidTestUtils.simulateNetworkChange(connectivityType: 'none');
      
      // Update data on other clients while mobile is offline
      const updatedValue = 'extended_offline_updated_value';
      await desktopClients[0].set(testKey, updatedValue);
      
      // Wait for desktop synchronization
      await Future.delayed(const Duration(seconds: 3));
      
      // Bring mobile client back online after extended period
      await Future.delayed(const Duration(seconds: 7));
      await AndroidTestUtils.simulateNetworkChange(
        connectivityType: 'wifi',
        wifiName: 'ReconnectTestWiFi',
      );
      
      // Verify mobile client catches up with other clients
      final extendedOfflineResult = await AndroidTestUtils.waitForConvergence(
        convergenceCheck: () async {
          try {
            final value = await mobileClients[0].get(testKey);
            return value == updatedValue;
          } catch (e) {
            return false;
          }
        },
        maxWait: const Duration(minutes: 2),
      );
      
      expect(extendedOfflineResult, isTrue,
        reason: 'Mobile client should catch up after extended offline period');
    });

    test('Cross-platform convergence validation', () async {
      final crossPlatformOperations = {
        'cross_platform_android_1': 'android_value_1',
        'cross_platform_android_2': 'android_value_2',
        'cross_platform_desktop_1': 'desktop_value_1',
        'cross_platform_desktop_2': 'desktop_value_2',
      };
      
      // Perform operations with explicit client type identification
      await mobileClients[0].set('cross_platform_android_1', crossPlatformOperations['cross_platform_android_1']!);
      await mobileClients[1].set('cross_platform_android_2', crossPlatformOperations['cross_platform_android_2']!);
      await desktopClients[0].set('cross_platform_desktop_1', crossPlatformOperations['cross_platform_desktop_1']!);
      await desktopClients[1].set('cross_platform_desktop_2', crossPlatformOperations['cross_platform_desktop_2']!);
      
      // Verify cross-platform convergence
      final allClients = [...mobileClients, ...desktopClients];
      final crossPlatformResult = await MerkleKVMobileTestHelper.validateSpecCompliantConvergence(
        clients: allClients,
        testOperations: crossPlatformOperations,
        maxConvergenceTime: const Duration(minutes: 3),
      );
      
      expect(crossPlatformResult, isTrue,
        reason: 'Cross-platform convergence should work between Android and desktop clients');
    });
  });
}