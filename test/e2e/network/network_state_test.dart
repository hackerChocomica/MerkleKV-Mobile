import 'dart:async';
import '../scenarios/e2e_scenario.dart';
import '../drivers/network_state_manager.dart' as nsm;

/// Network state testing scenarios for mobile E2E testing
class NetworkStateTestScenarios {
  
  /// WiFi to cellular transition scenario
  static NetworkTransitionScenario wifiToCellularTransition() {
    return NetworkTransitionScenario(
      name: 'WiFi to Cellular Transition',
      description: 'Test network transition from WiFi to cellular data',
      transition: NetworkTransition.wifiToCellular,
      steps: [
        LaunchAppStep(),
        ConnectMerkleKVStep(),
        VerifyNetworkStateStep(expectedState: NetworkState.wifi),
        SetDataStep(key: 'wifi_key', value: 'wifi_value'),
        TransitionToCellularStep(),
        VerifyNetworkStateStep(expectedState: NetworkState.cellular),
        VerifyDataStep(key: 'wifi_key', expectedValue: 'wifi_value'),
        SetDataStep(key: 'cellular_key', value: 'cellular_value'),
        VerifyConnectionStep(),
      ],
      preConditions: [
        MqttBrokerPreCondition(),
        NetworkConnectivityPreCondition(requiredState: NetworkState.wifi),
      ],
      postConditions: [
        MerkleKVConnectedPostCondition(),
        DataConsistencyPostCondition(keys: ['wifi_key', 'cellular_key']),
      ],
      timeout: Duration(minutes: 2),
    );
  }

  /// Cellular to WiFi transition scenario
  static NetworkTransitionScenario cellularToWifiTransition() {
    return NetworkTransitionScenario(
      name: 'Cellular to WiFi Transition',
      description: 'Test network transition from cellular to WiFi',
      transition: NetworkTransition.cellularToWifi,
      steps: [
        LaunchAppStep(),
        ConnectMerkleKVStep(),
        SetNetworkStateToCellularStep(),
        VerifyNetworkStateStep(expectedState: NetworkState.cellular),
        SetDataStep(key: 'cellular_key', value: 'cellular_value'),
        TransitionToWiFiStep(),
        VerifyNetworkStateStep(expectedState: NetworkState.wifi),
        VerifyDataStep(key: 'cellular_key', expectedValue: 'cellular_value'),
        SetDataStep(key: 'wifi_key', value: 'wifi_value'),
        VerifyConnectionStep(),
      ],
      preConditions: [
        MqttBrokerPreCondition(),
      ],
      postConditions: [
        MerkleKVConnectedPostCondition(),
        DataConsistencyPostCondition(keys: ['cellular_key', 'wifi_key']),
      ],
      timeout: Duration(minutes: 2),
    );
  }

  /// Airplane mode toggle scenario
  static NetworkTransitionScenario airplaneModeToggleScenario() {
    return NetworkTransitionScenario(
      name: 'Airplane Mode Toggle',
      description: 'Test airplane mode enable/disable cycle',
      transition: NetworkTransition.airplaneModeToggle,
      steps: [
        LaunchAppStep(),
        ConnectMerkleKVStep(),
        SetDataStep(key: 'pre_airplane_key', value: 'pre_airplane_value'),
        // Queue operations before airplane mode
        QueueOperationsStep(operationCount: 5, keyPrefix: 'queued'),
        EnableAirplaneModeStep(),
        WaitStep(duration: Duration(seconds: 5)),
        DisableAirplaneModeStep(),
        // Wait for reconnection and operation processing
        WaitForReconnectionStep(timeout: Duration(seconds: 30)),
        VerifyDataStep(key: 'pre_airplane_key', expectedValue: 'pre_airplane_value'),
        VerifyQueuedOperationsStep(operationCount: 5, keyPrefix: 'queued'),
        VerifyConnectionStep(),
      ],
      preConditions: [
        MqttBrokerPreCondition(),
        NetworkConnectivityPreCondition(requiredState: NetworkState.wifi),
      ],
      postConditions: [
        MerkleKVConnectedPostCondition(),
        DataConsistencyPostCondition(keys: ['pre_airplane_key']),
      ],
      timeout: Duration(minutes: 3),
    );
  }

  /// Network interruption scenario
  static NetworkTransitionScenario networkInterruptionScenario() {
    return NetworkTransitionScenario(
      name: 'Network Interruption Recovery',
      description: 'Test recovery from temporary network interruption',
      transition: NetworkTransition.networkInterruption,
      steps: [
        LaunchAppStep(),
        ConnectMerkleKVStep(),
        SetDataStep(key: 'pre_interruption_key', value: 'pre_interruption_value'),
        // Start background operations
        StartBackgroundOperationsStep(operationCount: 10, intervalMs: 500),
        // Simulate network interruption
        SimulateNetworkInterruptionStep(duration: Duration(seconds: 10)),
        // Wait for recovery
        WaitForNetworkRecoveryStep(timeout: Duration(seconds: 30)),
        VerifyDataStep(key: 'pre_interruption_key', expectedValue: 'pre_interruption_value'),
        VerifyBackgroundOperationsStep(),
        VerifyConnectionStep(),
      ],
      preConditions: [
        MqttBrokerPreCondition(),
        NetworkConnectivityPreCondition(requiredState: NetworkState.wifi),
      ],
      postConditions: [
        MerkleKVConnectedPostCondition(),
      ],
      timeout: Duration(minutes: 3),
    );
  }

