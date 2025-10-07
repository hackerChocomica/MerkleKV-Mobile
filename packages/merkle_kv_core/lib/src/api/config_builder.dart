import 'dart:io';

import '../config/merkle_kv_config.dart';
import '../config/invalid_config_exception.dart';
import '../config/mqtt_security_config.dart';
import '../config/resource_limits.dart';
import '../utils/battery_awareness.dart';

/// Builder class for creating MerkleKVConfig instances with a fluent API.
///
/// Provides an easy-to-use builder pattern for constructing configuration
/// with validation and sensible defaults. Supports method chaining for
/// a clean, readable configuration setup.
///
/// Example usage:
/// ```dart
/// final config = MerkleKVConfig.builder()
///   .host('mqtt.example.com')
///   .clientId('mobile-device-1')
///   .nodeId('device-uuid-123')
///   .enableTls()
///   .credentials('username', 'password')
///   .enablePersistence('/path/to/storage')
///   .build();
/// ```
class MerkleKVConfigBuilder {
  String? _mqttHost;
  int? _mqttPort;
  String? _username;
  String? _password;
  bool _mqttUseTls = false;
  String? _clientId;
  String? _nodeId;
  String _topicPrefix = '';
  int _keepAliveSeconds = 60;
  int _sessionExpirySeconds = 86400;
  int _connectionTimeoutSeconds = 20;
  int _skewMaxFutureMs = 300000;
  int _tombstoneRetentionHours = 24;
  bool _persistenceEnabled = false;
  String? _storagePath;
  BatteryAwarenessConfig? _batteryConfig;
  ResourceLimits? _resourceLimits;
  MqttSecurityConfig? _mqttSecurity;

  /// Sets the MQTT broker hostname or IP address.
  MerkleKVConfigBuilder host(String host) {
    _mqttHost = host;
    return this;
  }

  /// Sets the MQTT broker port.
  /// 
  /// If not specified, defaults to 8883 for TLS connections or 1883 for non-TLS.
  MerkleKVConfigBuilder port(int port) {
    _mqttPort = port;
    return this;
  }

  /// Sets MQTT authentication credentials.
  MerkleKVConfigBuilder credentials(String username, String password) {
    _username = username;
    _password = password;
    return this;
  }

  /// Sets only the MQTT username (for username-only authentication).
  MerkleKVConfigBuilder username(String username) {
    _username = username;
    return this;
  }

  /// Sets only the MQTT password.
  MerkleKVConfigBuilder password(String password) {
    _password = password;
    return this;
  }

  /// Enables TLS encryption for MQTT connection.
  /// 
  /// Automatically sets port to 8883 if not explicitly specified.
  MerkleKVConfigBuilder enableTls() {
    _mqttUseTls = true;
    _mqttPort ??= 8883; // Default TLS port
    return this;
  }

  /// Disables TLS encryption for MQTT connection.
  /// 
  /// Automatically sets port to 1883 if not explicitly specified.
  MerkleKVConfigBuilder disableTls() {
    _mqttUseTls = false;
    _mqttPort ??= 1883; // Default non-TLS port
    return this;
  }

  /// Sets the unique client identifier for MQTT connection.
  /// 
  /// Must be between 1 and 128 characters long.
  MerkleKVConfigBuilder clientId(String clientId) {
    _clientId = clientId;
    return this;
  }

  /// Sets the unique node identifier for replication.
  /// 
  /// Must be between 1 and 128 characters long.
  MerkleKVConfigBuilder nodeId(String nodeId) {
    _nodeId = nodeId;
    return this;
  }

  /// Sets the topic prefix for all MQTT topics.
  /// 
  /// Will be automatically normalized (no leading/trailing slashes, no spaces).
  MerkleKVConfigBuilder topicPrefix(String prefix) {
    _topicPrefix = prefix;
    return this;
  }

  /// Sets the MQTT keep-alive interval in seconds.
  /// 
  /// Default: 60 seconds per Locked Spec §11.
  MerkleKVConfigBuilder keepAlive(int seconds) {
    _keepAliveSeconds = seconds;
    return this;
  }

