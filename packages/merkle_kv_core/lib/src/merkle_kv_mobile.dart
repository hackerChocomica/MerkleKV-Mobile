/// Main client façade for MerkleKV Mobile
///
/// This class provides a minimal, mobile-friendly façade over the core
/// [`MerkleKV`] API to align with the onboarding examples in the README.
///
/// Design intent (academic rationale):
/// - Separation of Concerns — Initialization and network lifecycle concerns
///   (e.g., `start`/`stop`) are encapsulated while delegating data operations to
///   the underlying, fully featured [`MerkleKV`] engine. This preserves a lean
///   surface area for application code while maintaining access to advanced
///   capabilities when needed.
/// - Fail-fast Safety — All data-plane methods validate that the client has
///   been started, yielding early and explicit errors if the lifecycle contract
///   is violated. This reduces latent runtime failures on mobile platforms.
/// - Compatibility — The façade mirrors the README contract:
///   `final client = MerkleKVMobile(config); await client.start();` and then
///   `get/set/delete` operations, without re-implementing protocol logic.
library merkle_kv_mobile;

import 'api/merkle_kv.dart' show MerkleKV;
import 'config/merkle_kv_config.dart' show MerkleKVConfig;
import 'mqtt/connection_state.dart' show ConnectionState;

/// Mobile-oriented façade over the core MerkleKV engine.
class MerkleKVMobile {
  /// Immutable configuration for this client instance.
  final MerkleKVConfig config;

  MerkleKV? _inner; // Lazily created on start()

  /// Creates a new MerkleKV Mobile client instance with the provided [config].
  ///
  /// The constructor is side-effect free; network connections are established
  /// on [start].
  MerkleKVMobile(this.config);

  /// Returns the semantic version of this façade.
  String get version => '0.0.1';

  /// Indicates whether the client has been started.
  bool get isStarted => _inner != null;

  /// Starts the underlying MerkleKV engine and establishes an MQTT connection.
  ///
  /// Idempotent: repeated invocations after a successful start are no-ops.
  Future<void> start() async {
    if (_inner != null) return;
    final kv = await MerkleKV.create(config);
    await kv.connect();
    _inner = kv;
  }

  /// Gracefully stops the client and releases resources.
  ///
  /// Safe to call multiple times.
  Future<void> stop() async {
    final kv = _inner;
    if (kv == null) return;
    await kv.disconnect();
    _inner = null;
  }

  /// Disposes the underlying engine (disconnects and deallocates resources).
  Future<void> dispose() async {
    final kv = _inner;
    if (kv != null) {
      await kv.dispose();
      _inner = null;
    }
  }

  /// Stream of connection state changes for reactive UI or telemetry layers.
  Stream<ConnectionState> get connectionState => _require().connectionState;

  /// Current connection state snapshot.
  ConnectionState get currentConnectionState => _require().currentConnectionState;

  /// Exposes the underlying engine for advanced scenarios.
  ///
  /// While most mobile apps should rely on façade methods below, this getter
  /// allows direct access to the complete API when needed.
  MerkleKV get engine => _require();

  // -------- Data-plane operations (pass-through) --------

  Future<String?> get(String key) => _require().get(key);

  Future<void> set(String key, String value) => _require().set(key, value);

  Future<void> delete(String key) => _require().delete(key);

  Future<int> increment(String key, [int amount = 1]) =>
      _require().increment(key, amount);

  Future<int> decrement(String key, [int amount = 1]) =>
      _require().decrement(key, amount);

  Future<int> append(String key, String value) =>
      _require().append(key, value);

  Future<int> prepend(String key, String value) =>
      _require().prepend(key, value);

  Future<Map<String, String?>> getMultiple(List<String> keys) =>
      _require().getMultiple(keys);

  Future<Map<String, bool>> setMultiple(Map<String, String> keyValues) =>
      _require().setMultiple(keyValues);

  // -------- Internal helpers --------

  MerkleKV _require() {
    final kv = _inner;
    if (kv == null) {
      throw StateError(
        'MerkleKVMobile has not been started. Call start() before invoking operations.',
      );
    }
    return kv;
  }
}
