# MerkleKV Mobile Public API Documentation

## Overview

The MerkleKV Mobile Public API provides a clean, type-safe interface for distributed key-value operations on mobile devices. Built on MQTT transport with automatic replication and conflict resolution.

## Key Features

- **Thread-safe concurrent operations** - All operations can be called safely from multiple threads
- **UTF-8 byte-size validation** - Enforces Locked Spec §11 limits automatically
- **Fail-fast behavior** - Operations fail immediately when disconnected (unless offline queue enabled)
- **Idempotent operations** - DEL always returns OK, retry operations reuse command IDs
- **Reactive connection monitoring** - Stream-based connection state updates
- **Builder pattern configuration** - Easy, fluent API for setup

## Quick Start

```dart
import 'package:merkle_kv_core/merkle_kv.dart';

// Create configuration
final config = MerkleKVConfig.builder()
  .host('mqtt.example.com')
  .clientId('mobile-device-1')
  .nodeId('device-uuid-123')
  .enableTls()
  .mobileDefaults()
  .build();

// Create and connect
final merkleKV = await MerkleKV.create(config);
await merkleKV.connect();

// Perform operations
await merkleKV.set('key', 'value');
final value = await merkleKV.get('key');
await merkleKV.delete('key');

// Cleanup
await merkleKV.disconnect();
await merkleKV.dispose();
```

## Configuration

### Using the Builder Pattern

```dart
final config = MerkleKVConfig.builder()
  .host('mqtt.example.com')           // Required: MQTT broker host
  .port(8883)                         // Optional: Custom port (auto-inferred from TLS)
  .clientId('mobile-client-1')        // Required: Unique client identifier
  .nodeId('node-uuid-123')            // Required: Unique node identifier
  .enableTls()                        // Enable TLS encryption
  .credentials('username', 'password') // Optional: MQTT authentication
  .topicPrefix('myapp/production')    // Optional: Topic prefix for isolation
  .enablePersistence('/path/to/storage') // Optional: Enable disk persistence
  .keepAlive(120)                     // Optional: MQTT keep-alive interval
  .sessionExpiry(3600)                // Optional: Session expiry interval
  .build();
```

### Preset Configurations

```dart
// Mobile-optimized settings
final config = MerkleKVConfig.builder()
  .host('broker.example.com')
  .clientId('mobile-client')
  .nodeId('mobile-node')
  .mobileDefaults()  // Sets mobile-optimized timeouts and persistence
  .build();

// Edge device settings (minimal resources)
final config = MerkleKVConfig.builder()
  .host('broker.example.com')
  .clientId('edge-client')
  .nodeId('edge-node')
  .edgeDefaults()  // Optimizes for minimal resource usage
  .build();

// Testing settings
final config = MerkleKVConfig.builder()
  .host('test.mosquitto.org')
  .clientId('test-client')
  .nodeId('test-node')
  .testingDefaults()  // Sets up for testing environments
  .build();
```

## Core Operations

### GET Operation

```dart
// Retrieve a value by key
final value = await merkleKV.get('user:123');
if (value != null) {
  print('User: $value');
} else {
  print('User not found');
}
```

**Behavior:**
- Returns `null` if key doesn't exist
- Timeout: 10 seconds
- Thread-safe: Yes

### SET Operation

```dart
// Store a key-value pair
await merkleKV.set('user:123', 'John Doe');
```

**Behavior:**
- Creates or updates the key
- Timeout: 10 seconds
- Thread-safe: Yes
- Validates key ≤256 bytes UTF-8, value ≤256 KiB UTF-8

### DELETE Operation

```dart
// Delete a key (idempotent)
await merkleKV.delete('user:123');
```

**Behavior:**
- Always returns successfully, even if key doesn't exist
- Idempotent operation
- Timeout: 10 seconds
- Thread-safe: Yes

## Numeric Operations

### Increment

```dart
// Increment by default amount (1)
final newValue = await merkleKV.increment('counter');

// Increment by custom amount
final newValue = await merkleKV.increment('counter', 5);
```