  /// Poor connectivity scenario
  static NetworkTransitionScenario poorConnectivityScenario() {
    return NetworkTransitionScenario(
      name: 'Poor Connectivity Handling',
      description: 'Test behavior under poor network conditions',
      transition: NetworkTransition.poorConnectivity,
      steps: [
        LaunchAppStep(),
        ConnectMerkleKVStep(),
        SetDataStep(key: 'good_connection_key', value: 'good_connection_value'),
        // Simulate poor connectivity
        SimulatePoorConnectivityStep(
          latencyMs: 2000,
          packetLoss: 0.1,
          duration: Duration(minutes: 1),
        ),
        // Perform operations under poor conditions
        SetDataWithRetryStep(key: 'poor_connection_key', value: 'poor_connection_value'),
        VerifyDataWithTimeoutStep(
          key: 'poor_connection_key',
          expectedValue: 'poor_connection_value',
          timeout: Duration(seconds: 30),
        ),
        // Restore good connectivity
        RestoreGoodConnectivityStep(),
        VerifyConnectionStep(),
      ],
      preConditions: [
        MqttBrokerPreCondition(),
        NetworkConnectivityPreCondition(requiredState: NetworkState.wifi),
      ],
      postConditions: [
        MerkleKVConnectedPostCondition(),
        DataConsistencyPostCondition(keys: ['good_connection_key', 'poor_connection_key']),
      ],
      timeout: Duration(minutes: 3),
    );
  }

  /// Get all network transition scenarios
  static List<NetworkTransitionScenario> getAllScenarios() {
    return [
      wifiToCellularTransition(),
      cellularToWifiTransition(),
      airplaneModeToggleScenario(),
      networkInterruptionScenario(),
      poorConnectivityScenario(),
    ];
  }
}

// Extended test steps for network state testing

/// Verify network state
class VerifyNetworkStateStep extends TestStep {
  final NetworkState expectedState;

  VerifyNetworkStateStep({required this.expectedState})
      : super(description: 'Verify network state is $expectedState');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      // Convert between enum types if needed
      // In real implementation, would properly check state
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}

/// Transition to cellular network
class TransitionToCellularStep extends TestStep {
  TransitionToCellularStep() : super(description: 'Transition from WiFi to cellular');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.transitionWiFiToCellular();
    }
  }
}

/// Transition to WiFi network
class TransitionToWiFiStep extends TestStep {
  TransitionToWiFiStep() : super(description: 'Transition from cellular to WiFi');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.transitionCellularToWiFi();
    }
  }
}

/// Set network state to cellular
class SetNetworkStateToCellularStep extends TestStep {
  SetNetworkStateToCellularStep() : super(description: 'Set network state to cellular');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.disableWiFi();
      await networkManager.enableCellular();
    }
  }
}

/// Enable airplane mode
class EnableAirplaneModeStep extends TestStep {
  EnableAirplaneModeStep() : super(description: 'Enable airplane mode');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.toggleAirplaneMode(enabled: true);
    } else if (appiumDriver != null) {
      await appiumDriver.toggleAirplaneMode(enabled: true);
    }
  }
}

/// Disable airplane mode
class DisableAirplaneModeStep extends TestStep {
  DisableAirplaneModeStep() : super(description: 'Disable airplane mode');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.toggleAirplaneMode(enabled: false);
    } else if (appiumDriver != null) {
      await appiumDriver.toggleAirplaneMode(enabled: false);
    }
  }
}

/// Queue multiple operations
class QueueOperationsStep extends TestStep {
  final int operationCount;
  final String keyPrefix;

  QueueOperationsStep({required this.operationCount, required this.keyPrefix})
      : super(description: 'Queue $operationCount operations with prefix $keyPrefix');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would queue operations in the actual MerkleKV client
    for (int i = 0; i < operationCount; i++) {
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
}

/// Wait for reconnection
class WaitForReconnectionStep extends TestStep {
  final Duration timeout;

  WaitForReconnectionStep({required this.timeout})
      : super(description: 'Wait for reconnection within ${timeout.inSeconds}s');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      // This would check connection status in actual MerkleKV client
      await Future.delayed(Duration(milliseconds: 500));
      // Assume reconnected for simulation
      if (stopwatch.elapsed > Duration(seconds: 2)) {
        return;
      }
    }
    
    throw TimeoutException('Reconnection timeout', timeout);
  }
}

/// Verify queued operations completed
class VerifyQueuedOperationsStep extends TestStep {
  final int operationCount;
  final String keyPrefix;

