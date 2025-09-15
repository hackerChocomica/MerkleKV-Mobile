# Implement Public API Surface for MerkleKV Mobile (Issue #21)

## Summary

This PR implements a comprehensive public API surface for MerkleKV Mobile as requested in GitHub issue #21. The implementation provides a clean, type-safe interface for distributed key-value operations on mobile devices with UTF-8 validation, thread-safety, and fail-fast behavior.

## Features Implemented

### ✅ Core Public API
- **MerkleKV Class**: Main public API with all operations (GET, SET, DEL, INCR, DECR, APPEND, PREPEND)
- **Builder Pattern Configuration**: `MerkleKVConfig.builder()` with fluent API
- **Thread-Safe Operations**: All operations support concurrent access
- **Connection State Management**: Stream-based reactive updates
- **Clean Import**: Single import `import 'package:merkle_kv_core/merkle_kv.dart';`

### ✅ Exception Hierarchy
- `MerkleKVException` base class
- `ValidationException` for input validation errors
- `ConnectionException` for connection-related errors  
- `TimeoutException` for operation timeouts
- `PayloadException` for size limit violations
- `InternalException` for system errors
- `UnsupportedOperationException` for unsupported features

### ✅ Input Validation
- **UTF-8 Byte-Size Validation**: Keys ≤256 bytes, Values ≤256 KiB, Payloads ≤512 KiB
- **Fail-Fast Validation**: Pre-operation checks prevent network round trips
- **Extension Methods**: Convenient validation helpers on String/List/Map

### ✅ Configuration Builder
- **Fluent API**: Method chaining for easy configuration
- **Preset Configurations**: `mobileDefaults()`, `edgeDefaults()`, `testingDefaults()`
- **Comprehensive Options**: TLS, authentication, persistence, timeouts

### ✅ Operation Types

#### Single-Key Operations (10s timeout)
- `get(key)` - Retrieve value
- `set(key, value)` - Store key-value pair  
- `delete(key)` - Remove key (idempotent)
- `increment(key, [amount])` - Increment numeric value
- `decrement(key, [amount])` - Decrement numeric value
- `append(key, suffix)` - Append to string value
- `prepend(key, prefix)` - Prepend to string value

#### Bulk Operations (20s timeout)
- `getMultiple(keys)` - Retrieve multiple keys
- `setMultiple(keyValues)` - Store multiple key-value pairs

#### Connection Management
- `connect()` - Establish connection
- `disconnect()` - Close connection
- `dispose()` - Clean up resources
- `connectionState` stream - Monitor connection state

## Key Technical Features

### Thread Safety
All operations are thread-safe and can be called concurrently:
```dart
await Future.wait([
  merkleKV.set('key1', 'value1'),
  merkleKV.set('key2', 'value2'),
  merkleKV.increment('counter'),
]);
```

### UTF-8 Validation with Size Limits
```dart
// Pre-validates key ≤256 bytes, value ≤256 KiB
await merkleKV.set('key', 'value');  // Validates before network call

// Bulk operations validate total payload ≤512 KiB
await merkleKV.setMultiple(keyValues);
```

### Fail-Fast Behavior
```dart
try {
  await merkleKV.get('key'); // When disconnected
} on ConnectionException catch (e) {
  // Fails immediately without network attempt
}
```

### Idempotent DEL Operations
```dart
await merkleKV.delete('key');  // Always returns OK, even if key doesn't exist
```

### Reactive Connection Monitoring
```dart
merkleKV.connectionState.listen((state) {
  switch (state) {
    case ConnectionState.connecting:
      print('Connecting...');
      break;
    case ConnectionState.connected:
      print('Connected and ready');
      break;
    case ConnectionState.disconnected:
      print('Disconnected');
      break;
  }
});
```

## Builder Pattern Configuration

