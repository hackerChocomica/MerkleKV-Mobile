# MerkleKV Core

A distributed key-value store optimized for mobile edge devices with MQTT-based communication and replication.

## Features

### Topic Prefix Configuration & Multi-Tenant Isolation
- **UTF-8 Byte Length Validation**: Prefixes ≤50 bytes, Client IDs ≤128 bytes, Topics ≤100 bytes
- **Character Restrictions**: Only `[A-Za-z0-9_/-]` allowed, blocks MQTT wildcards
- **Multi-Tenant Support**: Prefix-based isolation with canonical topic schemes
- **Backward Compatibility**: Enhanced validation without breaking existing APIs
- **Comprehensive Validation**: Integrated into MerkleKVConfig and TopicScheme

### Anti-Entropy Protocol
- **SYNC/SYNC_KEYS Operations**: Efficient state synchronization between nodes
- **Payload Validation**: 512KiB size limits with precise overhead calculation
- **Rate Limiting**: Token bucket algorithm (configurable, default 5 req/sec)
- **Loop Prevention**: Reconciliation flags prevent replication event cycles
- **Error Handling**: Comprehensive error codes with timeout management
- **Observability**: Detailed metrics for sync performance and diagnostics

### Enhanced Replication System
- **Event Publisher**: Reliable replication event publishing with persistent outbox queue
- **CBOR Serialization**: Efficient binary encoding for replication events
- **Monotonic Sequencing**: Ordered event delivery with automatic recovery
- **Observability**: Comprehensive metrics for monitoring replication health
- **Offline Resilience**: Buffered delivery with at-least-once guarantee

### Core Platform
- **MQTT Communication**: Request-response pattern over MQTT with correlation
- **In-Memory Storage**: Fast key-value store with Last-Write-Wins conflict resolution  
- **Command Processing**: GET/SET/DEL operations with validation and error handling
- **Configuration Management**: Type-safe, immutable configuration with validation

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  merkle_kv_core: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

// Configure the client
final config = MerkleKVConfig(
  mqttHost: 'broker.example.com',
  nodeId: 'mobile-device-1',
  clientId: 'app-instance-1',
);

// Initialize and start
final client = MerkleKVMobile(config);
await client.start();

// Basic operations
await client.set('user:123', 'Alice');
final value = await client.get('user:123');
await client.delete('user:123');
```

### Multi-Tenant Configuration

```dart
// Configure tenant-specific MerkleKV instance
final config = MerkleKVConfig(
  mqttHost: 'mqtt.example.com',
  mqttPort: 1883,
  clientId: 'mobile-device-001',
  nodeId: 'node-001',
  topicPrefix: 'tenant-a/production', // Tenant isolation
);

// Topics will be generated as:
// Commands: tenant-a/production/mobile-device-001/cmd
// Responses: tenant-a/production/mobile-device-001/res
// Replication: tenant-a/production/replication/events

// Multiple tenant environments
final prodConfig = MerkleKVConfig(
  mqttHost: 'mqtt.company.com',
  clientId: 'app-device-123',
  nodeId: 'prod-node-1',
  topicPrefix: 'myapp/production',
);

final stagingConfig = MerkleKVConfig(
  mqttHost: 'mqtt.company.com', 
  clientId: 'app-device-123',
  nodeId: 'staging-node-1',
  topicPrefix: 'myapp/staging',
);
```

### Event Publishing

```dart
// Enable replication event publishing
final config = MerkleKVConfig(
  mqttHost: 'broker.example.com', 
  nodeId: 'mobile-device-1',
  clientId: 'app-instance-1',
  enableReplication: true,
);

final client = MerkleKVMobile(config);
await client.start();

// Operations automatically publish replication events
await client.set('key', 'value'); // Publishes SET event
await client.delete('key');       // Publishes DEL event
```

### Secure MQTT (TLS + Auth)

```dart
// Simple TLS with username/password
final tlsConfig = MerkleKVConfig(
  mqttHost: 'secure-broker.example.com',
  mqttPort: 8883,
  mqttUseTls: true,
  clientId: 'app-instance-1',
  nodeId: 'mobile-device-1',
  username: '<from-keystore>',
  password: '<from-keystore>',
);

