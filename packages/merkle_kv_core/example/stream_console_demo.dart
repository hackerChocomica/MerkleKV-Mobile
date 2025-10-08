import 'dart:async';

import 'package:merkle_kv_core/src/mqtt/connection_logger.dart';
import 'package:merkle_kv_core/src/mqtt/log_entry.dart';

void main() async {
  final logger = StreamConnectionLogger(
    tag: 'Aero-MQTT',
    enableDebug: true,
    mirrorToConsole: true,
    bufferSize: 200,
  );

  // App devs can subscribe this stream to render a console-like widget
  final sub = logger.stream.listen((ConnectionLogEntry e) {
    // Render in UI (here we just print the JSON for demo)
    // ignore: avoid_print
    print('JSON => ${e.toJson()}');
  });

  // Blast some spicy logs
  logger.debug('Bootstrapping MQTT client...');
  logger.info('Connecting to broker tcp://broker.emqx.io:1883');
  logger.warn('QoS=0 publish detected from external client; enforcing QoS=1');
  logger.error('Handshake failed; retry in 2s', Exception('timeout'));

  // Simulate async lifecycle events
  await Future.delayed(const Duration(milliseconds: 200));
  logger.info('Reconnecting with exponential backoff (attempt #2)');
  await Future.delayed(const Duration(milliseconds: 100));
  logger.debug('SUBACK received for topic aero/+/res');
  await Future.delayed(const Duration(milliseconds: 100));
  logger.info('Connected ✅');

  // Demonstrate buffer snapshot for late subscribers
  final snapshot = logger.bufferSnapshot;
  // ignore: avoid_print
  print('Buffered entries: ${snapshot.length}');

  await sub.cancel();
  await logger.dispose();
}