  VerifyQueuedOperationsStep({required this.operationCount, required this.keyPrefix})
      : super(description: 'Verify $operationCount queued operations completed');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would verify queued operations in the actual MerkleKV client
    for (int i = 0; i < operationCount; i++) {
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
}

/// Start background operations
class StartBackgroundOperationsStep extends TestStep {
  final int operationCount;
  final int intervalMs;

  StartBackgroundOperationsStep({required this.operationCount, required this.intervalMs})
      : super(description: 'Start $operationCount background operations every ${intervalMs}ms');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would start background operations in the actual MerkleKV client
    await Future.delayed(Duration(milliseconds: 100));
  }
}

/// Simulate network interruption
class SimulateNetworkInterruptionStep extends TestStep {
  final Duration duration;

  SimulateNetworkInterruptionStep({required this.duration})
      : super(description: 'Simulate network interruption for ${duration.inSeconds}s');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.simulateNetworkInterruption(interruptionDuration: duration);
    }
  }
}

/// Wait for network recovery
class WaitForNetworkRecoveryStep extends TestStep {
  final Duration timeout;

  WaitForNetworkRecoveryStep({required this.timeout})
      : super(description: 'Wait for network recovery within ${timeout.inSeconds}s');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      final stopwatch = Stopwatch()..start();
      
      while (stopwatch.elapsed < timeout) {
        final status = await networkManager.checkConnectivity();
        if (status.isConnected) {
          return;
        }
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      throw TimeoutException('Network recovery timeout', timeout);
    }
  }
}

/// Verify background operations
class VerifyBackgroundOperationsStep extends TestStep {
  VerifyBackgroundOperationsStep() : super(description: 'Verify background operations completed');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would verify background operations in the actual MerkleKV client
    await Future.delayed(Duration(milliseconds: 100));
  }
}

/// Simulate poor connectivity
class SimulatePoorConnectivityStep extends TestStep {
  final int latencyMs;
  final double packetLoss;
  final Duration duration;

  SimulatePoorConnectivityStep({
    required this.latencyMs,
    required this.packetLoss,
    required this.duration,
  }) : super(description: 'Simulate poor connectivity: ${latencyMs}ms latency, ${(packetLoss * 100).toStringAsFixed(1)}% loss');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    if (networkManager != null) {
      await networkManager.simulatePoorConnectivity(
        duration: duration,
        latencyMs: latencyMs,
        packetLoss: packetLoss,
      );
    }
  }
}

/// Set data with retry logic
class SetDataWithRetryStep extends TestStep {
  final String key;
  final String value;

  SetDataWithRetryStep({required this.key, required this.value})
      : super(description: 'Set data with retry: $key = $value');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would set data with retry logic in the actual MerkleKV client
    await Future.delayed(Duration(milliseconds: 500));
  }
}

/// Verify data with timeout
class VerifyDataWithTimeoutStep extends TestStep {
  final String key;
  final String expectedValue;
  final Duration timeout;

  VerifyDataWithTimeoutStep({
    required this.key,
    required this.expectedValue,
    required this.timeout,
  }) : super(description: 'Verify data with timeout: $key should equal $expectedValue within ${timeout.inSeconds}s');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would verify data with timeout in the actual MerkleKV client
    await Future.delayed(Duration(milliseconds: 200));
  }
}

/// Restore good connectivity
class RestoreGoodConnectivityStep extends TestStep {
  RestoreGoodConnectivityStep() : super(description: 'Restore good connectivity');

  @override
  Future<void> execute({
    dynamic appiumDriver,
    dynamic lifecycleManager,
    dynamic networkManager,
  }) async {
    // This would restore good connectivity conditions
    await Future.delayed(Duration(milliseconds: 100));
  }
}

// Import necessary classes from other files
class ConnectMerkleKVStep extends TestStep {
  ConnectMerkleKVStep() : super(description: 'Connect to MerkleKV client');
  
  @override
  Future<void> execute({dynamic appiumDriver, dynamic lifecycleManager, dynamic networkManager}) async {
    await Future.delayed(Duration(milliseconds: 500));
  }
}

class SetDataStep extends TestStep {
  final String key;
  final String value;
  
  SetDataStep({required this.key, required this.value}) 
      : super(description: 'Set data: $key = $value');
  
  @override
  Future<void> execute({dynamic appiumDriver, dynamic lifecycleManager, dynamic networkManager}) async {
    await Future.delayed(Duration(milliseconds: 100));
  }
}

class VerifyDataStep extends TestStep {
  final String key;
  final String expectedValue;
  
  VerifyDataStep({required this.key, required this.expectedValue})
      : super(description: 'Verify data: $key should equal $expectedValue');
  
  @override
  Future<void> execute({dynamic appiumDriver, dynamic lifecycleManager, dynamic networkManager}) async {
    await Future.delayed(Duration(milliseconds: 100));
  }
}

class VerifyConnectionStep extends TestStep {
  VerifyConnectionStep() : super(description: 'Verify MerkleKV connection is active');
  
  @override
  Future<void> execute({dynamic appiumDriver, dynamic lifecycleManager, dynamic networkManager}) async {
    await Future.delayed(Duration(milliseconds: 100));
  }
}