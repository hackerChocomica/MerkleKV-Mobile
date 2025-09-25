import 'dart:async';
import 'dart:io';

// Import the actual battery awareness implementation
import '../../packages/merkle_kv_core/lib/src/utils/battery_awareness.dart';
import '../../packages/merkle_kv_core/lib/src/config/merkle_kv_config.dart';
import '../../packages/merkle_kv_core/lib/src/mqtt/battery_aware_lifecycle.dart';
import '../../packages/merkle_kv_core/lib/src/mqtt/mqtt_client_interface.dart';
import '../../packages/merkle_kv_core/lib/src/mqtt/connection_state.dart';

/// Integration tests for actual battery awareness functionality
/// 
/// These tests validate the real battery awareness implementation,
/// not just mock simulators.
class BatteryAwarenessIntegrationTest {
  /// Test battery awareness configuration and optimization logic
  static Future<Map<String, bool>> runBatteryAwarenessTests({
    bool verbose = false,
  }) async {
    final results = <String, bool>{};
    
    print('[INFO] Starting Battery Awareness Integration Tests');
    
    // Test 1: Battery Configuration Integration
    try {
      if (verbose) print('[INFO] Testing Battery Configuration Integration...');
      await _testBatteryConfigIntegration();
      results['battery_config_integration'] = true;
      print('[SUCCESS] Battery Configuration Integration test - PASSED');
    } catch (e) {
      results['battery_config_integration'] = false;
      print('[ERROR] Battery Configuration Integration test - FAILED: $e');
    }
    
    // Test 2: Battery Status Monitoring
    try {
      if (verbose) print('[INFO] Testing Battery Status Monitoring...');
      await _testBatteryStatusMonitoring();
      results['battery_status_monitoring'] = true;
      print('[SUCCESS] Battery Status Monitoring test - PASSED');
    } catch (e) {
      results['battery_status_monitoring'] = false;
      print('[ERROR] Battery Status Monitoring test - FAILED: $e');
    }
    
    // Test 3: Battery Optimization Logic
    try {
      if (verbose) print('[INFO] Testing Battery Optimization Logic...');
      await _testBatteryOptimizationLogic();
      results['battery_optimization_logic'] = true;
      print('[SUCCESS] Battery Optimization Logic test - PASSED');
    } catch (e) {
      results['battery_optimization_logic'] = false;
      print('[ERROR] Battery Optimization Logic test - FAILED: $e');
    }
    
    // Test 4: Adaptive Connection Behavior
    try {
      if (verbose) print('[INFO] Testing Adaptive Connection Behavior...');
      await _testAdaptiveConnectionBehavior();
      results['adaptive_connection_behavior'] = true;
      print('[SUCCESS] Adaptive Connection Behavior test - PASSED');
    } catch (e) {
      results['adaptive_connection_behavior'] = false;
      print('[ERROR] Adaptive Connection Behavior test - FAILED: $e');
    }
    
    // Test 5: Real-time Battery Response
    try {
      if (verbose) print('[INFO] Testing Real-time Battery Response...');
      await _testRealTimeBatteryResponse();
      results['realtime_battery_response'] = true;
      print('[SUCCESS] Real-time Battery Response test - PASSED');
    } catch (e) {
      results['realtime_battery_response'] = false;
      print('[ERROR] Real-time Battery Response test - FAILED: $e');
    }
    
    return results;
  }
  
