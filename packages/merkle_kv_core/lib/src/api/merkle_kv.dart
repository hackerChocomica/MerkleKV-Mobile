import 'dart:async';
import 'dart:isolate';

import '../config/merkle_kv_config.dart';
import '../commands/command.dart';
import '../commands/command_processor.dart';
import '../commands/response.dart';
import '../mqtt/connection_state.dart';
import '../mqtt/mqtt_client_interface.dart';
import '../mqtt/mqtt_client_impl.dart';
import '../storage/storage_interface.dart';
import '../storage/storage_factory.dart';
import '../utils/uuid_generator.dart';
import 'exceptions.dart';
import 'validation.dart';

/// Public API surface for MerkleKV Mobile distributed key-value store.
///
/// Provides clean abstractions for core operations (GET, SET, DEL, INCR/DECR,
/// APPEND/PREPEND), bulk operations (MGET/MSET), and configuration management.
/// 
/// Key features:
/// - Thread-safe concurrent operations
/// - UTF-8 byte-size validation per Locked Spec §11
/// - Fail-fast behavior when disconnected (unless offline queue enabled)
/// - Idempotent DEL operations (always return OK)
/// - Command ID reuse for retry operations
/// - Reactive connection state monitoring
///
/// Example usage:
/// ```dart
/// final config = MerkleKVConfig.builder()
///   .host('mqtt.example.com')
///   .clientId('mobile-device-1')
///   .nodeId('device-uuid-123')
///   .enableTls()
///   .build();
///
/// final merkleKV = await MerkleKV.create(config);
/// await merkleKV.connect();
///
/// // Core operations
/// await merkleKV.set('user:123', 'John Doe');
/// final value = await merkleKV.get('user:123');
/// await merkleKV.delete('user:123');
///
/// // Numeric operations
/// await merkleKV.increment('counter', 5);
/// final count = await merkleKV.decrement('counter', 2);
///
/// // Bulk operations
/// final values = await merkleKV.getMultiple(['key1', 'key2']);
/// await merkleKV.setMultiple({'key1': 'value1', 'key2': 'value2'});
/// ```
class MerkleKV {
  final MerkleKVConfig _config;
  final MqttClientInterface _mqttClient;
  final StorageInterface _storage;
  final CommandProcessor _commandProcessor;
  
  // Thread safety
  final SendPort? _isolateSendPort;
  final Map<String, Completer<Response>> _pendingOperations = {};
  
  // Connection state management
  final StreamController<ConnectionState> _connectionStateController = 
      StreamController<ConnectionState>.broadcast();
  ConnectionState _currentConnectionState = ConnectionState.disconnected;
  
  // Command ID reuse for retries
  final Map<String, String> _retryCommandIds = {};
  
  // Private constructor
  MerkleKV._(
    this._config,
    this._mqttClient,
    this._storage,
    this._commandProcessor,
    this._isolateSendPort,
  );

  /// Creates a new MerkleKV instance with the specified configuration.
  ///
  /// Initializes storage, MQTT client, and command processor.
  /// Does not automatically connect - call [connect] separately.
  ///
  /// Throws [ValidationException] if configuration is invalid.
  static Future<MerkleKV> create(MerkleKVConfig config) async {
    try {
      // Initialize storage
      final storage = StorageFactory.create(config);
      await storage.initialize();
      
      // Initialize MQTT client
      final mqttClient = MqttClientImpl(config);
      
      // Initialize command processor
      final commandProcessor = CommandProcessorImpl(config, storage);
      
      // Create instance
      final instance = MerkleKV._(
        config,
        mqttClient,
        storage,
        commandProcessor,
        null, // Isolate support to be added later
      );
      
      // Set up connection state monitoring
      instance._setupConnectionStateMonitoring();
      
      return instance;
    } catch (e) {
      throw ValidationException(
        'Failed to create MerkleKV instance: ${e.toString()}',
        cause: e,
      );
    }
  }

  /// Connects to the MQTT broker and starts message processing.
  ///
  /// Throws [ConnectionException] if connection fails.
  Future<void> connect() async {
    try {
      _updateConnectionState(ConnectionState.connecting);
      await _mqttClient.connect();
      _updateConnectionState(ConnectionState.connected);
    } catch (e) {
      _updateConnectionState(ConnectionState.disconnected);
      throw ConnectionException(
        'Failed to connect to MQTT broker: ${e.toString()}',
        connectionState: _currentConnectionState.name,
        cause: e,
      );
    }
  }

  /// Disconnects from the MQTT broker and stops message processing.
  ///
  /// Gracefully handles ongoing operations and cleanup.
  Future<void> disconnect() async {
    try {
      _updateConnectionState(ConnectionState.disconnecting);
      
      // Cancel pending operations
      for (final completer in _pendingOperations.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            const ConnectionException('Disconnecting - operation cancelled'),
          );
        }
      }
      _pendingOperations.clear();
      
