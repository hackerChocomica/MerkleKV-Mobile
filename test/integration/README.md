# Integration Testing Documentation

This document describes the comprehensive integration test suite for MerkleKV Mobile, implementing GitHub issue #24 requirements for testing with real MQTT brokers.

## Overview

The integration test suite validates MerkleKV operations against real MQTT brokers (Mosquitto and HiveMQ) to ensure compliance with the Locked Specification and robust real-world performance.

## Test Infrastructure

### Broker Support
- **Mosquitto 2.0**: Primary broker with full TLS/ACL support
- **HiveMQ Community Edition**: Secondary broker for compatibility testing
- **Toxiproxy**: Network simulation and partition testing
 - **Embedded Stub Broker (fallback)**: Lightweight in-process MQTT stub used ONLY when no real broker is reachable and the test environment hasn't explicitly required a real one. This guarantees tests never hang due to a missing broker while still allowing strict modes.

### Security Features
- **TLS 1.2+**: Mandatory encryption with client certificate authentication
- **Access Control Lists (ACLs)**: Topic-level permissions and tenant isolation
- **Certificate Management**: CA-signed certificates for all components

### Test Environment
```bash
# Quick start
./scripts/run_integration_tests.sh

# Run specific test suite
./scripts/run_integration_tests.sh -s security

# Setup infrastructure only
./scripts/run_integration_tests.sh --setup-only
```

### Deterministic Broker Startup (New)

For fast local iteration or CI environments without Docker services pre-started, a deterministic helper is available:

```bash
# Start (or noop if already running) a basic Mosquitto on port 1883
./scripts/start_test_broker.sh

# Environment overrides
BROKER_PORT=1884 COMPOSE_FILE=docker-compose.test.yml SERVICE_NAME=mosquitto-test ./scripts/start_test_broker.sh
```

Integration tests auto-handle broker availability via `TestBrokerHelper` with the following precedence:
1. If something is already listening on the target port → use it.
2. If `IT_DOCKER_START=1` → attempt `scripts/start_test_broker.sh` (idempotent) then re-check the port.
3. If still unavailable and `IT_REQUIRE_BROKER=1` → FAIL fast (no embedded fallback allowed).
4. Otherwise → start the in-process embedded stub broker for minimal connectivity so tests proceed.

Environment flags:
```
IT_REQUIRE_BROKER=1      # Force real broker; error if not reachable
IT_DOCKER_START=1         # Try to launch docker-compose.basic.yml mosquitto-test automatically
IT_BROKER_PORT=1883       # Override port (default 1883)
IT_BROKER_START_TIMEOUT=30# Seconds to wait for docker startup (default 25)
MKV_PROJECT_ROOT=/path    # Explicit project root (auto-inferred otherwise)
```

Recommended CI invocation ensuring a real broker:
```bash
IT_DOCKER_START=1 IT_REQUIRE_BROKER=1 ./scripts/start_test_broker.sh
IT_REQUIRE_BROKER=1 dart test packages/merkle_kv_core/test/integration/authz_controller_integration_test.dart
```

This approach eliminates flaky connection timeouts and enforces explicit failure instead of silent skips.

## Test Suites

### 1. End-to-End Operations (`end_to_end_operations_test.dart`)

Validates basic MerkleKV operations through real brokers:

- **GET/SET/DEL operations**: Core key-value operations
- **Broker compatibility**: Mosquitto and HiveMQ support
- **Error handling**: Network failures and invalid operations
- **Response validation**: Proper CBOR encoding/decoding

```dart
// Example test execution
dart test test/integration/end_to_end_operations_test.dart
```

### 2. Payload Limits (`payload_limits_test.dart`)

Ensures compliance with Locked Spec payload constraints:

- **256KiB value limit**: Maximum individual value size
- **512KiB bulk operations**: Maximum batch operation size
- **Message size enforcement**: Broker-level validation
- **Integrity verification**: Data consistency across size limits

Key constants:
```dart
static const int maxValueSize = 256 * 1024;      // 256KiB
static const int maxBulkSize = 512 * 1024;       // 512KiB
```

### 3. Security Testing (`security_test.dart`)

Comprehensive security validation matrix:

- **TLS 1.2+ enforcement**: No unencrypted connections
- **Client certificate authentication**: Mutual TLS validation
- **ACL topic isolation**: Cross-tenant security
- **Permission enforcement**: Read/write access controls

Security matrix tested:
```
[Valid cert, Valid topic] → Success
[Valid cert, Invalid topic] → Denied
[Invalid cert, Any topic] → Connection refused
[No TLS, Any operation] → Connection refused
```

### 4. Convergence Testing (`convergence_test.dart`)

Anti-entropy and consistency validation:

- **LWW conflict resolution**: Last-writer-wins semantics
- **Convergence timing**: Within configured intervals
- **Multi-key scenarios**: Complex state synchronization
- **Network delay handling**: Realistic timing constraints

Timing constraints:
```dart
static const Duration convergenceInterval = Duration(seconds: 30);
static const Duration maxConflictResolution = Duration(seconds: 45);
```

### 5. Multi-Client Operations (`multi_client_test.dart`)

