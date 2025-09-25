import 'dart:async';
import 'dart:developer' as developer;

import '../config/merkle_kv_config.dart';
import '../commands/error_classifier.dart';
import 'connection_state.dart';
import 'mqtt_client_interface.dart';
import 'topic_scheme.dart';
import 'topic_validator.dart';
import 'topic_permissions.dart';
import 'topic_authz_metrics.dart';

/// Abstract interface for topic-based message routing.
///
/// Manages subscribe/publish operations for command, response, and replication
/// topics with automatic re-subscription after reconnect.
abstract class TopicRouter {
  /// Subscribe to command messages for this client.
  ///
  /// [handler] - Callback function (topic, payload) => void
  Future<void> subscribeToCommands(void Function(String, String) handler);

  /// Subscribe to replication messages for all devices.
  ///
  /// [handler] - Callback function (topic, payload) => void
  Future<void> subscribeToReplication(void Function(String, String) handler);

  /// Subscribe to response messages for this client.
  ///
  /// [handler] - Callback function (topic, payload) => void
  Future<void> subscribeToResponses(void Function(String, String) handler);
  Future<void> subscribeToResponsesOf(String clientId, void Function(String, String) handler);

  /// Publish a command message to target client.
  ///
  /// [targetClientId] - Target client identifier
  /// [payload] - Message payload
  Future<void> publishCommand(String targetClientId, String payload);

  /// Publish a response message from this client.
  ///
  /// [payload] - Response payload
  Future<void> publishResponse(String payload);

  /// Publish a replication event for all devices.
  ///
  /// [payload] - Replication event payload
  Future<void> publishReplication(String payload);

  /// Dispose resources and clean up subscriptions.
  Future<void> dispose();

  /// Authorization metrics (allow/deny counters) for diagnostics.
  TopicAuthzMetrics get authzMetrics;
}

/// Default implementation of [TopicRouter] using MQTT client.
///
/// Provides topic management with validation, QoS enforcement, and automatic
/// re-subscription after reconnection events.
class TopicRouterImpl implements TopicRouter {
  final MqttClientInterface _mqttClient;
  final TopicScheme _topicScheme;
  // Enforce client-side authz for canonical scheme (prefix 'merkle_kv')
  final bool _enforceAuthz;
  final TopicPermissions _permissions;
  final TopicAuthzMetrics _metrics = TopicAuthzMetrics();

  // Active subscription handlers
  void Function(String, String)? _commandHandler;
  void Function(String, String)? _responseHandler;
  void Function(String, String)? _replicationHandler;

  // Controller may subscribe to other clients' response topics; track them for
  // reconnection restoration.
  final List<_ForeignResponseSubscription> _foreignResponseSubs = [];

  // Connection state monitoring
  StreamSubscription<ConnectionState>? _connectionSubscription;
  // Tracks completion of the most recent restoration cycle so tests (or
  // higher-level orchestration) can deterministically await subscription
  // re-establishment after a reconnect.
  Completer<void>? _lastRestoreCompleter;
  // Tracks pending topic filters awaiting SUBACK during a restoration cycle.
  Set<String>? _pendingRestoreTopics;
  StreamSubscription<String>? _subAckSub;

  /// Creates a TopicRouter with the provided configuration and MQTT client.
  TopicRouterImpl(MerkleKVConfig config, this._mqttClient)
    : _topicScheme = TopicScheme.create(config.topicPrefix, config.clientId),
      _enforceAuthz = TopicValidator.normalizePrefix(config.topicPrefix) == 'merkle_kv',
      _permissions = TopicPermissions(
          clientId: config.clientId,
          replicationAccess: config.replicationAccess,
          isController: config.isController) {
    _initializeConnectionMonitoring();
  }

  /// Initialize connection state monitoring for auto re-subscription.
  void _initializeConnectionMonitoring() {
    _connectionSubscription = _mqttClient.connectionState.listen((state) {
      if (state == ConnectionState.connected) {
        // Defer restoration to next microtask to ensure the underlying
        // MQTT client's onConnected handler has finished attaching the
        // updates stream listener and re-establishing its own internal
        // subscriptions. This avoids a subtle race where we resubscribe
        // before the updates listener is ready, potentially missing early
        // publications emitted immediately after reconnect.
        scheduleMicrotask(() {
          _restoreSubscriptions();
        });
      }
    });
  }