  /// Sets the session expiry interval in seconds.
  /// 
  /// Default: 86400 seconds (24 hours) per Locked Spec §11.
  MerkleKVConfigBuilder sessionExpiry(int seconds) {
    _sessionExpirySeconds = seconds;
    return this;
  }

  /// Sets the MQTT connection timeout in seconds.
  /// 
  /// Default: 20 seconds.
  MerkleKVConfigBuilder connectionTimeout(int seconds) {
    _connectionTimeoutSeconds = seconds;
    return this;
  }

  /// Sets the maximum allowed future timestamp skew in milliseconds.
  /// 
  /// Default: 300000 milliseconds (5 minutes) per Locked Spec §11.
  MerkleKVConfigBuilder timestampSkew(int milliseconds) {
    _skewMaxFutureMs = milliseconds;
    return this;
  }

  /// Sets the tombstone retention period in hours.
  /// 
  /// Default: 24 hours per Locked Spec §11.
  MerkleKVConfigBuilder tombstoneRetention(int hours) {
    _tombstoneRetentionHours = hours;
    return this;
  }

  /// Enables persistence to disk with the specified storage path.
  /// 
  /// If path is null, a temporary directory will be created automatically.
  MerkleKVConfigBuilder enablePersistence([String? storagePath]) {
    _persistenceEnabled = true;
    _storagePath = storagePath;
    return this;
  }

  /// Disables persistence (in-memory storage only).
  MerkleKVConfigBuilder disablePersistence() {
    _persistenceEnabled = false;
    _storagePath = null;
    return this;
  }

  /// Sets a custom storage path for persistence.
  /// 
  /// Automatically enables persistence if not already enabled.
  MerkleKVConfigBuilder storagePath(String path) {
    _storagePath = path;
    _persistenceEnabled = true;
    return this;
  }

  /// Configures battery-aware behaviors (mobile optimization knobs).
  MerkleKVConfigBuilder battery(BatteryAwarenessConfig config) {
    _batteryConfig = config;
    return this;
  }

  /// Applies resource advisories (non-fatal soft limits).
  MerkleKVConfigBuilder resourceLimits(ResourceLimits limits) {
    _resourceLimits = limits;
    return this;
  }

  /// Configures MQTT transport security (TLS, hostname validation, auth).
  MerkleKVConfigBuilder security(MqttSecurityConfig security) {
    _mqttSecurity = security;
    // Keep legacy flags in sync when possible
    _mqttUseTls = security.enableTLS;
    _mqttPort ??= _mqttUseTls ? 8883 : 1883;
    return this;
  }

  /// Applies mobile-optimized defaults.
  /// 
  /// Sets appropriate timeouts and enables persistence for mobile usage.
  MerkleKVConfigBuilder mobileDefaults() {
    _keepAliveSeconds = 120; // 2 minutes for mobile
    _sessionExpirySeconds = 3600; // 1 hour for mobile
    _persistenceEnabled = true;
    _topicPrefix = 'merkle_kv_mobile';
    return this;
  }

  /// Applies edge device defaults.
  /// 
  /// Optimizes for minimal resource usage.
  MerkleKVConfigBuilder edgeDefaults() {
    _keepAliveSeconds = 300; // 5 minutes for edge
    _sessionExpirySeconds = 7200; // 2 hours for edge
    _persistenceEnabled = false; // Minimal storage usage
    _topicPrefix = 'merkle_kv_edge';
    _mqttUseTls = false; // Minimal TLS overhead
    return this;
  }

  /// Applies testing defaults.
  /// 
  /// Sets up configuration suitable for testing environments.
  MerkleKVConfigBuilder testingDefaults() {
    _mqttUseTls = false;
    _topicPrefix = 'merkle_kv_mobile_test';
    _persistenceEnabled = false;
    return this;
  }

  /// Validates the current builder state and returns any validation errors.
  /// 
  /// Returns an empty list if configuration is valid.
  List<String> validate() {
    final errors = <String>[];

    if (_mqttHost == null || _mqttHost!.trim().isEmpty) {
      errors.add('MQTT host is required');
    }

    if (_clientId == null || _clientId!.trim().isEmpty) {
      errors.add('Client ID is required');
    }

    if (_nodeId == null || _nodeId!.trim().isEmpty) {
      errors.add('Node ID is required');
    }

    if (_persistenceEnabled && (_storagePath == null || _storagePath!.trim().isEmpty)) {
      // This is actually OK - we'll auto-generate a temp path
    }

    if (_keepAliveSeconds <= 0) {
      errors.add('Keep alive seconds must be positive');
    }

    if (_sessionExpirySeconds <= 0) {
      errors.add('Session expiry seconds must be positive');
    }

    if (_connectionTimeoutSeconds <= 0) {
      errors.add('Connection timeout seconds must be positive');
    }

    return errors;
  }