Concurrent operations and partition tolerance:

- **Concurrent modifications**: Multiple clients, same keys
- **Network partition simulation**: Split-brain scenarios
- **Partition recovery**: Message queuing and replay
- **Broker restart resilience**: State preservation

Network partition simulation:
```dart
// Create partition using Toxiproxy
await createNetworkPartition(Duration(seconds: 30));
// Verify queued operations
await verifyPartitionRecovery();
```

## Configuration

### Test Configuration (`test/integration/test_config.dart`)

Centralized configuration for all integration tests:

```dart
class TestConfig {
  // Broker endpoints
  static const String mosquittoHost = 'localhost';
  static const int mosquittoPort = 1883;
  static const int mosquittoTlsPort = 8883;
  
  // Test data generation
  static String generateTestKey(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  static Uint8List generateTestValue(int size) => Uint8List.fromList(List.generate(size, (i) => i % 256));
  
  // Locked Spec compliance
  static const int maxValueSize = 256 * 1024;      // 256KiB
  static const int maxBulkSize = 512 * 1024;       // 512KiB
  static const Duration convergenceInterval = Duration(seconds: 30);
}
```

### Docker Compose (`docker-compose.test.yml`)

Multi-broker test environment:

```yaml
services:
  mosquitto-test:
    image: eclipse-mosquitto:2.0
    ports:
      - "1883:1883"      # MQTT
      - "8883:8883"      # MQTT over TLS
    volumes:
      - ./test/integration/mosquitto.conf:/mosquitto/config/mosquitto.conf
      - ./test/integration/certs:/mosquitto/certs

  hivemq-test:
    image: hivemq/hivemq-ce:2024.3
    ports:
      - "1884:1883"      # MQTT (alternative port)
      - "8080:8080"      # Management API
    volumes:
      - ./test/integration/hivemq:/opt/hivemq/conf

  toxiproxy:
    image: ghcr.io/shopify/toxiproxy:2.9.0
    ports:
      - "8474:8474"      # Admin API
      - "1885:1885"      # Mosquitto proxy
      - "1886:1886"      # HiveMQ proxy
```

## Certificate Management

### Generation Scripts

**Certificate Generation** (`test/integration/generate_certs.sh`):
```bash
# CA certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt

# Server certificates
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -out server.crt

# Client certificates
openssl genrsa -out client.key 4096
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -out client.crt
```

**Certificate Conversion** (`test/integration/convert_certs.sh`):
```bash
# Convert to PKCS12 for HiveMQ
openssl pkcs12 -export -out server.p12 -inkey server.key -in server.crt -certfile ca.crt
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt
```

### Certificate Structure
```
test/integration/certs/
├── ca.crt              # Certificate Authority
├── ca.key              # CA private key
├── server.crt          # Server certificate
├── server.key          # Server private key
├── server.p12          # Server PKCS12 (HiveMQ)
├── client.crt          # Client certificate
├── client.key          # Client private key
├── client.p12          # Client PKCS12 (HiveMQ)
└── truststore.jks      # Java truststore (HiveMQ)
```

## Broker Configuration

### Mosquitto Configuration (`test/integration/mosquitto.conf`)

```conf
# Basic settings
listener 1883
protocol mqtt

# TLS listener
listener 8883
protocol mqtt
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/server.crt
keyfile /mosquitto/certs/server.key
require_certificate true
use_identity_as_username true
tls_version tlsv1.2

# Message size limits (Locked Spec compliance)
message_size_limit 1048576  # 1MB total message limit

# ACL file
acl_file /mosquitto/config/acl.conf

# Logging
log_dest stdout
log_type all
connection_messages true
```

### HiveMQ Configuration (`test/integration/hivemq/config.xml`)

```xml
<hivemq>
    <listeners>
        <!-- Plain MQTT -->
        <tcp-listener>
            <port>1883</port>
            <bind-address>0.0.0.0</bind-address>
        </tcp-listener>
        
        <!-- TLS MQTT -->
        <tls-tcp-listener>
            <port>8883</port>
            <bind-address>0.0.0.0</bind-address>
            <tls>
                <keystore>
                    <path>/opt/hivemq/conf/server.p12</path>
                    <password>test123</password>
                    <private-key-password>test123</private-key-password>
                </keystore>
                <truststore>
                    <path>/opt/hivemq/conf/truststore.jks</path>
                    <password>test123</password>
                </truststore>
                <client-authentication-mode>REQUIRED</client-authentication-mode>
                <protocols>
                    <protocol>TLSv1.2</protocol>
                    <protocol>TLSv1.3</protocol>
                </protocols>
            </tls>
        </tls-tcp-listener>
    </listeners>
    
    <!-- Message size limits -->
    <restrictions>
        <max-packet-size>1048576</max-packet-size>  <!-- 1MB -->
    </restrictions>
</hivemq>
```

## Continuous Integration

### GitHub Actions (`/.github/workflows/integration-tests.yml`)

Automated CI pipeline with comprehensive testing:

