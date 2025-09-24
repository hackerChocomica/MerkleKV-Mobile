import 'dart:async';

/// Battery status information for the device.
class BatteryStatus {
  /// Battery level as a percentage (0-100).
  final int level;
  
  /// Whether the device is currently charging.
  final bool isCharging;
  
  /// Whether the device is in power saving mode.
  final bool isPowerSaveMode;
  
  /// Whether the device is in low power mode (iOS specific).
  final bool isLowPowerMode;
  
  /// Timestamp when this status was recorded.
  final DateTime timestamp;

  const BatteryStatus({
    required this.level,
    required this.isCharging,
    required this.isPowerSaveMode,
    required this.isLowPowerMode,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BatteryStatus(level: $level%, charging: $isCharging, '
           'powerSave: $isPowerSaveMode, lowPower: $isLowPowerMode, '
           'timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryStatus &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          isCharging == other.isCharging &&
          isPowerSaveMode == other.isPowerSaveMode &&
          isLowPowerMode == other.isLowPowerMode;

  @override
  int get hashCode =>
      level.hashCode ^
      isCharging.hashCode ^
      isPowerSaveMode.hashCode ^
      isLowPowerMode.hashCode;
}

/// Configuration for battery-aware behavior.
class BatteryAwarenessConfig {
  /// Battery level threshold for enabling power saving (0-100).
  /// Default: 20%
  final int lowBatteryThreshold;
  
  /// Battery level threshold for critical power saving (0-100).
  /// Default: 10%
  final int criticalBatteryThreshold;
  
  /// Whether to enable adaptive MQTT keep-alive intervals based on battery.
  /// Default: true
  final bool adaptiveKeepAlive;
  
  /// Whether to enable adaptive sync intervals based on battery.
  /// Default: true
  final bool adaptiveSyncInterval;
  
  /// Whether to enable operation throttling during low battery.
  /// Default: true
  final bool enableOperationThrottling;
  
  /// Whether to reduce background activity during power saving mode.
  /// Default: true
  final bool reduceBackgroundActivity;

  const BatteryAwarenessConfig({
    this.lowBatteryThreshold = 20,
    this.criticalBatteryThreshold = 10,
    this.adaptiveKeepAlive = true,
    this.adaptiveSyncInterval = true,
    this.enableOperationThrottling = true,
    this.reduceBackgroundActivity = true,
  });

  BatteryAwarenessConfig copyWith({
    int? lowBatteryThreshold,
    int? criticalBatteryThreshold,
    bool? adaptiveKeepAlive,
    bool? adaptiveSyncInterval,
    bool? enableOperationThrottling,
    bool? reduceBackgroundActivity,
  }) {
    return BatteryAwarenessConfig(
      lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
      criticalBatteryThreshold: criticalBatteryThreshold ?? this.criticalBatteryThreshold,
      adaptiveKeepAlive: adaptiveKeepAlive ?? this.adaptiveKeepAlive,
      adaptiveSyncInterval: adaptiveSyncInterval ?? this.adaptiveSyncInterval,
      enableOperationThrottling: enableOperationThrottling ?? this.enableOperationThrottling,
      reduceBackgroundActivity: reduceBackgroundActivity ?? this.reduceBackgroundActivity,
    );
  }
}

/// Battery optimization recommendations based on current status.
class BatteryOptimization {
  /// Recommended MQTT keep-alive interval in seconds.
  final int keepAliveSeconds;
  
  /// Recommended sync interval in seconds.
  final int syncIntervalSeconds;
  
  /// Whether to throttle non-essential operations.
  final bool throttleOperations;
  
  /// Whether to reduce background activity.
  final bool reduceBackground;
  
  /// Maximum number of concurrent operations allowed.
  final int maxConcurrentOperations;
  
  /// Whether to defer non-critical network requests.
  final bool deferNonCriticalRequests;

  const BatteryOptimization({
    required this.keepAliveSeconds,
    required this.syncIntervalSeconds,
    required this.throttleOperations,
    required this.reduceBackground,
    required this.maxConcurrentOperations,
    required this.deferNonCriticalRequests,
  });

  @override
  String toString() {
    return 'BatteryOptimization(keepAlive: ${keepAliveSeconds}s, '
           'syncInterval: ${syncIntervalSeconds}s, throttle: $throttleOperations, '
           'reduceBackground: $reduceBackground, maxConcurrent: $maxConcurrentOperations, '
           'deferNonCritical: $deferNonCriticalRequests)';
  }
}

/// Abstract interface for battery awareness functionality.
abstract class BatteryAwarenessManager {
  /// Stream of battery status updates.
  Stream<BatteryStatus> get batteryStatusStream;
  
  /// Current battery status, null if not available.
  BatteryStatus? get currentStatus;
  
  /// Configuration for battery-aware behavior.
  BatteryAwarenessConfig get config;
  
  /// Get current battery optimization recommendations.
  BatteryOptimization getOptimization();
  
  /// Start monitoring battery status.
  Future<void> startMonitoring();
  
  /// Stop monitoring battery status.
  Future<void> stopMonitoring();
  
  /// Update battery awareness configuration.
  void updateConfig(BatteryAwarenessConfig newConfig);
  
  /// Dispose of resources.
  Future<void> dispose();
}

/// Default implementation of battery awareness for mobile platforms.
class DefaultBatteryAwarenessManager implements BatteryAwarenessManager {
  final StreamController<BatteryStatus> _statusController = 
      StreamController<BatteryStatus>.broadcast();
  
  BatteryAwarenessConfig _config;
  BatteryStatus? _currentStatus;
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// Create a battery awareness manager with configuration.
  DefaultBatteryAwarenessManager({
    BatteryAwarenessConfig? config,
  }) : _config = config ?? const BatteryAwarenessConfig();

  @override
  Stream<BatteryStatus> get batteryStatusStream => _statusController.stream;

  @override
  BatteryStatus? get currentStatus => _currentStatus;

  @override
  BatteryAwarenessConfig get config => _config;

  @override
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;
    
    // Initial battery status check
    await _updateBatteryStatus();
    
    // Start periodic monitoring (every 30 seconds)
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateBatteryStatus(),
    );
  }

  @override
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  @override
  void updateConfig(BatteryAwarenessConfig newConfig) {
    _config = newConfig;
    
    // Trigger optimization recalculation if status is available
    if (_currentStatus != null) {
      _statusController.add(_currentStatus!);
    }
  }

  @override
  BatteryOptimization getOptimization() {
    final status = _currentStatus;
    
    if (status == null) {
      // Default optimization when battery status is unknown
      return const BatteryOptimization(
        keepAliveSeconds: 60,
        syncIntervalSeconds: 30,
        throttleOperations: false,
        reduceBackground: false,
        maxConcurrentOperations: 10,
        deferNonCriticalRequests: false,
      );
    }

    // Determine power conservation level
    final bool isLowBattery = status.level <= _config.lowBatteryThreshold;
    final bool isCriticalBattery = status.level <= _config.criticalBatteryThreshold;
    final bool isPowerSaving = status.isPowerSaveMode || status.isLowPowerMode;
    final bool isCharging = status.isCharging;

    // Calculate optimized values based on battery state
    int keepAliveSeconds = 60;
    int syncIntervalSeconds = 30;
    int maxConcurrentOperations = 10;
    bool throttleOperations = false;
    bool reduceBackground = false;
    bool deferNonCritical = false;

    // Apply power saving optimizations
    if (isPowerSaving || isLowBattery || isCriticalBattery) {
      if (_config.adaptiveKeepAlive) {
        // Increase keep-alive interval to reduce network activity
        keepAliveSeconds = isCriticalBattery ? 300 : (isLowBattery ? 180 : 120);
      }
      
      if (_config.adaptiveSyncInterval) {
        // Increase sync interval to reduce background activity
        syncIntervalSeconds = isCriticalBattery ? 300 : (isLowBattery ? 120 : 60);
      }
      
      if (_config.enableOperationThrottling) {
        // Reduce concurrent operations
        maxConcurrentOperations = isCriticalBattery ? 2 : (isLowBattery ? 5 : 7);
        throttleOperations = true;
      }
      
      if (_config.reduceBackgroundActivity) {
        reduceBackground = true;
        deferNonCritical = true;
      }
    }

    // Relax restrictions if charging
    if (isCharging && !isCriticalBattery) {
      keepAliveSeconds = 60;
      syncIntervalSeconds = 30;
      maxConcurrentOperations = 10;
      throttleOperations = false;
      reduceBackground = false;
      deferNonCritical = false;
    }

    return BatteryOptimization(
      keepAliveSeconds: keepAliveSeconds,
      syncIntervalSeconds: syncIntervalSeconds,
      throttleOperations: throttleOperations,
      reduceBackground: reduceBackground,
      maxConcurrentOperations: maxConcurrentOperations,
      deferNonCriticalRequests: deferNonCritical,
    );
  }

  /// Update battery status by querying platform.
  /// 
  /// In a real implementation, this would use platform channels or 
  /// platform-specific battery APIs. For now, we simulate battery status.
  Future<void> _updateBatteryStatus() async {
    try {
      // Simulate battery status - in real implementation this would
      // use platform channels to get actual battery information
      final status = await _getPlatformBatteryStatus();
      
      // Only emit if status changed significantly
      if (_currentStatus == null || _hasBatteryStatusChanged(_currentStatus!, status)) {
        _currentStatus = status;
        _statusController.add(status);
      }
    } catch (e) {
      // Log error but don't fail - battery monitoring is optional
      // In production, this would use proper logging
      print('Failed to update battery status: $e');
    }
  }

  /// Simulate platform battery status query.
  /// 
  /// In a real implementation, this would use MethodChannel to call
  /// platform-specific battery APIs (Android BatteryManager, iOS UIDevice).
  Future<BatteryStatus> _getPlatformBatteryStatus() async {
    // Simulate battery status for testing
    // In production this would be replaced with actual platform calls
    return BatteryStatus(
      level: 75, // Simulate 75% battery
      isCharging: false,
      isPowerSaveMode: false,
      isLowPowerMode: false,
      timestamp: DateTime.now(),
    );
  }

  /// Check if battery status has changed significantly.
  bool _hasBatteryStatusChanged(BatteryStatus old, BatteryStatus current) {
    // Consider significant changes:
    // - Battery level change of 5% or more
    // - Charging status change
    // - Power save mode change
    return (current.level - old.level).abs() >= 5 ||
           current.isCharging != old.isCharging ||
           current.isPowerSaveMode != old.isPowerSaveMode ||
           current.isLowPowerMode != old.isLowPowerMode;
  }

  @override
  Future<void> dispose() async {
    await stopMonitoring();
    await _statusController.close();
  }
}

/// Mock battery awareness manager for testing.
class MockBatteryAwarenessManager implements BatteryAwarenessManager {
  final StreamController<BatteryStatus> _statusController = 
      StreamController<BatteryStatus>.broadcast();
  
  BatteryAwarenessConfig _config;
  BatteryStatus? _currentStatus;

  MockBatteryAwarenessManager({
    BatteryAwarenessConfig? config,
    BatteryStatus? initialStatus,
  }) : _config = config ?? const BatteryAwarenessConfig(),
       _currentStatus = initialStatus;

  @override
  Stream<BatteryStatus> get batteryStatusStream => _statusController.stream;

  @override
  BatteryStatus? get currentStatus => _currentStatus;

  @override
  BatteryAwarenessConfig get config => _config;

  @override
  Future<void> startMonitoring() async {
    // Mock implementation - no actual monitoring
  }

  @override
  Future<void> stopMonitoring() async {
    // Mock implementation - no actual monitoring
  }

  @override
  void updateConfig(BatteryAwarenessConfig newConfig) {
    _config = newConfig;
  }

  /// Simulate battery status change for testing.
  void simulateBatteryStatusChange(BatteryStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  @override
  BatteryOptimization getOptimization() {
    // Use same logic as default implementation
    final defaultManager = DefaultBatteryAwarenessManager(config: _config);
    defaultManager._currentStatus = _currentStatus;
    return defaultManager.getOptimization();
  }

  @override
  Future<void> dispose() async {
    await _statusController.close();
  }
}