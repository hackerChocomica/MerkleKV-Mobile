import 'dart:async';

import '../config/merkle_kv_config.dart';
import '../replication/metrics.dart';
import '../utils/battery_awareness.dart';
import 'connection_lifecycle.dart';
import 'connection_logger.dart';
import 'mqtt_client_interface.dart';

/// Battery-aware connection lifecycle manager.
///
/// Extends the default connection lifecycle manager to adapt MQTT behavior
/// based on device battery status and power saving modes.
class BatteryAwareConnectionLifecycleManager 
    extends DefaultConnectionLifecycleManager {
  final BatteryAwarenessManager _batteryManager;
  BatteryOptimization? _currentOptimization;
  StreamSubscription<BatteryStatus>? _batterySubscription;
  bool _batteryAwareKeepAlive = false;

  /// Creates a battery-aware connection lifecycle manager.
  ///
  /// [config] - MerkleKV configuration with battery awareness settings
  /// [mqttClient] - MQTT client implementation
  /// [batteryManager] - Battery awareness manager
  /// [metrics] - Optional metrics collector
  /// [logger] - Optional logger for connection events
  /// [disconnectionTimeout] - Timeout for disconnection operations
  BatteryAwareConnectionLifecycleManager({
    required MerkleKVConfig config,
    required MqttClientInterface mqttClient,
    required BatteryAwarenessManager batteryManager,
    ReplicationMetrics? metrics,
    bool maintainConnectionInBackground = true,
    ConnectionLogger? logger,
    Duration? disconnectionTimeout,
  })  : _batteryManager = batteryManager,
        super(
          config: config,
          mqttClient: mqttClient,
          metrics: metrics,
          maintainConnectionInBackground: maintainConnectionInBackground,
          logger: logger,
          disconnectionTimeout: disconnectionTimeout,
        ) {
    _initializeBatteryMonitoring();
  }

  /// Initialize battery status monitoring.
  void _initializeBatteryMonitoring() {
    // Subscribe to battery status changes
    _batterySubscription = _batteryManager.batteryStatusStream.listen(
      _handleBatteryStatusChange,
      onError: (error) {
        // Log battery monitoring errors but don't fail
        print('Battery monitoring error: $error');
      },
    );

    // Start battery monitoring
    _batteryManager.startMonitoring().catchError((error) {
      print('Failed to start battery monitoring: $error');
    });
  }

  /// Handle battery status changes and adapt connection behavior.
  void _handleBatteryStatusChange(BatteryStatus status) {
    final optimization = _batteryManager.getOptimization();
    _currentOptimization = optimization;

    // Log battery status change
    print('Battery status changed: $status');
    print('Applied optimization: $optimization');

    // Apply adaptive keep-alive if enabled and connected
    if (isConnected && _shouldUpdateKeepAlive(optimization)) {
      _updateKeepAliveInterval(optimization);
    }

    // Adjust background connection behavior
    _adjustBackgroundBehavior(optimization);
  }

  /// Check if keep-alive interval should be updated.
  bool _shouldUpdateKeepAlive(BatteryOptimization optimization) {
    return config.batteryConfig.adaptiveKeepAlive &&
           optimization.keepAliveSeconds != config.keepAliveSeconds;
  }

  /// Update MQTT keep-alive interval based on battery optimization.
  void _updateKeepAliveInterval(BatteryOptimization optimization) {
    try {
      // Update keep-alive interval through MQTT client if it supports it
      if (mqttClient is AdaptiveMqttClient) {
        final adaptiveClient = mqttClient as AdaptiveMqttClient;
        adaptiveClient.updateKeepAliveInterval(optimization.keepAliveSeconds);
        _batteryAwareKeepAlive = true;
        print('Updated keep-alive interval to ${optimization.keepAliveSeconds}s for battery optimization');
      }
    } catch (e) {
      print('Failed to update keep-alive interval: $e');
    }
  }

  /// Adjust background connection behavior based on battery optimization.
  void _adjustBackgroundBehavior(BatteryOptimization optimization) {
    // If battery optimization recommends reducing background activity,
    // we may want to disconnect more aggressively when backgrounded
    if (optimization.reduceBackground) {
      // This would be handled in handleAppStateChange
    }
  }

  @override
  Future<void> handleAppStateChange(AppLifecycleState state) async {
    final optimization = _currentOptimization ?? _batteryManager.getOptimization();
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await _handleBatteryAwareBackgrounding(optimization);
        break;
      case AppLifecycleState.resumed:
        await _handleBatteryAwareResuming(optimization);
        break;
      case AppLifecycleState.inactive:
        // Handle brief inactive states
        break;
    }
  }

  /// Handle backgrounding with battery awareness.
  Future<void> _handleBatteryAwareBackgrounding(BatteryOptimization optimization) async {
    print('App backgrounding with battery optimization: $optimization');
    
    // If battery optimization suggests reducing background activity and
    // we're not charging, consider disconnecting
    if (optimization.reduceBackground && 
        _batteryManager.currentStatus?.isCharging != true) {
      print('Disconnecting due to battery optimization during backgrounding');
      await disconnect(suppressLWT: true);
    } else {
      // Use standard backgrounding behavior
      await super.handleAppStateChange(AppLifecycleState.paused);
    }
  }

  /// Handle resuming with battery awareness.
  Future<void> _handleBatteryAwareResuming(BatteryOptimization optimization) async {
    print('App resuming with battery optimization: $optimization');
    
    // Use standard resuming behavior, but with battery-aware keep-alive
    await super.handleAppStateChange(AppLifecycleState.resumed);
    
    // Re-apply battery optimizations after resume
    if (isConnected && _shouldUpdateKeepAlive(optimization)) {
      _updateKeepAliveInterval(optimization);
    }
  }

  /// Get current battery optimization recommendations.
  BatteryOptimization getCurrentOptimization() {
    return _currentOptimization ?? _batteryManager.getOptimization();
  }

  /// Get battery awareness manager.
  BatteryAwarenessManager get batteryManager => _batteryManager;

  @override
  Future<void> dispose() async {
    // Cancel battery monitoring subscription
    await _batterySubscription?.cancel();
    
    // Stop battery monitoring
    await _batteryManager.stopMonitoring();
    
    // Dispose battery manager
    await _batteryManager.dispose();
    
    // Call parent dispose
    await super.dispose();
  }
}

/// Interface for MQTT clients that support adaptive behavior.
abstract class AdaptiveMqttClient extends MqttClientInterface {
  /// Update the keep-alive interval dynamically.
  void updateKeepAliveInterval(int seconds);
  
  /// Update connection parameters for power optimization.
  void updateConnectionParameters({
    int? keepAliveSeconds,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
  });
}

/// Factory for creating battery-aware connection lifecycle managers.
class BatteryAwareConnectionFactory {
  /// Create a battery-aware connection lifecycle manager.
  static BatteryAwareConnectionLifecycleManager create({
    required MerkleKVConfig config,
    required MqttClientInterface mqttClient,
    BatteryAwarenessManager? batteryManager,
    ReplicationMetrics? metrics,
    bool maintainConnectionInBackground = true,
    ConnectionLogger? logger,
    Duration? disconnectionTimeout,
  }) {
    final batteryMgr = batteryManager ?? 
        DefaultBatteryAwarenessManager(config: config.batteryConfig);
    
    return BatteryAwareConnectionLifecycleManager(
      config: config,
      mqttClient: mqttClient,
      batteryManager: batteryMgr,
      metrics: metrics,
      maintainConnectionInBackground: maintainConnectionInBackground,
      logger: logger,
      disconnectionTimeout: disconnectionTimeout,
    );
  }
}