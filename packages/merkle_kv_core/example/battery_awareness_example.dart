import 'dart:async';

import 'package:merkle_kv_core/merkle_kv_core.dart';

/// Example of battery-aware MerkleKV Mobile usage.
/// 
/// This example demonstrates how to use battery awareness features
/// to optimize MQTT connection behavior and operations based on device
/// battery status and power saving modes.
Future<void> main() async {
  print('=== Battery-Aware MerkleKV Mobile Example ===\n');

  // Create configuration with battery awareness settings
  final config = MerkleKVConfig(
    mqttHost: '127.0.0.1',
    clientId: 'battery-demo-client',
    nodeId: 'battery-demo-node',
    batteryConfig: const BatteryAwarenessConfig(
      lowBatteryThreshold: 25,        // Trigger optimizations at 25%
      criticalBatteryThreshold: 15,   // Aggressive optimizations at 15%
      adaptiveKeepAlive: true,         // Adjust MQTT keep-alive based on battery
      adaptiveSyncInterval: true,      // Adjust sync frequency based on battery
      enableOperationThrottling: true, // Limit concurrent operations when low battery
      reduceBackgroundActivity: true,  // Reduce background activity during power saving
    ),
  );

  print('Configuration with battery awareness:');
  print('- Low battery threshold: ${config.batteryConfig.lowBatteryThreshold}%');
  print('- Critical battery threshold: ${config.batteryConfig.criticalBatteryThreshold}%');
  print('- Adaptive keep-alive: ${config.batteryConfig.adaptiveKeepAlive}');
  print('- Operation throttling: ${config.batteryConfig.enableOperationThrottling}\n');

  // Create battery awareness manager
  final batteryManager = MockBatteryAwarenessManager();
  
  // Simulate normal battery status (75% charged, not in power save mode)
  print('=== Simulating Normal Battery Status (75%) ===');
  batteryManager.simulateBatteryStatusChange(BatteryStatus(
    level: 75,
    isCharging: false,
    isPowerSaveMode: false,
    isLowPowerMode: false,
    timestamp: DateTime.now(),
  ));
  
  var optimization = batteryManager.getOptimization();
  print('Battery optimization for 75% battery:');
  print('- Keep-alive interval: ${optimization.keepAliveSeconds}s');
  print('- Sync interval: ${optimization.syncIntervalSeconds}s');
  print('- Max concurrent operations: ${optimization.maxConcurrentOperations}');
  print('- Throttle operations: ${optimization.throttleOperations}');
  print('- Reduce background: ${optimization.reduceBackground}\n');

  // Simulate low battery status (20%)
  print('=== Simulating Low Battery Status (20%) ===');
  batteryManager.simulateBatteryStatusChange(BatteryStatus(
    level: 20,
    isCharging: false,
    isPowerSaveMode: true,
    isLowPowerMode: true,
    timestamp: DateTime.now(),
  ));
  
  optimization = batteryManager.getOptimization();
  print('Battery optimization for 20% battery (power save mode):');
  print('- Keep-alive interval: ${optimization.keepAliveSeconds}s (increased to save battery)');
  print('- Sync interval: ${optimization.syncIntervalSeconds}s (increased to save battery)');
  print('- Max concurrent operations: ${optimization.maxConcurrentOperations} (reduced)');
  print('- Throttle operations: ${optimization.throttleOperations}');
  print('- Reduce background: ${optimization.reduceBackground}\n');

  // Simulate critical battery status (10%)
  print('=== Simulating Critical Battery Status (10%) ===');
  batteryManager.simulateBatteryStatusChange(BatteryStatus(
    level: 10,
    isCharging: false,
    isPowerSaveMode: true,
    isLowPowerMode: true,
    timestamp: DateTime.now(),
  ));
  
  optimization = batteryManager.getOptimization();
  print('Battery optimization for 10% battery (critical):');
  print('- Keep-alive interval: ${optimization.keepAliveSeconds}s (very long to conserve battery)');
  print('- Sync interval: ${optimization.syncIntervalSeconds}s (very long to conserve battery)');
  print('- Max concurrent operations: ${optimization.maxConcurrentOperations} (heavily reduced)');
  print('- Throttle operations: ${optimization.throttleOperations}');
  print('- Reduce background: ${optimization.reduceBackground}');
  print('- Defer non-critical requests: ${optimization.deferNonCriticalRequests}\n');

  // Simulate charging at low battery (20% but charging)
  print('=== Simulating Low Battery but Charging (20% + charging) ===');
  batteryManager.simulateBatteryStatusChange(BatteryStatus(
    level: 20,
    isCharging: true,  // Device is charging
    isPowerSaveMode: false,
    isLowPowerMode: false,
    timestamp: DateTime.now(),
  ));
  
  optimization = batteryManager.getOptimization();
  print('Battery optimization for 20% battery but charging:');
  print('- Keep-alive interval: ${optimization.keepAliveSeconds}s (relaxed because charging)');
  print('- Sync interval: ${optimization.syncIntervalSeconds}s (relaxed because charging)');
  print('- Max concurrent operations: ${optimization.maxConcurrentOperations} (normal)');
  print('- Throttle operations: ${optimization.throttleOperations}');
  print('- Reduce background: ${optimization.reduceBackground}\n');

  // Demonstrate battery status monitoring
  print('=== Battery Status Stream Monitoring ===');
  final subscription = batteryManager.batteryStatusStream.listen((status) {
    print('Battery status changed: ${status.level}% '
          '(charging: ${status.isCharging}, power save: ${status.isPowerSaveMode})');
  });

  // Simulate a few battery status changes
  await Future.delayed(const Duration(milliseconds: 100));
  batteryManager.simulateBatteryStatusChange(BatteryStatus(
    level: 50,
    isCharging: false,
    isPowerSaveMode: false,
    isLowPowerMode: false,
    timestamp: DateTime.now(),
  ));

  await Future.delayed(const Duration(milliseconds: 100));
  batteryManager.simulateBatteryStatusChange(BatteryStatus(
    level: 25,
    isCharging: false,
    isPowerSaveMode: true,
    isLowPowerMode: false,
    timestamp: DateTime.now(),
  ));

  await Future.delayed(const Duration(milliseconds: 100));
  
  // Clean up
  await subscription.cancel();
  await batteryManager.dispose();
  
  print('\n=== Battery Awareness Example Complete ===');
  print('The battery awareness system adapts MQTT and sync behavior automatically');
  print('based on device battery level, charging status, and power save modes.');
}