// Or explicit security options
final advanced = tlsConfig.copyWith(
  mqttSecurity: MqttSecurityConfig(
    enableTLS: true,
    minTLSVersion: TLSVersion.v1_2,
    enforceHostnameValidation: true,
    validateCertificateChain: true,
    authMethod: AuthenticationMethod.usernamePassword,
    username: '<from-keystore>',
    password: '<from-keystore>',
  ),
);
```

### Deterministic Subscription Restoration (SUBACK‑Gated)

When a client reconnects, previously subscribed topics must be re‑established **before** publishing code assumes routing is active. Relying on timing delays or immediate `subscribe()` returns is race‑prone because MQTT only guarantees a subscription once the broker sends a SUBACK.

To make this deterministic, the MQTT abstraction exposes an `onSubscribed` broadcast stream emitting topic names as SUBACKs arrive. Higher‑level components (e.g. `TopicRouterImpl`) aggregate the set of topics that need restoration, issue subscriptions, then await acknowledgments (or a timeout) before resuming normal operation.

Key properties:

- `Stream<String> onSubscribed` (added to `MqttClientInterface`) fires once per successful broker acknowledgment.
- Restoration waits for *all* pending topics or a configurable timeout (default ~750ms) to avoid indefinite hangs on a misbehaving broker.
- Updates listener is reattached on every reconnect to prevent using a stale stream that silently drops messages.
- Tests (see `response_subscription_restore_test.dart`) confirm messages published immediately after reconnect are delivered reliably.

#### Example: Waiting for Restoration in Integration Code

```dart
// After reconnecting the underlying MQTT client:
await mqttClient.connect();

// Ask the topic router to restore and wait deterministically
await topicRouter.waitForRestore(timeout: const Duration(seconds: 2));

// Safe: responses / replication / command routes are active now
await topicRouter.publishResponse('ready');
```

#### Custom Client Implementors

If you implement your own `MqttClientInterface`, ensure:

```dart
final _subAckController = StreamController<String>.broadcast();

@override
Stream<String> get onSubscribed => _subAckController.stream;

void _handleSubAck(String topic) {
  if (!_subAckController.isClosed) _subAckController.add(topic);
}

Future<void> subscribe(String topic) async {
  // Delegate to underlying library; register a callback that calls _handleSubAck
}

Future<void> dispose() async {
  await _subAckController.close();
}
```

#### Timeout Handling

If not all topics acknowledge within the timeout window, the router logs a warning and proceeds with the subset that succeeded. Your application can choose to:

1. Retry restoration for missing topics.
2. Surface a degraded‑state metric / health signal.
3. Trigger a reconnect cycle if critical subscriptions are absent.

#### Why Not Blind Delays?

Fixed delays either wait too long (hurting latency) or still race under load. SUBACK‑gated restoration is precise and fast under nominal conditions while still bounded under failure.

#### Testing Strategy

- Positive path: all SUBACKs received → completion future resolves quickly.
- Lossy broker simulation: drop some SUBACKs → timeout path exercised, ensuring no deadlock.
- Post‑reconnect publish immediately after `waitForRestore()` (response test) to assert zero message loss.

---

### Anti-Entropy Synchronization

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

// Initialize anti-entropy protocol
final protocol = AntiEntropyProtocolImpl(
  storage: storage,
  merkleTree: merkleTree,
  mqttClient: mqttClient,
  metrics: metrics,
  nodeId: 'node1',
);

// Configure rate limiting (optional)
protocol.configureRateLimit(requestsPerSecond: 10.0);

// Perform synchronization with another node
try {
  final result = await protocol.performSync('target-node-id');
  
  if (result.success) {
    print('Sync completed: ${result.keysSynced} keys in ${result.duration}');
    print('Examined ${result.keysExamined} keys across ${result.rounds} rounds');
  } else {
    print('Sync failed: ${result.errorCode} - ${result.errorMessage}');
  }
} on SyncException catch (e) {
  switch (e.code) {
    case SyncErrorCode.rateLimited:
      print('Too many sync requests, please wait');
      break;
    case SyncErrorCode.payloadTooLarge:
      print('Sync payload exceeds 512KiB limit');
      break;
    case SyncErrorCode.timeout:
      print('Sync operation timed out');
      break;
    default:
      print('Sync error: ${e.message}');
  }
}

// Monitor sync metrics
final metrics = protocol.getMetrics();
print('Sync attempts: ${metrics.antiEntropySyncAttempts}');
print('Average duration: ${metrics.antiEntropySyncDurations.average}ms');
print('Payload rejections: ${metrics.antiEntropyPayloadRejections}');
print('Rate limit hits: ${metrics.antiEntropyRateLimitHits}');
```

