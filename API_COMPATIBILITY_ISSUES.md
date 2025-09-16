# Integration Tests API Compatibility Issues Summary

## 🚨 Critical API Changes Detected

The enabled integration tests are failing due to significant API evolution. Here are the main compatibility issues that need to be addressed:

### 1. **MerkleKVConfig Constructor Changes**
```dart
// OLD API (in tests):
MerkleKVConfig(
  nodeId: 'test-node-1',
  mqttHost: 'localhost',
  mqttPort: 1883,
  mqttUsername: 'admin',  // ❌ Parameter removed
  mqttPassword: 'admin',  // ❌ Parameter removed  
  useTls: false,          // ❌ Parameter renamed
)

// NEW API (current):
MerkleKVConfig(
  mqttHost: 'localhost',
  mqttPort: 1883,
  username: 'admin',      // ✅ Renamed from mqttUsername
  password: 'admin',      // ✅ Renamed from mqttPassword
  mqttUseTls: false,      // ✅ Renamed from useTls
  clientId: 'client-1',   // ✅ Required parameter added
  nodeId: 'node-1',       // ✅ Still required
)
```

### 2. **Storage API Changes**
```dart
// OLD API:
final storage = InMemoryKVStorage();     // ❌ Constructor not found
await storage.set(key, entry);          // ❌ Method removed

// NEW API:
final storage = InMemoryStorage();       // ✅ Correct constructor
await storage.store(key, entry);        // ✅ Method renamed
```

### 3. **Command System Changes**
```dart
// OLD API:
CommandRequest.set(key, value)           // ❌ Class not found
CommandResponse.fromJson(json)           // ❌ Class not found
ResponseStatus.OK                        // ❌ Enum value not found
ResponseStatus.INVALID_COMMAND           // ❌ Enum value not found

// NEW API:
// Need to investigate current command system implementation
```

### 4. **Model Constructor Changes**
```dart
// OLD API:
StorageEntry(
  key: key,
  value: value,
  timestamp: timestamp,    // ❌ Parameter removed
)

// NEW API:
StorageEntry(
  key: key,
  value: value,
  seq: sequenceNumber,     // ✅ Required parameter added
  timestampMs: timestamp,  // ✅ Renamed parameter
)
```

### 5. **MQTT Client API Changes**
```dart
// OLD API:
mqttClient.isConnected    // ❌ Getter removed

// NEW API:
// Need to investigate current connection state API
```

### 6. **Class Instantiation Issues**
```dart
// Abstract classes now:
CommandProcessor(storage: storage)  // ❌ Cannot instantiate abstract class
TopicRouter()                       // ❌ Cannot instantiate abstract class

// Constructor changes:
TopicScheme(nodeId)                 // ❌ Constructor signature changed
ConnectionLifecycle(...)            // ❌ Constructor not found
```

## 🔧 Required Fixes

### Phase 1: Configuration & Setup
1. **Update all MerkleKVConfig usage** to use new parameter names
2. **Add required clientId parameters** to all config instantiations
3. **Replace TestConfig usage** with IntegrationTestConfig constants

### Phase 2: Storage Layer
1. **Replace InMemoryKVStorage** with InMemoryStorage
2. **Update storage method calls** (set → store, etc.)
3. **Fix StorageEntry constructors** with new parameter names

### Phase 3: Command System
1. **Investigate current command API** structure
2. **Replace CommandRequest/CommandResponse** with current implementation
3. **Update ResponseStatus enum values** to match current API

### Phase 4: MQTT & Networking
1. **Fix MQTT connection state checking** (replace isConnected)
2. **Update TopicScheme instantiation** with new constructor
3. **Fix TLS certificate handling** type cast issues

### Phase 5: Test Utilities
1. **Create factory methods** for abstract classes (CommandProcessor, TopicRouter)
2. **Update test helper utilities** to match current APIs
3. **Fix response building patterns**

## 📊 Test Failure Stats

```
Total Integration Tests: 8 files moved
Failed to Load: 7 files (87.5%)
Successfully Loaded: 1 file (simple_broker_test.dart)

Error Categories:
- Constructor/Parameter Issues: ~40 errors
- Missing Classes/Methods: ~25 errors  
- Enum Value Changes: ~15 errors
- Type Conversion Issues: ~10 errors
```

## 🎯 Recommended Approach

### Immediate Actions:
1. **Focus on one test file** at a time (start with broker_connectivity_test.dart)
2. **Create API adapter layer** to bridge old test code with new APIs
3. **Update TestConfigurations class** to use current MerkleKVConfig format

### Long-term Strategy:
1. **Document current API patterns** for test development
2. **Create test utility factories** for commonly used objects
3. **Establish testing conventions** for new integration tests

## 🚨 Blockers

1. **TLS Certificate Handling**: Type cast error in security tests
2. **Command System**: Needs investigation of current implementation
3. **Abstract Class Factories**: Need concrete implementations for testing

## ✅ Next Steps

1. Fix TestConfigurations.mosquittoBasic() to use new MerkleKVConfig API
2. Create minimal working version of broker_connectivity_test.dart
3. Establish patterns for other tests to follow
4. Update integration test documentation

---

**Note**: These are expected compatibility issues from enabling previously isolated tests. The core functionality is intact - only test code needs updating to match evolved APIs.