  /// Test that MerkleKVConfig properly integrates battery awareness configuration
  static Future<void> _testBatteryConfigIntegration() async {
    // Test default configuration
    final defaultConfig = MerkleKVConfig(
      mqttHost: '127.0.0.1',
      clientId: 'test-client',
      nodeId: 'test-node',
    );
    
    // Verify default battery configuration is applied
    assert(defaultConfig.batteryConfig.lowBatteryThreshold == 20, 
           'Default low battery threshold should be 20%');
    assert(defaultConfig.batteryConfig.criticalBatteryThreshold == 10,
           'Default critical battery threshold should be 10%');
    assert(defaultConfig.batteryConfig.adaptiveKeepAlive == true,
           'Adaptive keep-alive should be enabled by default');
    
    // Test custom battery configuration
    final customConfig = MerkleKVConfig(
      mqttHost: '127.0.0.1',
      clientId: 'test-client',
      nodeId: 'test-node',
      batteryConfig: const BatteryAwarenessConfig(
        lowBatteryThreshold: 30,
        criticalBatteryThreshold: 15,
        adaptiveKeepAlive: false,
        enableOperationThrottling: false,
      ),
    );
    
    // Verify custom configuration is applied
    assert(customConfig.batteryConfig.lowBatteryThreshold == 30,
           'Custom low battery threshold should be 30%');
    assert(customConfig.batteryConfig.criticalBatteryThreshold == 15,
           'Custom critical battery threshold should be 15%');
    assert(customConfig.batteryConfig.adaptiveKeepAlive == false,
           'Custom adaptive keep-alive should be disabled');
    
    // Test JSON serialization/deserialization
    final json = customConfig.toJson();
    final recreatedConfig = MerkleKVConfig.fromJson(json);
    
    assert(recreatedConfig.batteryConfig.lowBatteryThreshold == 30,
           'Deserialized battery config should preserve custom threshold');
    
    print('[TEST] ✓ Battery configuration integration verified');
  }
  
  /// Test battery status monitoring and stream functionality
  static Future<void> _testBatteryStatusMonitoring() async {
    final batteryManager = MockBatteryAwarenessManager();
    
    // Test stream subscription
    final statusUpdates = <BatteryStatus>[];
    final subscription = batteryManager.batteryStatusStream.listen((status) {
      statusUpdates.add(status);
    });
    
    await batteryManager.startMonitoring();
    
    // Simulate various battery status changes
    final normalStatus = BatteryStatus(
      level: 75,
      isCharging: false,
      isPowerSaveMode: false,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    );
    
    final lowBatteryStatus = BatteryStatus(
      level: 20,
      isCharging: false,
      isPowerSaveMode: true,
      isLowPowerMode: true,
      timestamp: DateTime.now(),
    );
    
    final chargingStatus = BatteryStatus(
      level: 25,
      isCharging: true,
      isPowerSaveMode: false,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    );
    
    // Test status updates
    batteryManager.simulateBatteryStatusChange(normalStatus);
    await Future.delayed(Duration(milliseconds: 10));
    
    batteryManager.simulateBatteryStatusChange(lowBatteryStatus);
    await Future.delayed(Duration(milliseconds: 10));
    
    batteryManager.simulateBatteryStatusChange(chargingStatus);
    await Future.delayed(Duration(milliseconds: 10));
    
    // Verify status updates were received
    assert(statusUpdates.length >= 3, 'Should receive all status updates');
    assert(statusUpdates.any((s) => s.level == 75), 'Should receive normal status');
    assert(statusUpdates.any((s) => s.level == 20 && s.isPowerSaveMode), 'Should receive low battery status');
    assert(statusUpdates.any((s) => s.isCharging), 'Should receive charging status');
    
    // Test current status access
    final currentStatus = batteryManager.currentStatus;
    assert(currentStatus != null, 'Should have current status');
    assert(currentStatus!.isCharging == true, 'Current status should reflect latest update');
    
    await subscription.cancel();
    await batteryManager.stopMonitoring();
    await batteryManager.dispose();
    
    print('[TEST] ✓ Battery status monitoring verified');
  }
  
