import 'dart:async';
import 'dart:io';

/// Manages network state transitions and connectivity scenarios for mobile E2E testing
/// Provides unified interface for simulating various network conditions
class NetworkStateManager {
  final TargetPlatform platform;
  final String deviceId;
  final Duration defaultTimeout;
  
  NetworkState _currentState = NetworkState.wifi;
  final StreamController<NetworkEvent> _eventController = StreamController.broadcast();
  bool _isMonitoring = false;

  NetworkStateManager({
    required this.platform,
    required this.deviceId,
    this.defaultTimeout = const Duration(seconds: 10),
  });

  /// Stream of network events
  Stream<NetworkEvent> get networkEvents => _eventController.stream;

  /// Current network state
  NetworkState get currentState => _currentState;

  /// Configure initial network state
  Future<void> configureNetworkState(NetworkState state) async {
    print('🌐 Configuring network state: $state');
    
    await _transitionToState(state);
  }

  /// Enable WiFi connectivity
  Future<void> enableWiFi() async {
    print('📶 Enabling WiFi');
    
    if (platform == TargetPlatform.android) {
      await _executeAndroidNetworkCommand('wifi', true);
    } else {
      await _executeiOSNetworkCommand('wifi', true);
    }
    
    await _transitionToState(NetworkState.wifi);
  }

  /// Disable WiFi connectivity
  Future<void> disableWiFi() async {
    print('📶 Disabling WiFi');
    
    if (platform == TargetPlatform.android) {
      await _executeAndroidNetworkCommand('wifi', false);
    } else {
      await _executeiOSNetworkCommand('wifi', false);
    }
    
    if (_currentState == NetworkState.wifi) {
      await _transitionToState(NetworkState.cellular);
    }
  }

  /// Enable cellular connectivity
  Future<void> enableCellular() async {
    print('📱 Enabling cellular');
    
    if (platform == TargetPlatform.android) {
      await _executeAndroidNetworkCommand('data', true);
    } else {
      await _executeiOSNetworkCommand('cellular', true);
    }
    
    if (_currentState == NetworkState.offline) {
      await _transitionToState(NetworkState.cellular);
    }
  }

  /// Disable cellular connectivity
  Future<void> disableCellular() async {
    print('📱 Disabling cellular');
    
    if (platform == TargetPlatform.android) {
      await _executeAndroidNetworkCommand('data', false);
    } else {
      await _executeiOSNetworkCommand('cellular', false);
    }
    
    if (_currentState == NetworkState.cellular) {
      await _transitionToState(NetworkState.offline);
    }
  }

  /// Toggle airplane mode
  Future<void> toggleAirplaneMode({required bool enabled}) async {
    print('✈️ ${enabled ? "Enabling" : "Disabling"} airplane mode');
    
    if (platform == TargetPlatform.android) {
      await _executeAndroidAirplaneMode(enabled);
    } else {
      await _executeiOSAirplaneMode(enabled);
    }
    
    if (enabled) {
      await _transitionToState(NetworkState.airplaneMode);
    } else {
      await _transitionToState(NetworkState.wifi); // Default back to WiFi
    }
  }

  /// Simulate network transition from WiFi to cellular
  Future<void> transitionWiFiToCellular({Duration? transitionDuration}) async {
    print('🔄 Transitioning from WiFi to cellular');
    
    await _transitionToState(NetworkState.wifiToCellular);
    
    if (transitionDuration != null) {
      await Future.delayed(transitionDuration);
    } else {
      await Future.delayed(Duration(seconds: 2)); // Default transition time
    }
    
    await _transitionToState(NetworkState.cellular);
  }

  /// Simulate network transition from cellular to WiFi
  Future<void> transitionCellularToWiFi({Duration? transitionDuration}) async {
    print('🔄 Transitioning from cellular to WiFi');
    
    await _transitionToState(NetworkState.cellularToWifi);
    
    if (transitionDuration != null) {
      await Future.delayed(transitionDuration);
    } else {
      await Future.delayed(Duration(seconds: 2)); // Default transition time
    }
    
    await _transitionToState(NetworkState.wifi);
  }

  /// Simulate network interruption
  Future<void> simulateNetworkInterruption({
    Duration interruptionDuration = const Duration(seconds: 10),
  }) async {
    print('⚠️ Simulating network interruption for ${interruptionDuration.inSeconds}s');
    
    final previousState = _currentState;
    await _transitionToState(NetworkState.offline);
    
    await Future.delayed(interruptionDuration);
    
    await _transitionToState(previousState);
  }

  /// Simulate poor connectivity
  Future<void> simulatePoorConnectivity({
    Duration duration = const Duration(minutes: 1),
    int latencyMs = 2000,
    double packetLoss = 0.1,
  }) async {
    print('📶 Simulating poor connectivity: ${latencyMs}ms latency, ${(packetLoss * 100).toStringAsFixed(1)}% loss');
    
    _emitEvent(NetworkEvent(
      type: NetworkEventType.poorConnectivity,
      state: _currentState,
      timestamp: DateTime.now(),
      metadata: {
        'latencyMs': latencyMs,
        'packetLoss': packetLoss,
        'duration': duration.inMilliseconds,
      },
    ));
    
    await Future.delayed(duration);
    
    _emitEvent(NetworkEvent(
      type: NetworkEventType.connectivityRestored,
      state: _currentState,
      timestamp: DateTime.now(),
    ));
  }

