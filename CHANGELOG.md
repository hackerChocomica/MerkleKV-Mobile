# Changelog

All notable changes to MerkleKV Mobile will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with strict Locked
Specification v1.0 compliance.

## [Unreleased]

### Planned
- Enhanced error handling and retry mechanisms
- Additional MQTT broker compatibility testing
- Flutter web support investigation

### Added
- **Retained Publish Support (Selective)**: Added retained flag across internal publish paths used strictly for broker mode detection. Normal application data traffic remains `retain=false`, preserving Locked Spec constraints while enabling deterministic external vs embedded broker capability probing.
- **Deterministic Subscription Restoration**: Introduced SUBACK‑gated restoration flow. `TopicRouter` now waits for per-topic SUBACK acknowledgments (via new `onSubscribed` stream) before signaling restoration complete, eliminating race conditions where early publishes could arrive before subscriptions became active.
- **`onSubscribed` Acknowledgment Stream**: New public stream on MQTT client abstraction emitting topic strings upon SUBACK; facilitates precise synchronization for tests and internal recovery logic.
- **Test Coverage**: Added `response_subscription_restore_test` validating that responses published during a disconnect window are received after reconnection once restoration completes; added broker mode detection integration test leveraging retained messages.

### Fixed
- **Lost Post-Reconnect Messages**: Resolved race where first response after reconnect (e.g. `r2`) was occasionally missed due to subscription restoration completing after publishes. Now gated on SUBACK events with timeout fallback.
- **Stale Updates Listener**: Ensured MQTT updates listener is always reattached on each successful connection to prevent silent message drops after reconnect sequences.

### Changed
- **Subscription Restoration Semantics**: Restoration now defined as ALL prior topics having received SUBACK (or timed out) rather than merely re-issuing subscribe calls. Adds determinism for higher-level components and tests.

### Documentation
- Added README section: “Deterministic Subscription Restoration (SUBACK‑Gated)” describing rationale, flow, and timeout behavior.

### 🧪 Testing
- Full test suite (703 tests) updated; all mocks implement new `onSubscribed` interface.
- Added deterministic waits (`waitForRestore()`) in integration tests to avoid arbitrary delays.

### 🔒 Locked Spec v1.0 Compliance
- Core constraints (QoS=1, retain=false for application data, size/time limits) remain intact.
- Retained usage is narrowly scoped to broker capability detection and is not used for replication/event payloads, preserving wire compatibility and determinism.

### Migration Notes
- Consumers using custom test doubles for the MQTT client must implement the new `onSubscribed` stream (can emit synchronously upon `subscribe()` for simple cases).
- No breaking method signature removals; addition is backward compatible for clients that ignore the new stream.

### Performance Impact
- Negligible: SUBACK wait introduces microsecond-to-millisecond latency only during restoration; normal steady-state publish/subscribe path unchanged.

## [1.0.0-beta.1] - 2024-09-17

### Added - CI/CD Build System & Production Readiness

- **Reliable Build Infrastructure**: Complete CI/CD build system with proper working directory handling
  - `scripts/build-flutter.sh`: Robust Flutter APK build script solving "Target file lib/main.dart not found" CI/CD issues
  - Automatic project structure detection and verification
  - Detailed progress reporting with APK size detection (~87MB debug builds)
  - Comprehensive error handling with proper exit codes
- **Repository Maintenance**: Professional repository cleanup and documentation standardization
  - Updated `.gitignore` to exclude build artifacts, patch files, and development debris
  - Removed unnecessary files: `*.patch`, `*.bundle`, `*.tar.gz`, `e2e_execution.log`
  - Added development artifact patterns for cleaner repository management
- **Enhanced Documentation**: Complete README.md overhaul with practical installation guides
  - APK download instructions with GitHub releases integration
  - Build script usage documentation with CI/CD context
  - Available scripts reference table for development workflow
  - Performance benchmarks and APK size reporting
- **Production Environment Setup**: Flutter 3.16.0 compatibility with Android SDK 36.0.0 and Gradle 8.4

### Fixed - Critical Build Issues

- **CI/CD Working Directory Bug**: Resolved "Target file lib/main.dart not found" by creating unified build script
- **Flutter Analyze Errors**: Fixed 572 → 0 Flutter analyze errors in corrupted `main_beta.dart`
- **Build Process Reliability**: Eliminated separate shell process issues that broke working directory context
- **File Corruption Recovery**: Complete reconstruction of corrupted Flutter application files

### Added - Enhanced Replication System (PR #58)

- **Enhanced Event Publisher** (Locked Spec §7): Complete replication event publishing system with reliable delivery guarantees
  - Persistent outbox queue with offline resilience and automatic retry logic
  - Monotonic sequence numbers with automatic recovery and gap detection  
  - At-least-once delivery guarantee using MQTT QoS=1 with acknowledgment tracking
  - Comprehensive observability metrics for monitoring publish rates, queue status, and delivery health
  - Configurable flush batching with size and time-based triggers
- **Production-Ready CI/CD**: Robust GitHub Actions workflow with MQTT broker integration testing
  - System-level Mosquitto broker setup for integration validation
  - Simplified smoke tests focusing on dependency resolution and connectivity
  - Reliable CI pipeline avoiding Dart SDK corruption issues

### Added - Core Platform (Phase 1)

