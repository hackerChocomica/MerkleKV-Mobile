import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import '../utils/test_broker_helper.dart';

/// Simple MQTT broker connectivity test using basic networking.
/// Tests only TCP connectivity without complex MQTT protocol handshake.
void main() {
  group('Simple MQTT Broker Tests', () {
    setUpAll(() async {
      // Ensure a broker is available for these connectivity tests; if a real
      // broker is present, this is a no-op.
      await TestBrokerHelper.ensureBroker(port: 1883);
    });
    test('TCP connectivity to Mosquitto broker', () async {
      final mosquittoHost = 'localhost';
      final mosquittoPort = 1883;

      // Test basic TCP socket connection
      await _testTcpConnection(mosquittoHost, mosquittoPort);
    });

    test('Socket communication with broker', () async {
      final mosquittoHost = 'localhost';
      final mosquittoPort = 1883;

      try {
        final socket = await Socket.connect(mosquittoHost, mosquittoPort,
            timeout: Duration(seconds: 5));

        // Test that we can write some data
        socket.add([0x10, 0x02]); // Minimal test packet
        await socket.flush();

        // Give broker a moment to respond or close connection
        await Future.delayed(Duration(milliseconds: 100));

        await socket.close();

        // Test passes if no exception thrown
        expect(true, isTrue, reason: 'Socket communication should work');
      } catch (e) {
        throw Exception('Socket communication failed: $e');
      }
    });

    test('Multiple connections to broker', () async {
      final mosquittoHost = 'localhost';
      final mosquittoPort = 1883;

      // Test that broker can handle multiple connections
      final sockets = <Socket>[];

      try {
        for (int i = 0; i < 3; i++) {
          final socket = await Socket.connect(mosquittoHost, mosquittoPort,
              timeout: Duration(seconds: 5));
          sockets.add(socket);
        }

        // All connections established successfully
        expect(sockets.length, equals(3));
      } finally {
        // Clean up all connections
        for (final socket in sockets) {
          try {
            await socket.close();
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }
    });
  });
}

/// Test basic TCP connection to the broker
Future<void> _testTcpConnection(String host, int port) async {
  try {
    final socket =
        await Socket.connect(host, port, timeout: Duration(seconds: 5));
    await socket.close();

    // Test passes if connection succeeds
    expect(true, isTrue, reason: 'TCP connection should succeed');
  } catch (e) {
    throw Exception('TCP connection failed: $e');
  }
}
