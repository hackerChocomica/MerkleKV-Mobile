import 'dart:async';
import 'dart:io';
import '../scenarios/e2e_scenario.dart';

/// Manages test sessions including setup, cleanup, and resource management
class TestSessionManager {
  final Map<String, TestSession> _activeSessions = {};
  Process? _mqttBrokerProcess;
  bool _brokerStarted = false;

  /// Initialize a new test session for the given scenario
  Future<TestSession> initializeSession(E2EScenario scenario) async {
    final sessionId = _generateSessionId();
    final session = TestSession(
      id: sessionId,
      scenario: scenario,
      startTime: DateTime.now(),
    );

    _activeSessions[sessionId] = session;
    
    print('📝 Initialized test session: $sessionId for ${scenario.name}');
    
    return session;
  }

  /// Start MQTT broker if not already running
  Future<void> startMqttBroker() async {
    if (_brokerStarted) {
      print('🔄 MQTT broker already running');
      return;
    }

    print('🚀 Starting MQTT broker...');
    
    try {
      // Check if Docker is available
      final dockerCheck = await Process.run('docker', ['--version']);
      if (dockerCheck.exitCode != 0) {
        throw StateError('Docker is required but not available');
      }

      // Start Mosquitto broker in Docker
      _mqttBrokerProcess = await Process.start(
        'docker',
        [
          'run',
          '--rm',
          '--name', 'e2e-mqtt-broker',
          '-p', '1883:1883',
          '-d',
          'eclipse-mosquitto:1.6'
        ],
      );

      // Wait for broker to start
      await Future.delayed(Duration(seconds: 3));
      
      // Verify broker is accessible
      await _verifyBrokerConnectivity();
      
      _brokerStarted = true;
      print('✅ MQTT broker started successfully');
      
    } catch (error) {
      print('❌ Failed to start MQTT broker: $error');
      rethrow;
    }
  }

  /// Stop MQTT broker
  Future<void> stopMqttBroker() async {
    if (!_brokerStarted) {
      return;
    }

    print('🛑 Stopping MQTT broker...');
    
    try {
      // Stop the Docker container
      final stopResult = await Process.run(
        'docker',
        ['stop', 'e2e-mqtt-broker'],
      );
      
      if (stopResult.exitCode == 0) {
        print('✅ MQTT broker stopped successfully');
      } else {
        print('⚠️ Warning: Failed to stop MQTT broker cleanly');
      }
      
      _mqttBrokerProcess = null;
      _brokerStarted = false;
      
    } catch (error) {
      print('❌ Error stopping MQTT broker: $error');
    }
  }

  /// Verify MQTT broker connectivity
  Future<void> _verifyBrokerConnectivity() async {
    try {
      final socket = await Socket.connect('localhost', 1883, timeout: Duration(seconds: 5));
      await socket.close();
    } catch (error) {
      throw StateError('MQTT broker is not accessible: $error');
    }
  }

  /// Cleanup a test session
  Future<void> cleanupSession(TestSession session) async {
    print('🧹 Cleaning up test session: ${session.id}');
    
    session.endTime = DateTime.now();
    _activeSessions.remove(session.id);
    
    // Additional cleanup per session can be added here
  }

  /// Cleanup all resources
  Future<void> cleanup() async {
    print('🧹 Cleaning up TestSessionManager...');
    
    // Cleanup all active sessions
    for (final session in _activeSessions.values) {
      await cleanupSession(session);
    }
    
    // Stop MQTT broker
    await stopMqttBroker();
  }

  /// Generate unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'session_${timestamp}_$random';
  }

  /// Get active sessions count
  int get activeSessionsCount => _activeSessions.length;

  /// Check if MQTT broker is running
  bool get isMqttBrokerRunning => _brokerStarted;
}

/// Represents a test session
class TestSession {
  final String id;
  final E2EScenario scenario;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, dynamic> metadata = {};

  TestSession({
    required this.id,
    required this.scenario,
    required this.startTime,
  });

  /// Get session duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Add metadata to session
  void addMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  /// Get metadata from session
  T? getMetadata<T>(String key) {
    return metadata[key] as T?;
  }
}