## Replication: CBOR Encoding/Decoding

```dart
// Encoding
final bytes = CborSerializer.encode(
  ReplicationEvent.value(
    key: 'k',
    nodeId: 'n1',
    seq: 42,
    timestampMs: 1712345678901,
    value: 'hello',
  ),
);

// Decoding
final evt = CborSerializer.decode(bytes);

// Constructors
// - value event (tombstone=false): includes `value`
// - tombstone event (tombstone=true): omits `value`
final del = ReplicationEvent.tombstone(
  key: 'k',
  nodeId: 'n1',
  seq: 43,
  timestampMs: 1712345679901,
);
```

### Anti-Entropy Protocol Details

The anti-entropy synchronization protocol follows Locked Spec §9 with these characteristics:

- **Two-Phase Protocol**: SYNC (compare root hashes) → SYNC_KEYS (exchange divergent entries)
- **Payload Limits**: Maximum 512KiB serialized payload with overhead estimation
- **Rate Limiting**: Token bucket algorithm prevents sync flooding (configurable rate)
- **Loop Prevention**: `putWithReconciliation` method prevents replication event cycles
- **LWW Conflict Resolution**: Last-Write-Wins based on timestamp during reconciliation
- **Comprehensive Error Handling**: Six error codes covering all failure scenarios
- **Timeout Management**: Configurable timeouts with automatic cleanup
- **Metrics Integration**: 8 new metrics for observability and debugging

### Notes

- Deterministic field order; binary output is stable across devices.
- Size limit: total CBOR payload ≤ 300 KiB (Spec §11). Oversize → error.
- Schema fields use snake_case (e.g., timestamp_ms, node_id).

## Testing

MerkleKV-Mobile includes a comprehensive testing suite with >95% code coverage targeting all critical components.

### Test Architecture

- **Unit Tests**: Comprehensive coverage of storage engine, MQTT client, topic router, and command processor
- **Property-Based Tests**: Edge case validation using random data generation
- **Negative Testing**: Extensive error condition and boundary testing
- **Integration Tests**: End-to-end scenarios including anti-entropy synchronization

### Key Testing Features

- **Last-Writer-Wins (LWW) Validation**: Conflict resolution testing with node ID tiebreakers
- **MQTT QoS=1 Enforcement**: Guaranteed message delivery validation
- **UTF-8 Boundary Testing**: Unicode edge case handling
- **Payload Size Validation**: 1MB limits and bulk operation boundaries
- **Security Testing**: Wildcard injection prevention and multi-tenant isolation

### Running Tests

```bash
# Run all tests
dart test

# Run unit tests with coverage
dart test --coverage=coverage/
dart pub global run coverage:format_coverage --lcov --in=coverage/ --out=coverage/lcov.info

# Run specific test suites
dart test test/unit/storage/    # Storage engine tests
dart test test/unit/mqtt/       # MQTT client and router tests
dart test test/unit/processor/  # Command processor tests
```

### Test Organization

```
test/
├── unit/                    # Comprehensive unit tests (>95% coverage)
│   ├── storage/            # Storage engine LWW resolution, tombstone GC
│   ├── mqtt/               # MQTT client QoS, reconnection, topic routing
│   └── processor/          # Command validation, bulk limits, idempotency
├── utils/                  # Testing utilities
│   ├── generators.dart    # Property-based test data generators
│   └── mock_helpers.dart  # Mock implementations and test helpers
└── integration/           # System and integration tests
```

For detailed testing documentation, see [TESTING.md](TESTING.md).

````