- **CBOR serializer for replication change events** (Spec §3.3, §11): deterministic encoding, tombstone handling, and strict ≤300 KiB size limit with comprehensive tests.
- **MerkleKVConfig** (Locked Spec §11): Immutable config, defaults, validation, secure JSON (secrets excluded), `copyWith`, `defaultConfig`.
- **MQTT Client Layer** (Locked Spec §6): Connection lifecycle, exponential backoff with jitter (±20%), Clean Start=false, Session Expiry=24h, LWT, QoS=1 & retain=false, TLS enforcement with credentials.
- **Topic scheme + router** (canonical §2) with validation, QoS enforcement, and auto re-subscribe.
- **Command Correlation Layer** (Locked Spec §3.1-3.2): Request/response correlation with UUIDv4 IDs, monotonic timeouts (10s/20s/30s), deduplication cache (10min TTL, LRU), payload validation (512 KiB limit), structured logging, async/await API.
- **Storage Engine** (Issue #6, Locked Spec §5.1, §5.6, §8): Complete in-memory storage implementation with optional persistence:
  - In-memory key-value store with Last-Write-Wins conflict resolution using `(timestampMs, nodeId)` ordering
  - Tombstone lifecycle management with 24-hour retention and garbage collection per §5.6
  - Optional persistence with append-only JSON format, SHA-256 integrity checksums, and corruption recovery
  - UTF-8 size validation per §11: keys ≤256 bytes, values ≤256 KiB with multi-byte character support
  - StorageEntry model with version vectors, StorageInterface abstraction, InMemoryStorage implementation, and StorageFactory
  - Comprehensive unit tests covering LWW edge cases, tombstone GC, persistence round-trip, and UTF-8 boundaries
- **Tests**: 28 tests for config, 21 tests for MQTT client, 45+ tests for command correlation; statistical jitter validation; subscription and publish enforcement.
- Initial repository structure and development setup
- Comprehensive automation scripts for GitHub issue management
- Project board automation with milestone-based organization
- Complete repository hygiene and process documentation

### Changed

- Public exports updated in `merkle_kv_core.dart` to include config and MQTT client APIs.
- Established Locked Specification v1.0 constraints for all development

### Security

- Secrets never logged or serialized; TLS validation required with credentials.

### Deprecated

- None

### Removed

- None

### Fixed

- None

### Security

- Established security policy and vulnerability disclosure process
- Implemented secure MQTT connection requirements (TLS ≥1.2)
- Defined ACL and access control best practices

### 🔒 Locked Spec v1.0 Compliance

- ✅ MQTT-only transport established (QoS=1, retain=false)
- ✅ Topic structure defined: `{prefix}/{client_id}/cmd|res`
- ✅ Size limits established: key ≤256B, value ≤256KiB, command ≤512KiB
- ✅ Timeout constraints defined: 10/20/30 seconds
- ✅ Reconnect backoff specified: 1→32s ±20% jitter
- ✅ LWW conflict resolution with vector timestamps
- ✅ Operation idempotency and deterministic behavior requirements

---

## Template for Future Releases

<!-- 
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features and functionality

### Changed
- Changes to existing functionality

### Deprecated
- Features that will be removed in future versions

### Removed
- Features removed in this version

### Fixed
- Bug fixes and corrections

### Security
- Security improvements and vulnerability fixes

### 🔒 Locked Spec v1.0 Compliance
- ✅ All changes maintain Locked Spec v1.0 compatibility
- ✅ No wire format changes
- ✅ MQTT-only transport preserved
- ✅ Size and timeout constraints maintained

### 📱 Mobile Platform Updates
- iOS-specific changes
- Android-specific changes
- React Native bridge updates

### ⚡ Performance Improvements
- Performance optimizations and improvements

### 🧪 Testing
- Testing improvements and new test coverage

### 📚 Documentation
- Documentation updates and improvements
-->

---

## Changelog Guidelines

### Categories

**Added** - New features, APIs, or capabilities
**Changed** - Changes to existing functionality
**Deprecated** - Features marked for removal in future versions
**Removed** - Features removed in this version
**Fixed** - Bug fixes and issue resolutions
**Security** - Security improvements and vulnerability fixes

### Mobile Platform Tracking

All changes should note their impact on:

- **iOS Compatibility** - iOS-specific changes and compatibility
- **Android Compatibility** - Android-specific changes and compatibility  
- **React Native Bridge** - Changes affecting the React Native integration
- **Performance Impact** - Battery, memory, and network implications

### Spec Compliance Tracking

Every release must confirm:

- **Wire Format Compatibility** - No breaking protocol changes
- **MQTT Constraints** - QoS=1, retain=false maintained
- **Size Limits** - Key/value/command size constraints respected
- **Timeout Behavior** - Proper timeout and backoff implementation
- **Idempotency** - All operations remain idempotent
- **Determinism** - Consistent behavior across implementations

### Version Links

All version entries should link to the corresponding GitHub release and comparison view:

```markdown
[X.Y.Z]: https://github.com/AI-Decenter/MerkleKV-Mobile/releases/tag/vX.Y.Z
[Unreleased]: https://github.com/AI-Decenter/MerkleKV-Mobile/compare/vX.Y.Z...HEAD
```

### Breaking Changes

Any breaking changes must be clearly marked and include:

- **Migration Guide** - Steps to upgrade existing implementations
- **Compatibility Matrix** - Version compatibility information
- **Deprecation Timeline** - When deprecated features will be removed

### Security Updates

Security-related changes should include:

- **CVE Numbers** - If applicable
- **Severity Assessment** - Impact and urgency level
- **Affected Versions** - Which versions are impacted
- **Mitigation Steps** - How to address the security issue

---

For questions about this changelog or to suggest improvements, please open an issue or discussion on GitHub.
