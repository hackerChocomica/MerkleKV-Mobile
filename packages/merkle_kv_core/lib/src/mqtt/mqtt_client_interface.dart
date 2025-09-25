import 'dart:async';
import 'connection_state.dart';

/// Abstract interface for MQTT client operations.
///
/// Provides connection lifecycle management, message publishing/subscribing,
/// and connection state monitoring with reconnection capabilities.
abstract class MqttClientInterface {
  /// Stream of connection state changes.
  ///
  /// Emits current state and all subsequent state transitions.
  Stream<ConnectionState> get connectionState;

  /// Stream of topic names as they are acknowledged (SUBACK) by the broker.
  ///
  /// Implementations should emit each topic filter after the broker confirms
  /// the subscription (i.e. after receiving SUBACK). This enables higher-level
  /// coordination (such as deterministic re-subscription restoration waits)
  /// without relying on arbitrary delays.
  Stream<String> get onSubscribed;

  /// Current connection state snapshot.
  ///
  /// Should reflect the latest known connection state immediately without
  /// waiting for a new event on [connectionState].
  ConnectionState get currentConnectionState;

  /// Connect to the MQTT broker.
  ///
  /// Implements exponential backoff reconnection strategy with jitter.
  /// Uses session settings from configuration (keepAlive, sessionExpiry).
  ///
  /// Throws [Exception] if connection fails after all retries.
  Future<void> connect();

  /// Disconnect from the MQTT broker.
  ///
  /// [suppressLWT] - If true, suppresses Last Will and Testament message.
  /// Defaults to true for graceful disconnections.
  Future<void> disconnect({bool suppressLWT = true});

  /// Publish a message to the specified topic.
  ///
  /// [topic] - MQTT topic to publish to
  /// [payload] - Message payload as string
  /// [forceQoS1] - Forces QoS level 1 (default: true)
  /// [forceRetainFalse] - Forces retain flag to false (default: true)
  ///
  /// Messages are queued during disconnection and flushed upon reconnection.
  Future<void> publish(
    String topic,
    String payload, {
    bool forceQoS1 = true,
    bool forceRetainFalse = true,
    bool? retain,
  });

  /// Subscribe to a topic with message handler.
  ///
  /// [topic] - MQTT topic to subscribe to
  /// [handler] - Callback function (topic, payload) => void
  ///
  /// Logs warning if broker downgrades subscription to QoS 0.
  Future<void> subscribe(String topic, void Function(String, String) handler);

  /// Unsubscribe from a topic.
  ///
  /// [topic] - MQTT topic to unsubscribe from
  Future<void> unsubscribe(String topic);
}