  /// Monitor network connectivity
  Future<List<NetworkEvent>> monitorConnectivity({
    required Duration duration,
    List<NetworkEventType>? eventTypes,
  }) async {
    print('📊 Monitoring network connectivity for ${duration.inSeconds}s');
    
    final events = <NetworkEvent>[];
    late StreamSubscription<NetworkEvent> subscription;
    
    final completer = Completer<List<NetworkEvent>>();
    
    subscription = networkEvents.listen((event) {
      if (eventTypes == null || eventTypes.contains(event.type)) {
        events.add(event);
      }
    });
    
    _isMonitoring = true;
    
    Timer(duration, () {
      _isMonitoring = false;
      subscription.cancel();
      completer.complete(events);
    });
    
    return completer.future;
  }

  /// Check current connectivity status
  Future<ConnectivityStatus> checkConnectivity() async {
    print('🔍 Checking connectivity status');
    
    try {
      // Test connection to known host
      final socket = await Socket.connect('8.8.8.8', 53, timeout: Duration(seconds: 5));
      await socket.close();
      
      return ConnectivityStatus(
        isConnected: true,
        networkType: _currentState,
        timestamp: DateTime.now(),
      );
      
    } catch (error) {
      return ConnectivityStatus(
        isConnected: false,
        networkType: _currentState,
        timestamp: DateTime.now(),
        error: error.toString(),
      );
    }
  }

  /// Execute Android network command
  Future<void> _executeAndroidNetworkCommand(String type, bool enable) async {
    try {
      final command = enable ? 'enable' : 'disable';
      final result = await Process.run(
        'adb',
        ['shell', 'svc', type, command],
      );
      
      if (result.exitCode != 0) {
        throw ProcessException(
          'adb',
          ['shell', 'svc', type, command],
          'Failed to $command $type: ${result.stderr}',
          result.exitCode,
        );
      }
      
    } catch (error) {
      print('❌ Failed to execute Android network command: $error');
      rethrow;
    }
  }

  /// Execute iOS network command
  Future<void> _executeiOSNetworkCommand(String type, bool enable) async {
    // iOS simulator network control is limited
    // This would require more complex setup for real device testing
    print('📱 iOS network command: $type ${enable ? "enable" : "disable"}');
    
    // Simulate command execution
    await Future.delayed(Duration(milliseconds: 500));
  }

  /// Execute Android airplane mode command
  Future<void> _executeAndroidAirplaneMode(bool enable) async {
    try {
      final value = enable ? '1' : '0';
      final result = await Process.run(
        'adb',
        ['shell', 'settings', 'put', 'global', 'airplane_mode_on', value],
      );
      
      if (result.exitCode != 0) {
        throw ProcessException(
          'adb',
          ['shell', 'settings', 'put', 'global', 'airplane_mode_on', value],
          'Failed to set airplane mode: ${result.stderr}',
          result.exitCode,
        );
      }
      
      // Broadcast the change
      await Process.run(
        'adb',
        ['shell', 'am', 'broadcast', '-a', 'android.intent.action.AIRPLANE_MODE'],
      );
      
    } catch (error) {
      print('❌ Failed to execute Android airplane mode command: $error');
      rethrow;
    }
  }

  /// Execute iOS airplane mode command
  Future<void> _executeiOSAirplaneMode(bool enable) async {
    // iOS requires Control Center interaction or physical device controls
    // This is a simulation for testing purposes
    print('📱 iOS airplane mode: ${enable ? "enable" : "disable"}');
    
    // Simulate command execution
    await Future.delayed(Duration(seconds: 1));
  }

  /// Transition to new network state
  Future<void> _transitionToState(NetworkState newState) async {
    if (_currentState == newState) {
      return;
    }
    
    final previousState = _currentState;
    _currentState = newState;
    
    _emitEvent(NetworkEvent(
      type: NetworkEventType.stateTransition,
      state: newState,
      previousState: previousState,
      timestamp: DateTime.now(),
    ));
    
    // Add realistic transition delay
    await Future.delayed(Duration(milliseconds: 300));
  }

  /// Emit network event
  void _emitEvent(NetworkEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Cleanup resources
  Future<void> cleanup() async {
    print('🧹 Cleaning up NetworkStateManager...');
    
    _isMonitoring = false;
    await _eventController.close();
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
}

/// Network states
enum NetworkState {
  wifi,
  cellular,
  offline,
  airplaneMode,
  wifiToCellular,
  cellularToWifi,
}

/// Platform enumeration
enum TargetPlatform {
  android,
  iOS,
}

/// Network event types
enum NetworkEventType {
  stateTransition,
  poorConnectivity,
  connectivityRestored,
  connectionLost,
  connectionEstablished,
}

/// Network event data
class NetworkEvent {
  final NetworkEventType type;
  final NetworkState state;
  final NetworkState? previousState;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  NetworkEvent({
    required this.type,
    required this.state,
    this.previousState,
    required this.timestamp,
    this.metadata = const {},
  });

  @override
  String toString() {
    return 'NetworkEvent(type: $type, state: $state, timestamp: $timestamp)';
  }
}

/// Connectivity status
class ConnectivityStatus {
  final bool isConnected;
  final NetworkState networkType;
  final DateTime timestamp;
  final String? error;

  ConnectivityStatus({
    required this.isConnected,
    required this.networkType,
    required this.timestamp,
    this.error,
  });

  @override
  String toString() {
    return 'ConnectivityStatus(connected: $isConnected, type: $networkType)';
  }
}