**Behavior:**
- Creates key with value 0 if it doesn't exist
- Returns new value after increment
- Validates against integer overflow
- Thread-safe: Yes

### Decrement

```dart
// Decrement by default amount (1)
final newValue = await merkleKV.decrement('counter');

// Decrement by custom amount
final newValue = await merkleKV.decrement('counter', 3);
```

**Behavior:**
- Creates key with value 0 if it doesn't exist
- Returns new value after decrement
- Validates against integer overflow
- Thread-safe: Yes

## String Operations

### Append

```dart
// Append to existing string
final newLength = await merkleKV.append('message', ' World');
```

**Behavior:**
- Creates key with empty string if it doesn't exist
- Returns length of string after append
- Validates result doesn't exceed 256 KiB limit
- Thread-safe: Yes

### Prepend

```dart
// Prepend to existing string
final newLength = await merkleKV.prepend('message', 'Hello ');
```

**Behavior:**
- Creates key with empty string if it doesn't exist
- Returns length of string after prepend
- Validates result doesn't exceed 256 KiB limit
- Thread-safe: Yes

## Bulk Operations

### Multiple GET (MGET)

```dart
// Retrieve multiple keys at once
final keys = ['user:1', 'user:2', 'user:3'];
final values = await merkleKV.getMultiple(keys);

// values is Map<String, String?> where missing keys have null values
values.forEach((key, value) {
  print('$key = ${value ?? "not found"}');
});
```

**Behavior:**
- Timeout: 20 seconds
- Missing keys have `null` values in result
- Validates total payload ≤512 KiB
- Thread-safe: Yes

### Multiple SET (MSET)

```dart
// Set multiple key-value pairs at once
final keyValues = {
  'user:1': 'Alice',
  'user:2': 'Bob',
  'user:3': 'Charlie',
};
final results = await merkleKV.setMultiple(keyValues);

// results is Map<String, bool> indicating success/failure per key
results.forEach((key, success) {
  print('$key: ${success ? "OK" : "FAILED"}');
});
```

**Behavior:**
- Timeout: 20 seconds
- Returns success status per key
- Validates total payload ≤512 KiB
- Thread-safe: Yes

## Connection Management

### Connection State Monitoring

```dart
// Monitor connection state changes
merkleKV.connectionState.listen((state) {
  switch (state) {
    case ConnectionState.connecting:
      print('Connecting...');
      break;
    case ConnectionState.connected:
      print('Connected');
      break;
    case ConnectionState.disconnecting:
      print('Disconnecting...');
      break;
    case ConnectionState.disconnected:
      print('Disconnected');
      break;
  }
});

// Check current state
print('Current state: ${merkleKV.currentConnectionState}');
```

### Manual Connection Control

```dart
// Connect manually
await merkleKV.connect();

// Disconnect manually
await merkleKV.disconnect();

// Dispose resources (calls disconnect automatically)
await merkleKV.dispose();
```

## Error Handling

The API uses specific exception types for different error conditions:

### ValidationException

```dart
try {
  await merkleKV.set('x' * 300, 'value'); // Key too long
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
  print('Field: ${e.field}');
  print('Value: ${e.value}');
}
```

**Triggers:**
- Key exceeds 256 UTF-8 bytes
- Value exceeds 256 KiB UTF-8 bytes
- Invalid key characters (null bytes, control characters)
- Invalid amounts for numeric operations

### ConnectionException

```dart
try {
  await merkleKV.get('key'); // When disconnected
} on ConnectionException catch (e) {
  print('Connection error: ${e.message}');
  print('Connection state: ${e.connectionState}');
}
```

**Triggers:**
- Operations when disconnected (and offline queue disabled)
- Connection failures
- Network errors

### TimeoutException

```dart
try {
  await merkleKV.get('key'); // Takes too long
} on TimeoutException catch (e) {
  print('Timeout error: ${e.message}');
  print('Operation: ${e.operation}');
  print('Timeout: ${e.timeoutMs}ms');
}
```

