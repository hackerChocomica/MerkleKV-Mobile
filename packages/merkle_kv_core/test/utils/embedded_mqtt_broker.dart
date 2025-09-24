import 'dart:async';
import 'dart:io';

/// A minimal embedded MQTT v3.1.1 broker for tests.
///
/// Supports just enough of the protocol to let clients connect, subscribe,
/// publish QoS 1, ping, and disconnect. Intended only for local integration
/// tests when a real broker isn’t available.
class EmbeddedMqttBroker {
  final InternetAddress host;
  final int port;

  ServerSocket? _server;
  final Set<Socket> _clients = {};
  bool _running = false;

  EmbeddedMqttBroker({InternetAddress? host, this.port = 1883})
      : host = host ?? InternetAddress.loopbackIPv4;

  bool get isRunning => _running;

  /// Start the broker if nothing is listening on [port]. Returns true if
  /// this instance started a server, false if another broker is already there.
  static Future<(bool started, EmbeddedMqttBroker? broker)> startIfNeeded({
    int port = 1883,
  }) async {
    // Quick probe: try to connect; if success, someone is already listening.
    try {
      final probe = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(milliseconds: 300));
      await probe.close();
      return (false, null);
    } catch (_) {
      // Nothing listening, go ahead and start our embedded broker.
    }

    final broker = EmbeddedMqttBroker(port: port);
    await broker.start();
    return (true, broker);
  }

  Future<void> start() async {
    if (_running) return;
    _server = await ServerSocket.bind(host, port, shared: true);
    _running = true;
    _server!.listen(_handleClient, onError: (_) {}, cancelOnError: true);
  }

  Future<void> stop() async {
    _running = false;
    for (final c in _clients.toList()) {
      try {
        await c.close();
      } catch (_) {}
    }
    _clients.clear();
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
  }

  void _handleClient(Socket socket) {
    _clients.add(socket);
    final buffer = <int>[];

    void onData(List<int> data) {
      buffer.addAll(data);
      // Process as many MQTT control packets as we can from the buffer.
      while (buffer.isNotEmpty) {
        final ok = _processOne(socket, buffer);
        if (!ok) break; // Need more data
      }
    }

    socket.listen(onData, onDone: () => _clients.remove(socket), onError: (_) {
      _clients.remove(socket);
    });
  }

  // Returns true if a full packet was processed; false if need more data.
  bool _processOne(Socket socket, List<int> buf) {
    if (buf.isEmpty) return false;
    final type = buf[0] & 0xF0;
    // Decode Remaining Length (MQTT varint) starting at index 1.
    final rlDec = _decodeRemainingLength(buf, 1);
    if (rlDec == null) return false; // need more bytes
    final (remainingLen, rlBytes) = rlDec;
    final headerLen = 1 + rlBytes;
    final totalLen = headerLen + remainingLen;
    if (buf.length < totalLen) return false; // wait for full packet

    final packet = buf.sublist(0, totalLen);
    // Remove from buffer
    buf.removeRange(0, totalLen);

    switch (type) {
      case 0x10: // CONNECT
        _sendConnAck(socket);
        break;
      case 0xC0: // PINGREQ
        _sendPingResp(socket);
        break;
      case 0xE0: // DISCONNECT
        // Client indicates it will close. Do not close the socket from within
        // the read callback to avoid "StreamSink is bound to a stream" errors.
        // The client will close; we'll observe onDone and remove it there.
        break;
      case 0x82: // SUBSCRIBE
        _handleSubscribe(socket, packet);
        break;
      case 0x30: // PUBLISH QoS 0
      case 0x31: // PUBLISH QoS 0 (flags vary)
      case 0x32: // PUBLISH QoS 1
      case 0x33: // PUBLISH QoS 1 (dup)
      case 0x34: // PUBLISH QoS 2
      case 0x35:
      case 0x36:
      case 0x37:
        _handlePublish(socket, packet);
        break;
      default:
        // Ignore unsupported packet types in this stub
        break;
    }

    return true;
  }

  void _sendConnAck(Socket socket) {
    // CONNACK: type=0x20, remaining length=0x02, flags=0x00 (session present), rc=0x00 (accepted)
    _safeSend(socket, const [0x20, 0x02, 0x00, 0x00]);
    _safeFlush(socket);
  }

  void _sendPingResp(Socket socket) {
    _safeSend(socket, const [0xD0, 0x00]);
    _safeFlush(socket);
  }

  void _handleSubscribe(Socket socket, List<int> packet) {
    // SUBSCRIBE variable header: Packet Identifier MSB, LSB after fixed header.
    // We need to compute header length like before.
    final rlDec = _decodeRemainingLength(packet, 1)!;
    final headerLen = 1 + rlDec.$2;
    final pidMsb = packet[headerLen];
    final pidLsb = packet[headerLen + 1];
    // Respond with SUBACK granting QoS 1 for all topics (simplified to 1 topic)
    final suback = [0x90, 0x03, pidMsb, pidLsb, 0x01];
    _safeSend(socket, suback);
    _safeFlush(socket);
  }

  void _handlePublish(Socket socket, List<int> packet) {
    // Determine QoS from header low bits
    final header = packet[0];
    final qos = (header & 0x06) >> 1; // 0,1,2
    if (qos == 1) {
      // Extract Packet Identifier after topic name in variable header.
      final rlDec = _decodeRemainingLength(packet, 1)!;
      final headerLen = 1 + rlDec.$2;
      // Topic Name starts at headerLen: two bytes length
      final topicLen = (packet[headerLen] << 8) | packet[headerLen + 1];
      final pidIndex = headerLen + 2 + topicLen;
      if (pidIndex + 1 < packet.length) {
        final pidMsb = packet[pidIndex];
        final pidLsb = packet[pidIndex + 1];
        final puback = [0x40, 0x02, pidMsb, pidLsb];
        _safeSend(socket, puback);
        _safeFlush(socket);
      }
    }
    // QoS 0: no response; QoS 2: not supported in stub
  }

  void _safeSend(Socket socket, List<int> data) {
    try {
      socket.add(data);
    } catch (_) {
      // Ignore write errors from clients that are closing or have piped streams.
    }
  }

  void _safeFlush(Socket socket) {
    try {
      // Best-effort flush; ignore errors if socket is in an invalid state.
      // flush() returns a Future, but we don't need to await it here.
      socket.flush();
    } catch (_) {}
  }

  // Decode MQTT Remaining Length field starting at [start].
  // Returns (value, bytesConsumed) or null if insufficient bytes.
  (int, int)? _decodeRemainingLength(List<int> data, int start) {
    int multiplier = 1;
    int value = 0;
    int bytes = 0;
    for (int i = start; i < data.length && bytes < 4; i++) {
      bytes++;
      final encodedByte = data[i];
      value += (encodedByte & 127) * multiplier;
      if ((encodedByte & 128) == 0) {
        return (value, bytes);
      }
      multiplier *= 128;
    }
    return null; // need more bytes
  }
}