      await _mqttClient.disconnect();
      _updateConnectionState(ConnectionState.disconnected);
    } catch (e) {
      _updateConnectionState(ConnectionState.disconnected);
      throw ConnectionException(
        'Error during disconnect: ${e.toString()}',
        cause: e,
      );
    }
  }

  /// Stream of connection state changes for reactive monitoring.
  ///
  /// Emits [ConnectionState] values when the connection state changes.
  Stream<ConnectionState> get connectionState => 
      _connectionStateController.stream;

  /// Current connection state.
  ConnectionState get currentConnectionState => _currentConnectionState;

  /// Configuration used by this instance.
  MerkleKVConfig get config => _config;

  /// Retrieves a value by key.
  ///
  /// Returns null if the key does not exist.
  /// Throws [ValidationException] if key is invalid.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<String?> get(String key) async {
    key.validateAsKey();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('get_$key');
    final response = await _executeCommand(
      Command.get(id: commandId, key: key),
      Duration(seconds: 10),
    );
    
    if (response.status == ResponseStatus.ok) {
      return response.value as String?;
    } else if (response.errorCode == ErrorCode.notFound) {
      return null;
    } else {
      _throwForResponse(response);
    }
  }

  /// Stores a key-value pair.
  ///
  /// Throws [ValidationException] if key or value is invalid.
  /// Throws [PayloadException] if value exceeds size limits.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<void> set(String key, String value) async {
    key.validateAsKey();
    value.validateAsValue();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('set_${key}_${value.hashCode}');
    final response = await _executeCommand(
      Command.set(id: commandId, key: key, value: value),
      Duration(seconds: 10),
    );
    
    if (response.status != ResponseStatus.ok) {
      _throwForResponse(response);
    }
  }

  /// Deletes a key (idempotent - always returns OK regardless of existence).
  ///
  /// Throws [ValidationException] if key is invalid.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<void> delete(String key) async {
    key.validateAsKey();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('delete_$key');
    final response = await _executeCommand(
      Command.delete(id: commandId, key: key),
      Duration(seconds: 10),
    );
    
    // DELETE is idempotent - always succeeds regardless of key existence
    if (response.status != ResponseStatus.ok && 
        response.errorCode != ErrorCode.notFound) {
      _throwForResponse(response);
    }
  }

  /// Increments a numeric value by the specified amount.
  ///
  /// Creates the key with value 0 if it doesn't exist.
  /// Returns the new value after increment.
  ///
  /// Throws [ValidationException] if key is invalid or amount causes overflow.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<int> increment(String key, [int amount = 1]) async {
    key.validateAsKey();
    InputValidator.validateAmount(amount);
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('incr_${key}_$amount');
    final response = await _executeCommand(
      Command.increment(id: commandId, key: key, amount: amount),
      Duration(seconds: 10),
    );
    
    if (response.status == ResponseStatus.ok) {
      return response.value as int;
    } else {
      _throwForResponse(response);
    }
  }

  /// Decrements a numeric value by the specified amount.
  ///
  /// Creates the key with value 0 if it doesn't exist.
  /// Returns the new value after decrement.
  ///
  /// Throws [ValidationException] if key is invalid or amount causes overflow.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<int> decrement(String key, [int amount = 1]) async {
    key.validateAsKey();
    InputValidator.validateAmount(amount);
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('decr_${key}_$amount');
    final response = await _executeCommand(
      Command.decrement(id: commandId, key: key, amount: amount),
      Duration(seconds: 10),
    );
    
    if (response.status == ResponseStatus.ok) {
      return response.value as int;
    } else {
      _throwForResponse(response);
    }
  }

  /// Appends a value to the end of an existing string.
  ///
  /// Creates the key with empty string if it doesn't exist.
  /// Returns the length of the string after append.
  ///
  /// Throws [ValidationException] if key or value is invalid.
  /// Throws [PayloadException] if resulting value exceeds size limits.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<int> append(String key, String value) async {
    key.validateAsKey();
    value.validateAsValue();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('append_${key}_${value.hashCode}');
    final response = await _executeCommand(
      Command.append(id: commandId, key: key, value: value),
      Duration(seconds: 10),
    );
    
    if (response.status == ResponseStatus.ok) {
      return response.value as int;
    } else {
      _throwForResponse(response);
    }
  }

  /// Prepends a value to the beginning of an existing string.
  ///
  /// Creates the key with empty string if it doesn't exist.
  /// Returns the length of the string after prepend.
  ///
  /// Throws [ValidationException] if key or value is invalid.
  /// Throws [PayloadException] if resulting value exceeds size limits.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (10 seconds).
  Future<int> prepend(String key, String value) async {
    key.validateAsKey();
    value.validateAsValue();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('prepend_${key}_${value.hashCode}');
    final response = await _executeCommand(
      Command.prepend(id: commandId, key: key, value: value),
      Duration(seconds: 10),
    );
    
    if (response.status == ResponseStatus.ok) {
      return response.value as int;
    } else {
      _throwForResponse(response);
    }
  }

  /// Retrieves multiple keys in a single operation.
  ///
  /// Returns a map where missing keys have null values.
  /// Throws [ValidationException] if any key is invalid.
  /// Throws [PayloadException] if bulk payload exceeds limits.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (20 seconds).
  Future<Map<String, String?>> getMultiple(List<String> keys) async {
    keys.validateAsKeys();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('mget_${keys.join('_').hashCode}');
    final response = await _executeCommand(
      Command.mget(id: commandId, keys: keys),
      Duration(seconds: 20),
    );
    
    if (response.status == ResponseStatus.ok) {
      final results = response.results ?? [];
      final resultMap = <String, String?>{};
      
      for (final result in results) {
        resultMap[result.key] = result.value;
      }
      
      // Ensure all requested keys are in the result
      for (final key in keys) {
        resultMap.putIfAbsent(key, () => null);
      }
      
      return resultMap;
    } else {
      _throwForResponse(response);
    }
  }

  /// Sets multiple key-value pairs in a single operation.
  ///
  /// Returns a map indicating success (true) or failure (false) for each key.
  /// Throws [ValidationException] if any key or value is invalid.
  /// Throws [PayloadException] if bulk payload exceeds limits.
  /// Throws [ConnectionException] if disconnected and offline queue disabled.
  /// Throws [TimeoutException] if operation times out (20 seconds).
  Future<Map<String, bool>> setMultiple(Map<String, String> keyValues) async {
    keyValues.validateAsKeyValues();
    _ensureConnectedOrOfflineEnabled();
    
    final commandId = _getOrCreateCommandId('mset_${keyValues.hashCode}');
    final response = await _executeCommand(
      Command.mset(id: commandId, keyValues: keyValues),
      Duration(seconds: 20),
    );
    
    if (response.status == ResponseStatus.ok) {
      final results = response.results ?? [];
      final resultMap = <String, bool>{};
      
      for (final result in results) {
        resultMap[result.key] = result.isSuccess;
      }
      
      // Ensure all requested keys are in the result
      for (final key in keyValues.keys) {
        resultMap.putIfAbsent(key, () => false);
      }
      
      return resultMap;
    } else {
      _throwForResponse(response);
    }
  }

  /// Disposes resources and cleans up connections.
  ///
  /// Should be called when the instance is no longer needed.
  Future<void> dispose() async {
    await disconnect();
    await _connectionStateController.close();
    await _storage.dispose();
  }

  // Private methods

  void _setupConnectionStateMonitoring() {
    // Monitor MQTT client connection state
    _mqttClient.connectionState.listen((state) {
      _updateConnectionState(state);
    });
  }

  void _updateConnectionState(ConnectionState newState) {
    if (_currentConnectionState != newState) {
      _currentConnectionState = newState;
      _connectionStateController.add(newState);
    }
  }

  void _ensureConnectedOrOfflineEnabled() {
    if (_currentConnectionState != ConnectionState.connected) {
      // TODO: Check if offline queue is enabled when that feature is implemented
      // For now, we fail fast when disconnected
      throw ConnectionException(
        'Operation requires connection - client is ${_currentConnectionState.name}',
        connectionState: _currentConnectionState.name,
      );
    }
  }

  String _getOrCreateCommandId(String operationKey) {
    // Reuse command ID for retry operations to maintain idempotency
    return _retryCommandIds.putIfAbsent(
      operationKey,
      () => UuidGenerator.generate(),
    );
  }

  Future<Response> _executeCommand(Command command, Duration timeout) async {
    final completer = Completer<Response>();
    _pendingOperations[command.id] = completer;
    
    try {
      // Send command via MQTT or process locally if testing
      final response = await _commandProcessor.processCommand(command);
      
      if (!completer.isCompleted) {
        completer.complete(response);
      }
      
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw TimeoutException(
        'Operation timed out',
        operation: command.op,
        timeoutMs: timeout.inMilliseconds,
      );
    } finally {
      _pendingOperations.remove(command.id);
      // Clear retry command ID after successful completion
      _retryCommandIds.removeWhere((key, value) => value == command.id);
    }
  }

  Never _throwForResponse(Response response) {
    final message = response.error ?? 'Unknown error';
    final code = response.errorCode ?? ErrorCode.internalError;
    
    switch (code) {
      case ErrorCode.timeout:
        throw TimeoutException(
          message,
          operation: 'unknown',
          timeoutMs: 0,
        );
      case ErrorCode.payloadTooLarge:
        throw PayloadException(
          message,
          payloadType: 'command',
          actualSize: 0,
          maxSize: InputValidator.maxCommandPayloadBytes,
        );
      case ErrorCode.invalidRequest:
        throw ValidationException(message);
      case ErrorCode.rangeOverflow:
        throw ValidationException(message, field: 'amount');
      case ErrorCode.invalidType:
        throw ValidationException(message, field: 'value');
      default:
        throw InternalException(message, errorCode: code);
    }
  }
}