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

/// Test basic MQTT protocol handshake using simplified approach
Future<void> _testMqttHandshake(String host, int port) async {
  print('  • Testing MQTT protocol handshake...');
  
  try {
    final socket = await Socket.connect(host, port, timeout: Duration(seconds: 5));
    
    // Send a simple MQTT CONNECT packet (minimal valid packet)
    // This is a simplified test that just verifies the broker responds
    final connectPacket = _buildMinimalMqttConnect();
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

/// Build a minimal MQTT CONNECT packet for basic connectivity testing
/// Note: This is a simplified implementation for test purposes only.
/// In production code, use a proper MQTT client library instead.
List<int> _buildMinimalMqttConnect() {
  // Pre-built minimal MQTT CONNECT packet for client ID "test"
  // This avoids manual protocol construction while maintaining test functionality
  return [
    0x10, 0x16,           // Fixed header: CONNECT packet, length 22
    0x00, 0x04,           // Protocol name length
    0x4D, 0x51, 0x54, 0x54, // "MQTT"
    0x04,                 // Protocol level (MQTT 3.1.1)
    0x02,                 // Connect flags (clean session)
    0x00, 0x3C,           // Keep alive (60 seconds)
    0x00, 0x04,           // Client ID length
    0x74, 0x65, 0x73, 0x74 // Client ID "test"
  ];
}