```dart
final config = MerkleKVConfig.builder()
  .host('mqtt.example.com')
  .clientId('mobile-device-1')
  .nodeId('device-uuid-123')
  .enableTls()
  .credentials('username', 'password')
  .mobileDefaults()  // Optimized for mobile devices
  .build();

final merkleKV = await MerkleKV.create(config);
```

## Files Added/Modified

### New Files
- `lib/src/api/exceptions.dart` - Exception hierarchy
- `lib/src/api/validation.dart` - UTF-8 validation utilities  
- `lib/src/api/config_builder.dart` - Configuration builder
- `lib/src/api/merkle_kv.dart` - Main public API class
- `lib/src/utils/uuid_generator.dart` - UUID generation utility
- `lib/merkle_kv.dart` - Clean public import
- `example/public_api_example.dart` - Comprehensive usage example
- `API_DOCUMENTATION.md` - Complete API documentation

### Modified Files
- `lib/merkle_kv_core.dart` - Added public API exports
- `lib/src/commands/command.dart` - Added missing factory methods

## Size Limits (Locked Spec §11 Compliance)

| Component | Limit | Enforcement |
|-----------|-------|-------------|
| Key | ≤256 bytes UTF-8 | Pre-operation validation |
| Value | ≤256 KiB UTF-8 | Pre-operation validation |
| Command payload | ≤512 KiB | Pre-transmission validation |
| CBOR replication payload | ≤300 KiB | Pre-transmission validation |

## Timeout Handling (Locked Spec Compliance)

| Operation Type | Timeout | Operations |
|----------------|---------|------------|
| Single-key | 10 seconds | GET, SET, DEL, INCR, DECR, APPEND, PREPEND |
| Multi-key | 20 seconds | MGET, MSET |
| Sync | 30 seconds | Anti-entropy synchronization |

## Error Handling Examples

```dart
try {
  await merkleKV.set('x' * 300, 'value'); // Key too long
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
  print('Field: ${e.field}, Value: ${e.value}');
}

try {
  await merkleKV.get('key'); // When disconnected
} on ConnectionException catch (e) {
  print('Connection error: ${e.message}');
  print('State: ${e.connectionState}');
}

try {
  await merkleKV.get('key'); // Operation timeout
} on TimeoutException catch (e) {
  print('Timeout: ${e.operation} exceeded ${e.timeoutMs}ms');
}
```

## Quality Assurance

### Static Analysis Results
- ✅ All critical errors resolved
- ✅ Code passes `dart analyze` with only minor style warnings
- ✅ No breaking changes to existing APIs
- ✅ Comprehensive error handling and validation

### Testing Status
- ✅ Comprehensive example demonstrating all features
- ✅ Integration with existing command processor and MQTT client
- ✅ All acceptance criteria from GitHub issue #21 met

## Breaking Changes
None. This is purely additive - existing APIs remain unchanged.

## Migration Guide
For new users, simply import the clean API:
```dart
import 'package:merkle_kv_core/merkle_kv.dart';
```

Existing internal API users can continue using the existing imports unchanged.

## Documentation
- Complete API documentation in `API_DOCUMENTATION.md`
- Comprehensive usage example in `example/public_api_example.dart`
- Inline documentation on all public methods
- Best practices and integration examples included

## Future Considerations
- The API surface is designed to be stable and extensible
- Builder pattern supports adding new configuration options without breaking changes
- Exception hierarchy can be extended for new error types
- All operations are designed for potential offline-first enhancements

---

**Closes #21**

This implementation fully addresses all requirements from the GitHub issue:
- ✅ Public MerkleKV class with complete API surface
- ✅ MerkleKVConfig.builder() pattern implementation  
- ✅ Comprehensive input validation with UTF-8 byte-size checking
- ✅ MerkleKVException hierarchy with specific exception types
- ✅ Thread-safe operation handling
- ✅ Connection state management with Stream for reactive updates
- ✅ Fail-fast behavior implementation
- ✅ Idempotent DEL operations
- ✅ Command ID reuse logic for retry operations