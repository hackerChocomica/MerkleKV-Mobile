#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';

/// Simple MQTT broker connectivity test using basic networking
/// This validates the broker is running and accessible without using complex APIs
void main() async {
  print('🚀 Starting Simple MQTT Broker Connectivity Test');
  
  final mosquittoHost = 'localhost';
  final mosquittoPort = 1883;
  
  print('\n📡 Testing basic TCP connectivity to Mosquitto broker...');
  
  try {
    // Test 1: Basic TCP socket connection
    await _testTcpConnection(mosquittoHost, mosquittoPort);
    
    // Test 2: MQTT protocol handshake
    await _testMqttHandshake(mosquittoHost, mosquittoPort);
    
    print('\n✅ All connectivity tests passed!');
    print('🎉 MQTT broker is accessible and responding correctly');
    
  } catch (e, stackTrace) {
    print('\n❌ Connectivity test failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

/// Test basic TCP connection to the broker
Future<void> _testTcpConnection(String host, int port) async {
  print('  • Testing TCP connection to $host:$port...');
  
  try {
    final socket = await Socket.connect(host, port, timeout: Duration(seconds: 5));
    print('    ✅ TCP connection established');
    
    await socket.close();
    print('    ✅ TCP connection closed cleanly');
    
  } catch (e) {
    throw Exception('TCP connection failed: $e');
  }
}

/// Test basic MQTT protocol handshake
Future<void> _testMqttHandshake(String host, int port) async {
  print('  • Testing MQTT protocol handshake...');
  
  try {
    final socket = await Socket.connect(host, port, timeout: Duration(seconds: 5));
    
    // Send MQTT CONNECT packet
    final connectPacket = _buildMqttConnectPacket('integration-test-client');
    socket.add(connectPacket);
    
    print('    ✅ MQTT CONNECT packet sent');
    
    // Wait for CONNACK
    final response = await socket.first.timeout(Duration(seconds: 5));
    
    if (response.isEmpty) {
      throw Exception('No CONNACK response received');
    }
    
    // Basic CONNACK validation (should start with 0x20 for CONNACK packet type)
    if (response[0] != 0x20) {
      throw Exception('Invalid CONNACK packet type: ${response[0].toRadixString(16)}');
    }
    
    // Check connection accepted (return code 0x00)
    if (response.length >= 4 && response[3] != 0x00) {
      throw Exception('Connection rejected by broker, return code: ${response[3]}');
    }
    
    print('    ✅ MQTT CONNACK received - connection accepted');
    
    await socket.close();
    
  } catch (e) {
    throw Exception('MQTT handshake failed: $e');
  }
}

/// Build a minimal MQTT CONNECT packet
List<int> _buildMqttConnectPacket(String clientId) {
  final List<int> packet = [];
  
  // Fixed header
  packet.add(0x10); // CONNECT packet type
  
  // Variable header and payload
  final variableHeader = <int>[
    // Protocol name "MQTT"
    0x00, 0x04, // length
    0x4D, 0x51, 0x54, 0x54, // "MQTT"
    
    // Protocol level (4 for MQTT 3.1.1)
    0x04,
    
    // Connect flags (clean session = 1)
    0x02,
    
    // Keep alive (60 seconds)
    0x00, 0x3C,
  ];
  
  // Payload (client ID)
  final clientIdBytes = clientId.codeUnits;
  final payload = <int>[
    (clientIdBytes.length >> 8) & 0xFF, // length high byte
    clientIdBytes.length & 0xFF,        // length low byte
    ...clientIdBytes,                   // client ID
  ];
  
  // Calculate remaining length
  final remainingLength = variableHeader.length + payload.length;
  packet.add(remainingLength);
  
  // Add variable header and payload
  packet.addAll(variableHeader);
  packet.addAll(payload);
  
  return packet;
}