**Triggers:**
- Single-key operations: >10 seconds
- Multi-key operations: >20 seconds
- Sync operations: >30 seconds

### PayloadException

```dart
try {
  await merkleKV.set('key', 'x' * (300 * 1024)); // Value too large
} on PayloadException catch (e) {
  print('Payload error: ${e.message}');
  print('Type: ${e.payloadType}');
  print('Actual size: ${e.actualSize}B');
  print('Max size: ${e.maxSize}B');
}
```

**Triggers:**
- Value exceeds 256 KiB UTF-8 bytes
- Command payload exceeds 512 KiB
- CBOR payload exceeds 300 KiB

## Size Limits (Locked Spec §11)

| Component | Limit | Validation |
|-----------|-------|------------|
| Key | ≤256 bytes UTF-8 | Pre-operation |
| Value | ≤256 KiB UTF-8 | Pre-operation |
| Command payload | ≤512 KiB | Pre-transmission |
| CBOR replication payload | ≤300 KiB | Pre-transmission |

## Timeouts (Locked Spec)

| Operation Type | Timeout | Examples |
|----------------|---------|----------|
| Single-key | 10 seconds | GET, SET, DEL, INCR, DECR, APPEND, PREPEND |
| Multi-key | 20 seconds | MGET, MSET |
| Sync | 30 seconds | Anti-entropy synchronization |

## Thread Safety

All operations are thread-safe and can be called concurrently from multiple threads:

```dart
// Safe to call from multiple threads
await Future.wait([
  merkleKV.set('key1', 'value1'),
  merkleKV.set('key2', 'value2'),
  merkleKV.increment('counter'),
  merkleKV.get('existing_key'),
]);
```

## Best Practices

### Configuration

- Use builder pattern for complex configurations
- Apply appropriate presets (`mobileDefaults()`, `edgeDefaults()`)
- Enable TLS for production environments
- Use meaningful client and node IDs for debugging

### Connection Management

- Monitor connection state for reactive UX
- Handle connection errors gracefully
- Always call `dispose()` when done

### Error Handling

- Catch specific exception types for targeted handling
- Use validation early to prevent network round trips
- Implement retry logic for transient failures

### Performance

- Use bulk operations for multiple keys
- Monitor payload sizes to stay under limits
- Consider connection state before operations

### Testing

- Use `testingDefaults()` for test configurations
- Mock connections for unit testing
- Test error conditions thoroughly

## Integration Examples

### Flutter App

```dart
class MerkleKVService {
  static MerkleKV? _instance;
  
  static Future<MerkleKV> getInstance() async {
    if (_instance == null) {
      final config = MerkleKVConfig.builder()
        .host('your-broker.example.com')
        .clientId('flutter-app-${Platform.operatingSystem}')
        .nodeId(await _getDeviceId())
        .enableTls()
        .mobileDefaults()
        .build();
        
      _instance = await MerkleKV.create(config);
      await _instance!.connect();
    }
    return _instance!;
  }
  
  static Future<String> _getDeviceId() async {
    // Implement device ID generation
    return 'device-${DateTime.now().millisecondsSinceEpoch}';
  }
}
```

### Background Service

```dart
class BackgroundSyncService {
  late MerkleKV _merkleKV;
  
  Future<void> initialize() async {
    final config = MerkleKVConfig.builder()
      .host('sync.example.com')
      .clientId('background-service')
      .nodeId('sync-node')
      .enablePersistence()
      .build();
      
    _merkleKV = await MerkleKV.create(config);
    
    // Monitor connection state
    _merkleKV.connectionState.listen(_handleConnectionChange);
    
    await _merkleKV.connect();
  }
  
  void _handleConnectionChange(ConnectionState state) {
    if (state == ConnectionState.connected) {
      // Trigger sync operations
      _performSync();
    }
  }
  
  Future<void> _performSync() async {
    try {
      // Sync operations
      await _merkleKV.set('last_sync', DateTime.now().toIso8601String());
    } catch (e) {
      // Handle sync errors
      print('Sync failed: $e');
    }
  }
}
```