  /// Restore active subscriptions after reconnection.
  Future<void> _restoreSubscriptions() async {
    // Start a new restore cycle completer
    final completer = Completer<void>();
    _lastRestoreCompleter = completer;
    _subAckSub?.cancel();
    _pendingRestoreTopics = <String>{};
    developer.log(
      'Restoring subscriptions after reconnection',
      name: 'TopicRouter',
      level: 800, // INFO
    );

    // Re-subscribe to commands if handler is active
    if (_commandHandler != null) {
      await _mqttClient.subscribe(_topicScheme.commandTopic, _commandHandler!);
      _pendingRestoreTopics!.add(_topicScheme.commandTopic);
      developer.log(
        'Restored command subscription: ${_topicScheme.commandTopic}',
        name: 'TopicRouter',
        level: 800, // INFO
      );
    }

    // Re-subscribe to responses if handler is active
    if (_responseHandler != null) {
      await _mqttClient.subscribe(_topicScheme.responseTopic, _responseHandler!);
      _pendingRestoreTopics!.add(_topicScheme.responseTopic);
      developer.log(
        'Restored response subscription: ${_topicScheme.responseTopic}',
        name: 'TopicRouter',
        level: 800, // INFO
      );
    }

    // Restore controller foreign response subscriptions
    for (final sub in _foreignResponseSubs) {
      final topic = TopicValidator.buildResponseTopic(_topicScheme.prefix, sub.clientId);
      await _mqttClient.subscribe(topic, sub.handler);
      _pendingRestoreTopics!.add(topic);
      developer.log(
        'Restored foreign response subscription: $topic',
        name: 'TopicRouter',
        level: 800,
      );
    }

    // Re-subscribe to replication if handler is active
    if (_replicationHandler != null) {
      await _mqttClient.subscribe(
        _topicScheme.replicationTopic,
        _replicationHandler!,
      );
      _pendingRestoreTopics!.add(_topicScheme.replicationTopic);
      developer.log(
        'Restored replication subscription: ${_topicScheme.replicationTopic}',
        name: 'TopicRouter',
        level: 800, // INFO
      );
    }
    // If there are no pending topics (no active subscriptions), complete immediately.
    if (_pendingRestoreTopics!.isEmpty) {
      if (!completer.isCompleted) completer.complete();
      return;
    }

    // Listen for SUBACK acknowledgments of the restored topics. Complete the
    // restoration cycle only after all have been acknowledged or a timeout
    // occurs (as a safety valve to avoid hanging tests if acks are missed).
    final pending = _pendingRestoreTopics!;
    _subAckSub = _mqttClient.onSubscribed.listen((topic) {
      if (pending.remove(topic)) {
        developer.log(
          'Acknowledged restored subscription: $topic (remaining=${pending.length})',
          name: 'TopicRouter',
          level: 800,
        );
        if (pending.isEmpty && !completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Safety timeout: complete even if some acks not observed (broker impl
    // variance). This still allows forward progress while logging.
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!completer.isCompleted) {
        developer.log(
          'Restore timeout elapsed with pending=${pending.length}; completing restoration early',
          name: 'TopicRouter',
          level: 800,
        );
        completer.complete();
      }
    });
  }

  /// Await the completion of the most recent restoration cycle. If no
  /// restoration is in progress (or has already completed), this returns
  /// immediately. Intended primarily for integration tests to eliminate
  /// arbitrary sleep-based timing.
  Future<void> waitForRestore({Duration timeout = const Duration(seconds: 2)}) async {
    final c = _lastRestoreCompleter;
    if (c == null || c.isCompleted) return;
    try {
      await c.future.timeout(timeout, onTimeout: () {});
    } catch (_) {
      // Swallow – timeout simply means restore not witnessed within window.
    }
  }

  @override
  Future<void> subscribeToCommands(
    void Function(String, String) handler,
  ) async {
    _commandHandler = handler;
    await _mqttClient.subscribe(_topicScheme.commandTopic, handler);

    developer.log(
      'Subscribed to commands: ${_topicScheme.commandTopic}',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  @override
  Future<void> subscribeToReplication(
    void Function(String, String) handler,
  ) async {
    _replicationHandler = handler;
    await _mqttClient.subscribe(_topicScheme.replicationTopic, handler);

    developer.log(
      'Subscribed to replication: ${_topicScheme.replicationTopic}',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  @override
  Future<void> subscribeToResponses(
    void Function(String, String) handler,
  ) async {
    // Always own responses
    _responseHandler = handler;
    await _mqttClient.subscribe(_topicScheme.responseTopic, handler);
    _metrics.responseSubscribeAllowed++;

    developer.log(
      'Subscribed to responses: ${_topicScheme.responseTopic}',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  @override
  Future<void> subscribeToResponsesOf(String clientId, void Function(String, String) handler) async {
    if (_enforceAuthz && !_permissions.canSubscribeToResponsesOf(clientId)) {
      _metrics.responseSubscribeDenied++;
      throw ApiException(302, 'Not authorized to subscribe to responses of $clientId');
    }
    // Build topic for target client responses
    final topic = TopicValidator.buildResponseTopic(_topicScheme.prefix, clientId);
    await _mqttClient.subscribe(topic, handler);
    _metrics.responseSubscribeAllowed++;
    _foreignResponseSubs.add(_ForeignResponseSubscription(clientId, handler));
    developer.log(
      'Subscribed to responses of $clientId: $topic',
      name: 'TopicRouter',
      level: 800,
    );
  }

  @override
  Future<void> publishCommand(String targetClientId, String payload) async {
    // Client-side authorization: in canonical scheme, prevent cross-client publishes
    _assertCanPublishCommand(targetClientId);

    // Use TopicValidator for enhanced validation and consistent topic building
    final targetTopic = TopicValidator.buildCommandTopic(
      _topicScheme.prefix, 
      targetClientId,
    );

    await _mqttClient.publish(
      targetTopic,
      payload,
      forceQoS1: true,
      forceRetainFalse: true,
    );

    if (_enforceAuthz) _metrics.commandAllowed++;

    developer.log(
      'Published command to $targetTopic (${payload.length} bytes)',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  /// Asserts the caller is authorized to publish to the given target client.
  ///
  /// Policy (minimal client-side enforcement):
  /// - When using canonical prefix 'merkle_kv', non-controller clients are
  ///   only allowed to publish to their own command topic. Cross-client
  ///   publishes must be performed by privileged identities (enforced by
  ///   broker ACLs). We reflect that policy locally to fail fast.
  /// - For non-canonical prefixes (tests, custom setups), no client-side
  ///   restriction is applied.
  void _assertCanPublishCommand(String targetClientId) {
    if (!_enforceAuthz) return; // Non-canonical prefix: no client-side restriction
    if (_permissions.canPublishCommand(targetClientId)) return;
    _metrics.commandDenied++;
    throw ApiException(
      300,
      'Not authorized to publish commands to $targetClientId (requires controller role or self)',
    );
  }

  @override
  Future<void> publishResponse(String payload) async {
    await _mqttClient.publish(
      _topicScheme.responseTopic,
      payload,
      forceQoS1: true,
      forceRetainFalse: true,
    );

    developer.log(
      'Published response to ${_topicScheme.responseTopic} (${payload.length} bytes)',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  @override
  Future<void> publishReplication(String payload) async {
    if (_enforceAuthz && !_permissions.canPublishReplication()) {
      _metrics.replicationDenied++;
      throw ApiException(
        301,
        'Not authorized to publish replication events (replicationAccess=${_permissions.replicationAccess})',
      );
    }
    await _mqttClient.publish(
      _topicScheme.replicationTopic,
      payload,
      forceQoS1: true,
      forceRetainFalse: true,
    );

    if (_enforceAuthz) _metrics.replicationAllowed++;

    developer.log(
      'Published replication to ${_topicScheme.replicationTopic} (${payload.length} bytes)',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  @override
  Future<void> dispose() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _subAckSub?.cancel();
    _commandHandler = null;
  _responseHandler = null;
    _replicationHandler = null;
    _foreignResponseSubs.clear();
    _pendingRestoreTopics = null;

    developer.log(
      'TopicRouter disposed',
      name: 'TopicRouter',
      level: 800, // INFO
    );
  }

  @override
  TopicAuthzMetrics get authzMetrics => _metrics;

  /// Publish current authz metrics to an internal metrics topic (fire-and-forget)
  /// Only under canonical scheme to avoid polluting custom prefixes.
  Future<void> publishAuthzMetrics() async {
    if (!_enforceAuthz) return;
    final metricsTopic = '${_topicScheme.prefix}/metrics/authz';
    await _mqttClient.publish(
      metricsTopic,
      authzMetrics.toJson().toString(),
      forceQoS1: false,
      forceRetainFalse: true,
    );
  }
}

class _ForeignResponseSubscription {
  final String clientId;
  final void Function(String, String) handler;
  _ForeignResponseSubscription(this.clientId, this.handler);
}