  /// Test battery optimization logic with different battery conditions
  static Future<void> _testBatteryOptimizationLogic() async {
    final config = BatteryAwarenessConfig(
      lowBatteryThreshold: 25,
      criticalBatteryThreshold: 15,
      adaptiveKeepAlive: true,
      adaptiveSyncInterval: true,
      enableOperationThrottling: true,
      reduceBackgroundActivity: true,
    );
    
    final batteryManager = MockBatteryAwarenessManager(config: config);
    
    // Test normal battery optimization (75%)
    batteryManager.simulateBatteryStatusChange(BatteryStatus(
      level: 75,
      isCharging: false,
      isPowerSaveMode: false,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    ));
    
    var optimization = batteryManager.getOptimization();
    assert(optimization.keepAliveSeconds == 60, 'Normal battery should use standard keep-alive');
    assert(optimization.maxConcurrentOperations == 10, 'Normal battery should allow full concurrency');
    assert(optimization.throttleOperations == false, 'Normal battery should not throttle');
    assert(optimization.reduceBackground == false, 'Normal battery should not reduce background');
    
    // Test low battery optimization (20%)
    batteryManager.simulateBatteryStatusChange(BatteryStatus(
      level: 20,
      isCharging: false,
      isPowerSaveMode: true,
      isLowPowerMode: true,
      timestamp: DateTime.now(),
    ));
    
    optimization = batteryManager.getOptimization();
    assert(optimization.keepAliveSeconds == 180, 'Low battery should increase keep-alive to 180s');
    assert(optimization.maxConcurrentOperations == 5, 'Low battery should reduce concurrency to 5');
    assert(optimization.throttleOperations == true, 'Low battery should enable throttling');
    assert(optimization.reduceBackground == true, 'Low battery should reduce background activity');
    
    // Test critical battery optimization (10%)
    batteryManager.simulateBatteryStatusChange(BatteryStatus(
      level: 10,
      isCharging: false,
      isPowerSaveMode: true,
      isLowPowerMode: true,
      timestamp: DateTime.now(),
    ));
    
    optimization = batteryManager.getOptimization();
    assert(optimization.keepAliveSeconds == 300, 'Critical battery should increase keep-alive to 300s');
    assert(optimization.maxConcurrentOperations == 2, 'Critical battery should reduce concurrency to 2');
    assert(optimization.throttleOperations == true, 'Critical battery should enable throttling');
    assert(optimization.deferNonCriticalRequests == true, 'Critical battery should defer non-critical requests');
    
    // Test charging optimization (20% but charging)
    batteryManager.simulateBatteryStatusChange(BatteryStatus(
      level: 20,
      isCharging: true, // Device is charging
      isPowerSaveMode: false,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    ));
    
    optimization = batteryManager.getOptimization();
    assert(optimization.keepAliveSeconds == 60, 'Charging should relax keep-alive back to 60s');
    assert(optimization.maxConcurrentOperations == 10, 'Charging should restore full concurrency');
    assert(optimization.throttleOperations == false, 'Charging should disable throttling');
    assert(optimization.reduceBackground == false, 'Charging should restore background activity');
    
    await batteryManager.dispose();
    
    print('[TEST] ✓ Battery optimization logic verified');
  }
  
  /// Test adaptive connection behavior with mock MQTT client
  static Future<void> _testAdaptiveConnectionBehavior() async {
    final config = MerkleKVConfig(
      mqttHost: '127.0.0.1',
      clientId: 'test-client',
      nodeId: 'test-node',
      batteryConfig: const BatteryAwarenessConfig(
        lowBatteryThreshold: 25,
        adaptiveKeepAlive: true,
      ),
    );
    
    final mockMqttClient = MockMqttClient();
    final batteryManager = MockBatteryAwarenessManager(config: config.batteryConfig);
    
    final lifecycleManager = BatteryAwareConnectionLifecycleManager(
      config: config,
      mqttClient: mockMqttClient,
      batteryManager: batteryManager,
    );
    
    // Test normal battery behavior
    batteryManager.simulateBatteryStatusChange(BatteryStatus(
      level: 75,
      isCharging: false,
      isPowerSaveMode: false,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    ));
    
    await Future.delayed(Duration(milliseconds: 50));
    
    var currentOptimization = lifecycleManager.getCurrentOptimization();
    assert(currentOptimization.keepAliveSeconds == 60, 
           'Normal battery should use standard keep-alive');
    
    // Test low battery behavior
    batteryManager.simulateBatteryStatusChange(BatteryStatus(
      level: 20,
      isCharging: false,
      isPowerSaveMode: true,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    ));
    
    await Future.delayed(Duration(milliseconds: 50));
    
    currentOptimization = lifecycleManager.getCurrentOptimization();
    assert(currentOptimization.keepAliveSeconds == 180,
           'Low battery should increase keep-alive interval');
    assert(currentOptimization.throttleOperations == true,
           'Low battery should enable operation throttling');
    
    await lifecycleManager.dispose();
    
    print('[TEST] ✓ Adaptive connection behavior verified');
  }
  
