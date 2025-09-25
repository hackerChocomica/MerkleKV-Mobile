import 'dart:io';
import 'embedded_mqtt_broker.dart';
import 'dart:async';
import 'dart:convert';

/// Environment flags influencing broker startup logic:
///   IT_REQUIRE_BROKER=1        -> Fail if no real broker reachable; never start embedded
///   IT_DOCKER_START=1          -> Attempt to start docker-compose.basic.yml mosquitto-test
///   MKV_PROJECT_ROOT=<path>    -> Explicit repo root (else we infer ../../.. relative path)
///   IT_BROKER_START_TIMEOUT    -> Seconds to wait for external/docker broker (default 25)
///   IT_BROKER_PORT             -> Override port (default 1883)
///
/// Startup precedence:
///   1. If something already listening on port -> return
///   2. If IT_DOCKER_START=1 -> run scripts/start_test_broker.sh (idempotent) + wait
///   3. If still not listening:
///        a. If IT_REQUIRE_BROKER=1 -> throw
///        b. Else start embedded broker stub

/// Ensures an MQTT broker is available for integration tests.
/// If no broker is listening on localhost:1883, starts an embedded broker.
class TestBrokerHelper {
  static EmbeddedMqttBroker? _broker;

  static Future<void> ensureBroker({int port = 1883}) async {
    // Allow override of port
    port = int.tryParse(Platform.environment['IT_BROKER_PORT'] ?? '') ?? port;

    if (await _isPortOpen(port)) {
      return; // Already available
    }

    final requireReal = Platform.environment['IT_REQUIRE_BROKER'] == '1';
    final attemptDocker = Platform.environment['IT_DOCKER_START'] == '1';
    final startTimeout = int.tryParse(
          Platform.environment['IT_BROKER_START_TIMEOUT'] ?? '',
        ) ??
        25;

    if (attemptDocker) {
      await _tryDockerStart(port: port, timeoutSeconds: startTimeout);
      if (await _isPortOpen(port)) {
        return; // Success via docker
      }
    }

    if (requireReal) {
      throw StateError(
        'IT_REQUIRE_BROKER=1 set but no broker reachable on port $port after attempts.',
      );
    }

    // Fallback: embedded stub broker
    final (started, broker) = await EmbeddedMqttBroker.startIfNeeded(port: port);
    if (started) _broker = broker;
  }

  static Future<void> stopBroker() async {
    await _broker?.stop();
    _broker = null;
  }

  // --- internals ---

  static Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(milliseconds: 300));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _tryDockerStart({
    required int port,
    required int timeoutSeconds,
  }) async {
    try {
      final projectRoot = Platform.environment['MKV_PROJECT_ROOT'] ??
          // We run tests from packages/merkle_kv_core, scripts at ../../scripts/
          Directory.current.path + '/../..';
      final script = File('$projectRoot/scripts/start_test_broker.sh');
      if (!await script.exists()) {
        return; // Silently ignore if script not present
      }
      final proc = await Process.start(
        script.path,
        const [],
        mode: ProcessStartMode.detachedWithStdio,
        environment: {
          ...Platform.environment,
          'BROKER_PORT': '$port',
          'COMPOSE_FILE': '$projectRoot/docker-compose.basic.yml',
          'SERVICE_NAME': 'mosquitto-test',
          'START_TIMEOUT': '$timeoutSeconds',
        },
        workingDirectory: projectRoot,
      );

      // Collect stdout/stderr non-blocking for debug (best effort)
      final out = StringBuffer();
      proc.stdout.transform(utf8.decoder).listen(out.write);
      proc.stderr.transform(utf8.decoder).listen(out.write);

      final exitCode = await proc.exitCode;
      if (exitCode != 0) {
        // Not fatal; we'll fallback / maybe embedded
      }
    } catch (_) {
      // Ignore docker start errors; fallback path will handle
    }
  }
}
