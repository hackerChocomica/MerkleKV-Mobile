/// Example demonstrating the MerkleKV public API surface.
///
/// This example shows all the key features of the MerkleKV Mobile API
/// including configuration, connection management, and operations.

import 'package:merkle_kv_core/merkle_kv.dart';

Future<void> main() async {
  print('=== MerkleKV Mobile API Example ===\n');

  // 1. Create configuration using the builder pattern
  print('1. Creating configuration...');
  final config = MerkleKVConfig.builder()
    .host('test.mosquitto.org')
    .clientId('example-mobile-client')
    .nodeId('example-node-123')
    .topicPrefix('merkle_kv_example')
    .mobileDefaults() // Apply mobile-optimized settings
    .build();

  print('   Configuration created successfully');
  print('   Host: ${config.mqttHost}');
  print('   Client ID: ${config.clientId}');
  print('   Node ID: ${config.nodeId}');
  print('   Topic Prefix: ${config.topicPrefix}');
  print('   Persistence: ${config.persistenceEnabled}');
  print('');

  // 2. Create MerkleKV instance
  print('2. Creating MerkleKV instance...');
  final merkleKV = await MerkleKV.create(config);
  print('   Instance created successfully');
  print('');

  try {
    // 3. Connect to MQTT broker
    print('3. Connecting to MQTT broker...');
    await merkleKV.connect();
    print('   Connected successfully');
    print('   Connection state: ${merkleKV.currentConnectionState}');
    print('');

    // 4. Set up connection state monitoring
    print('4. Setting up connection state monitoring...');
    merkleKV.connectionState.listen((state) {
      print('   Connection state changed: $state');
    });
    print('');

    // 5. Basic operations
    print('5. Performing basic operations...');
    
    // SET operation
    await merkleKV.set('user:123', 'John Doe');
    print('   SET user:123 = "John Doe"');
    
    // GET operation
    final value = await merkleKV.get('user:123');
    print('   GET user:123 = "$value"');
    
    // SET another key
    await merkleKV.set('user:456', 'Jane Smith');
    print('   SET user:456 = "Jane Smith"');
    print('');

    // 6. Numeric operations
    print('6. Performing numeric operations...');
    
    // Initialize a counter
    await merkleKV.set('counter', '0');
    print('   SET counter = "0"');
    
    // Increment operations
    var count = await merkleKV.increment('counter', 5);
    print('   INCREMENT counter by 5 = $count');
    
    count = await merkleKV.increment('counter', 3);
    print('   INCREMENT counter by 3 = $count');
    
    // Decrement operations
    count = await merkleKV.decrement('counter', 2);
    print('   DECREMENT counter by 2 = $count');
    print('');

    // 7. String operations
    print('7. Performing string operations...');
    
    // Initialize a text field
    await merkleKV.set('message', 'Hello');
    print('   SET message = "Hello"');
    
    // Append operation
    var length = await merkleKV.append('message', ' World');
    print('   APPEND " World" to message, new length = $length');
    
    // Check the result
    final message = await merkleKV.get('message');
    print('   GET message = "$message"');
    
    // Prepend operation
    length = await merkleKV.prepend('message', 'Greeting: ');
    print('   PREPEND "Greeting: " to message, new length = $length');
    
    // Check the result
    final finalMessage = await merkleKV.get('message');
    print('   GET message = "$finalMessage"');
    print('');

    // 8. Bulk operations
    print('8. Performing bulk operations...');
    
    // Bulk GET operation
    final keys = ['user:123', 'user:456', 'counter', 'message'];
    final values = await merkleKV.getMultiple(keys);
    print('   MGET ${keys.join(", ")}:');
    values.forEach((key, value) {
      print('     $key = ${value ?? "null"}');
    });
    
    // Bulk SET operation
    final keyValues = {
      'product:1': 'Laptop',
      'product:2': 'Mouse',
      'product:3': 'Keyboard',
    };
    final results = await merkleKV.setMultiple(keyValues);
    print('   MSET ${keyValues.keys.join(", ")}:');
    results.forEach((key, success) {
      print('     $key = ${success ? "OK" : "FAILED"}');
    });
    print('');

    // 9. DELETE operation (idempotent)
    print('9. Performing DELETE operations...');
    
    // Delete existing key
    await merkleKV.delete('user:123');
    print('   DELETE user:123 (existing key)');
    
    // Delete non-existing key (should still succeed)
    await merkleKV.delete('non:existent');
    print('   DELETE non:existent (non-existing key) - still succeeds');
    
    // Verify deletion
    final deletedValue = await merkleKV.get('user:123');
    print('   GET user:123 after deletion = ${deletedValue ?? "null"}');
    print('');

    // 10. Error handling demonstration
    print('10. Demonstrating error handling...');
    
    try {
      // Try to set a key that's too long
      final longKey = 'x' * 300; // Exceeds 256 byte limit
      await merkleKV.set(longKey, 'value');
    } on ValidationException catch (e) {
      print('   Caught ValidationException: ${e.message}');
    }
    
    try {
      // Try to set a value that's too large
      final largeValue = 'x' * (300 * 1024); // Exceeds 256 KiB limit
      await merkleKV.set('key', largeValue);
    } on ValidationException catch (e) {
      print('   Caught ValidationException: ${e.message}');
    }
    print('');

  } catch (e) {
    print('Error occurred: $e');
  } finally {
    // 11. Cleanup
    print('11. Cleaning up...');
    await merkleKV.disconnect();
    await merkleKV.dispose();
    print('   Disconnected and disposed successfully');
  }

  print('\n=== Example completed ===');
}