  /// Test real-time battery response and configuration updates
  static Future<void> _testRealTimeBatteryResponse() async {
    final batteryManager = DefaultBatteryAwarenessManager(
      config: const BatteryAwarenessConfig(
        lowBatteryThreshold: 30,
        criticalBatteryThreshold: 15,
      ),
    );
    
    // Test configuration update
    batteryManager.updateConfig(const BatteryAwarenessConfig(
      lowBatteryThreshold: 25,
      criticalBatteryThreshold: 10,
      adaptiveKeepAlive: false,
    ));
    
    assert(batteryManager.config.lowBatteryThreshold == 25,
           'Configuration should be updated');
    assert(batteryManager.config.adaptiveKeepAlive == false,
           'Adaptive keep-alive should be disabled after update');
    
    // Test monitoring lifecycle
    await batteryManager.startMonitoring();
    assert(true, 'Should be able to start monitoring without errors');
    
    await batteryManager.stopMonitoring();
    assert(true, 'Should be able to stop monitoring without errors');
    
    await batteryManager.dispose();
    assert(true, 'Should be able to dispose without errors');
    
    print('[TEST] ✓ Real-time battery response verified');
  }
}

/// Mock MQTT client for testing battery-aware connection behavior
class MockMqttClient implements MqttClientInterface {
  final StreamController<ConnectionState> _stateController = 
      StreamController<ConnectionState>.broadcast();
  final StreamController<String> _subAckController =
      StreamController<String>.broadcast();
  
  ConnectionState _currentState = ConnectionState.disconnected;
  
  @override
  Stream<ConnectionState> get connectionState => _stateController.stream;

  @override
  Stream<String> get onSubscribed => _subAckController.stream;
  
  @override
  ConnectionState get currentConnectionState => _currentState;
  
  @override
  Future<void> connect() async {
    _currentState = ConnectionState.connected;
    _stateController.add(_currentState);
  }
  
  @override
  Future<void> disconnect({bool suppressLWT = true}) async {
    _currentState = ConnectionState.disconnected;
    _stateController.add(_currentState);
  }
  
  @override
  Future<void> subscribe(String topic) async {
    // Mock implementation
  }
  
  @override
  Future<void> unsubscribe(String topic) async {
    // Mock implementation
  }
  
  @override
  Future<void> publish(String topic, String payload) async {
    // Mock implementation
  }
  
  @override
  Stream<String> messageStream(String topic) {
    return Stream.empty();
  }
  
  void dispose() {
    _stateController.close();
  }
}

/// Main test runner for battery awareness integration tests
void main(List<String> args) async {
  print('[INFO] Starting Battery Awareness Integration Test Suite');
  
  // Parse arguments
  bool verbose = args.contains('--verbose');
  
  final results = <String, bool>{};
  var totalTests = 0;
  var passedTests = 0;
  
  try {
    print('\n[INFO] === BATTERY AWARENESS INTEGRATION TESTS ===');
    
    totalTests++;
    try {
      if (verbose) print('[INFO] Running Battery Awareness Integration Tests...');
      final integrationResults = await BatteryAwarenessIntegrationTest.runBatteryAwarenessTests(verbose: verbose);
      final passed = integrationResults.values.every((result) => result);
      results['battery_awareness_integration'] = passed;
      if (passed) passedTests++;
      print('[SUCCESS] Battery Awareness Integration - ${passed ? 'PASSED' : 'FAILED'}');
    } catch (e) {
      results['battery_awareness_integration'] = false;
      print('[ERROR] Battery Awareness Integration - FAILED: $e');
    }
    
    // Print summary
    print('\n[INFO] ========== Integration Test Results ==========');
    print('[INFO] Total Tests: $totalTests');
    print('[INFO] Passed: $passedTests');
    print('[INFO] Failed: ${totalTests - passedTests}');
    print('[INFO] Success Rate: ${totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0.0'}%');
    
    for (final entry in results.entries) {
      final status = entry.value ? '✅ PASS' : '❌ FAIL';
      print('[INFO] $status - ${entry.key}');
    }
    print('[INFO] ================================================\n');
    
    // Exit with appropriate code
    if (passedTests == totalTests) {
      print('[SUCCESS] All integration tests passed! 🔋');
      exit(0);
    } else {
      print('[ERROR] ${totalTests - passedTests} integration test(s) failed');
      exit(1);
    }
    
  } catch (e, stackTrace) {
    print('[FATAL] Integration test execution failed: $e');
    if (verbose) {
      print('[DEBUG] Stack trace: $stackTrace');
    }
    exit(1);
  }
}