  /// Builds and returns a validated MerkleKVConfig instance.
  /// 
  /// Throws [InvalidConfigException] if any required fields are missing
  /// or if validation fails.
  MerkleKVConfig build() {
    // Validate required fields
    final errors = validate();
    if (errors.isNotEmpty) {
      throw InvalidConfigException(
        'Configuration validation failed: ${errors.join(', ')}',
        'configuration',
      );
    }

    // Auto-infer port if not set
    _mqttPort ??= _mqttUseTls ? 8883 : 1883;

    // Auto-generate storage path if persistence enabled but path not set
    String? resolvedStoragePath = _storagePath;
    if (_persistenceEnabled && (_storagePath == null || _storagePath!.isEmpty)) {
      final dir = Directory.systemTemp.createTempSync('merkle_kv_');
      resolvedStoragePath = '${dir.path}${Platform.pathSeparator}merkle_kv_storage.jsonl';
    }

    return MerkleKVConfig(
      mqttHost: _mqttHost!,
      mqttPort: _mqttPort!,
      username: _username,
      password: _password,
      mqttUseTls: _mqttUseTls,
      clientId: _clientId!,
      nodeId: _nodeId!,
      topicPrefix: _topicPrefix,
      keepAliveSeconds: _keepAliveSeconds,
      sessionExpirySeconds: _sessionExpirySeconds,
      connectionTimeoutSeconds: _connectionTimeoutSeconds,
      skewMaxFutureMs: _skewMaxFutureMs,
      tombstoneRetentionHours: _tombstoneRetentionHours,
      persistenceEnabled: _persistenceEnabled,
      storagePath: resolvedStoragePath,
      batteryConfig: _batteryConfig,
      resourceLimits: _resourceLimits,
      mqttSecurity: _mqttSecurity,
    );
  }

  /// Resets the builder to default values.
  MerkleKVConfigBuilder reset() {
    _mqttHost = null;
    _mqttPort = null;
    _username = null;
    _password = null;
    _mqttUseTls = false;
    _clientId = null;
    _nodeId = null;
    _topicPrefix = '';
    _keepAliveSeconds = 60;
    _sessionExpirySeconds = 86400;
    _connectionTimeoutSeconds = 20;
    _skewMaxFutureMs = 300000;
    _tombstoneRetentionHours = 24;
    _persistenceEnabled = false;
    _storagePath = null;
    return this;
  }
}

/// Extension on MerkleKVConfig to add builder pattern support.
extension MerkleKVConfigBuilderExtension on MerkleKVConfig {
  /// Creates a new builder instance for constructing MerkleKVConfig.
  /// 
  /// Returns a fresh builder with default values.
  static MerkleKVConfigBuilder builder() {
    return MerkleKVConfigBuilder();
  }

  /// Creates a builder instance pre-populated with values from this config.
  /// 
  /// Useful for creating modified copies of existing configurations.
  MerkleKVConfigBuilder toBuilder() {
    final builder = MerkleKVConfigBuilder()
      ..host(mqttHost)
      ..port(mqttPort);
    
    if (username != null) builder.username(username!);
    if (password != null) builder.password(password!);
    
    builder
      .._mqttUseTls = mqttUseTls
      ..clientId(clientId)
      ..nodeId(nodeId)
      ..topicPrefix(topicPrefix)
      ..keepAlive(keepAliveSeconds)
      ..sessionExpiry(sessionExpirySeconds)
      ..connectionTimeout(connectionTimeoutSeconds)
      ..timestampSkew(skewMaxFutureMs)
      ..tombstoneRetention(tombstoneRetentionHours)
      .._persistenceEnabled = persistenceEnabled
      .._storagePath = storagePath;
      
    return builder;
  }
}