```yaml
strategy:
  matrix:
    test-suite: [
      end_to_end_operations,
      payload_limits, 
      security,
      convergence,
      multi_client
    ]

steps:
  - name: Run Integration Tests
    run: |
      ./scripts/run_integration_tests.sh -s ${{ matrix.test-suite }}
    timeout-minutes: 30

  - name: Security Compliance Check
    run: |
      # Verify TLS 1.2+ enforcement
      # Check certificate validation
      # Validate ACL configurations
```

### Performance Baselines

Scheduled performance validation:
```yaml
- name: Performance Baseline
  if: github.event.schedule
  run: |
    # 256KiB value operations: < 1s
    # 512KiB bulk operations: < 5s  
    # Convergence: < 30s
    ./scripts/run_integration_tests.sh --performance-baseline
```

## Running Tests

### Prerequisites

1. **Docker and Docker Compose**: Container orchestration
2. **Dart SDK**: Test execution environment
3. **OpenSSL**: Certificate generation
4. **Curl**: Health checks and API calls

### Basic Usage

```bash
# Install and check prerequisites
./scripts/run_integration_tests.sh -c

# Run all integration tests
./scripts/run_integration_tests.sh

# Run specific test suite
./scripts/run_integration_tests.sh -s security

# Setup infrastructure only (for development)
./scripts/run_integration_tests.sh --setup-only

# Check broker status
./scripts/run_integration_tests.sh --status

# Clean up test environment
./scripts/run_integration_tests.sh --cleanup-only
```

### Development Workflow

1. **Setup**: `./scripts/run_integration_tests.sh --setup-only`
2. **Develop**: Edit test files in `test/integration/`
3. **Test**: `dart test test/integration/specific_test.dart`
4. **Iterate**: Repeat steps 2-3
5. **Cleanup**: `./scripts/run_integration_tests.sh --cleanup-only`

### Manual Broker Testing

When infrastructure is running:

```bash
# Test Mosquitto connectivity
mosquitto_pub -h localhost -p 1883 -t "test/topic" -m "hello"
mosquitto_sub -h localhost -p 1883 -t "test/topic"

# Test TLS connectivity
mosquitto_pub -h localhost -p 8883 \
  --cafile test/integration/certs/ca.crt \
  --cert test/integration/certs/client.crt \
  --key test/integration/certs/client.key \
  -t "test/topic" -m "hello tls"
```

## Locked Specification Compliance

### Message Size Limits
- **Individual values**: 256KiB maximum
- **Bulk operations**: 512KiB maximum total
- **Broker enforcement**: 1MB message size limit

### Security Requirements
- **TLS 1.2+**: Mandatory for production
- **Client certificates**: Mutual authentication
- **Topic ACLs**: Tenant isolation
- **No plaintext**: All data encrypted in transit

### Convergence Timing
- **Anti-entropy interval**: 30 seconds maximum
- **Conflict resolution**: 45 seconds maximum
- **Network tolerance**: Graceful degradation

### Multi-Client Support
- **Concurrent operations**: Race condition handling
- **Partition tolerance**: Message queuing
- **Recovery semantics**: Consistent state restoration

## Troubleshooting

### Common Issues

**Certificate errors**:
```bash
# Regenerate certificates
rm -rf test/integration/certs/
./test/integration/generate_certs.sh
./test/integration/convert_certs.sh
```

**Broker connectivity**:
```bash
# Check broker logs
docker-compose -f docker-compose.test.yml logs mosquitto-test
docker-compose -f docker-compose.test.yml logs hivemq-test

# Verify ports
netstat -tlnp | grep -E "(1883|8883|1884|8080)"
```

**Test timeouts**:
```bash
# Increase test timeout
dart test test/integration/specific_test.dart --timeout=600s

# Check system resources
docker stats
```

### Debug Mode

Enable verbose logging:
```bash
./scripts/run_integration_tests.sh -v -s convergence
```

View broker configuration:
```bash
docker-compose -f docker-compose.test.yml exec mosquitto-test cat /mosquitto/config/mosquitto.conf
```

## Performance Expectations

### Baseline Metrics
- **256KiB value SET**: < 1 second
- **256KiB value GET**: < 500ms  
- **512KiB bulk operation**: < 5 seconds
- **Anti-entropy convergence**: < 30 seconds
- **TLS handshake**: < 2 seconds

### Resource Usage
- **Memory per broker**: < 512MB
- **Disk per test run**: < 100MB
- **Network bandwidth**: < 10MB/s sustained
- **CPU usage**: < 50% per core

These expectations ensure the test suite runs efficiently in CI environments while providing realistic performance validation.

## Future Enhancements

### Planned Improvements
1. **Additional brokers**: RabbitMQ, Apache Pulsar support
2. **Chaos engineering**: Automated failure injection
3. **Performance profiling**: Detailed latency analysis
4. **Load testing**: High-volume operation simulation
5. **Metrics collection**: Prometheus/Grafana integration

### Integration Points
- **Monitoring**: Health check endpoints
- **Alerting**: Test failure notifications  
- **Reporting**: Performance trend analysis
- **Documentation**: Auto-generated API docs

This comprehensive integration test suite ensures MerkleKV Mobile meets all GitHub issue #24 requirements while providing a robust foundation for ongoing development and validation.