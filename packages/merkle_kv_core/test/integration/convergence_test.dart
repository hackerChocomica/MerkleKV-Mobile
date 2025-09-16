import 'dart:async';
import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

import 'test_config.dart';

void main() {
  group('Basic Convergence Tests', () {
    
    test('Storage entries can be compared for convergence', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'convergence-test-client',
        nodeId: 'convergence-test-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      
      final testKey = 'convergence-key';
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create two entries with different timestamps
      final entry1 = StorageEntry.value(
        key: testKey,
        value: 'value-1',
        timestampMs: baseTimestamp,
        nodeId: 'node-1',
        seq: 1,
      );
      
      final entry2 = StorageEntry.value(
        key: testKey,
        value: 'value-2',
        timestampMs: baseTimestamp + 1000, // Newer
        nodeId: 'node-2',
        seq: 1,
      );
      
      // Put first entry
      await storage.put(testKey, entry1);
      var result = await storage.get(testKey);
      expect(result!.value, equals('value-1'));
      
      // Put newer entry - should overwrite
      await storage.put(testKey, entry2);
      result = await storage.get(testKey);
      expect(result!.value, equals('value-2'));
      
      // Trying to put older entry should be ignored
      await storage.put(testKey, entry1);
      result = await storage.get(testKey);
      expect(result!.value, equals('value-2')); // Should still be newer value
    });

    test('Multiple storage instances handle same operations', () async {
      final config1 = TestConfigurations.mosquittoBasic(
        clientId: 'conv-client-1',
        nodeId: 'conv-node-1',
      );
      
      final config2 = TestConfigurations.mosquittoBasic(
        clientId: 'conv-client-2',
        nodeId: 'conv-node-2',
      );
      
      final storage1 = InMemoryStorage(config1);
      final storage2 = InMemoryStorage(config2);
      
      await storage1.initialize();
      await storage2.initialize();
      
      final testKey = 'shared-key';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Both nodes create entries for the same key
      final entry1 = StorageEntry.value(
        key: testKey,
        value: 'from-node-1',
        timestampMs: timestamp,
        nodeId: config1.nodeId,
        seq: 1,
      );
      
      final entry2 = StorageEntry.value(
        key: testKey,
        value: 'from-node-2',
        timestampMs: timestamp + 500, // Slightly newer
        nodeId: config2.nodeId,
        seq: 1,
      );
      
      // Apply same sequence to both storages
      await storage1.put(testKey, entry1);
      await storage2.put(testKey, entry1);
      
      await storage1.put(testKey, entry2);
      await storage2.put(testKey, entry2);
      
      // Both should have the newer value
      final result1 = await storage1.get(testKey);
      final result2 = await storage2.get(testKey);
      
      expect(result1!.value, equals('from-node-2'));
      expect(result2!.value, equals('from-node-2'));
      expect(result1.timestampMs, equals(result2.timestampMs));
    });

    test('Tombstone convergence behavior', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'tombstone-client',
        nodeId: 'tombstone-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      
      final testKey = 'tombstone-key';
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create and store a value
      final valueEntry = StorageEntry.value(
        key: testKey,
        value: 'test-value',
        timestampMs: baseTimestamp,
        nodeId: config.nodeId,
        seq: 1,
      );
      
      await storage.put(testKey, valueEntry);
      var result = await storage.get(testKey);
      expect(result!.value, equals('test-value'));
      
      // Create tombstone
      final tombstoneEntry = StorageEntry.tombstone(
        key: testKey,
        timestampMs: baseTimestamp + 1000,
        nodeId: config.nodeId,
        seq: 2,
      );
      
      await storage.put(testKey, tombstoneEntry);
      result = await storage.get(testKey);
      expect(result, isNull); // Tombstone should make get return null
      
      // Trying to put older value entry should be ignored
      await storage.put(testKey, valueEntry);
      result = await storage.get(testKey);
      expect(result, isNull); // Should still be tombstone
    });

    test('Command processor maintains consistency', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'consistency-client',
        nodeId: 'consistency-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      final testKey = 'consistency-key';
      
      // Sequence of operations
      var response = await processor.set(testKey, 'value-1', 'cmd-1');
      expect(response.status, equals(ResponseStatus.ok));
      
      response = await processor.get(testKey, 'cmd-2');
      expect(response.status, equals(ResponseStatus.ok));
      expect(response.value, equals('value-1'));
      
      response = await processor.set(testKey, 'value-2', 'cmd-3');
      expect(response.status, equals(ResponseStatus.ok));
      
      response = await processor.get(testKey, 'cmd-4');
      expect(response.status, equals(ResponseStatus.ok));
      expect(response.value, equals('value-2'));
      
      response = await processor.delete(testKey, 'cmd-5');
      expect(response.status, equals(ResponseStatus.ok));
      
      response = await processor.get(testKey, 'cmd-6');
      expect(response.status, equals(ResponseStatus.error));
    });

    test('Concurrent operations maintain ordering', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'concurrent-client',
        nodeId: 'concurrent-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      // Execute multiple operations concurrently
      final futures = <Future<Response>>[];
      
      // Set multiple keys
      for (int i = 0; i < 20; i++) {
        futures.add(processor.set('key-$i', 'value-$i', 'set-cmd-$i'));
      }
      
      final setResponses = await Future.wait(futures);
      
      // All SET operations should succeed
      for (final response in setResponses) {
        expect(response.status, equals(ResponseStatus.ok));
      }
      
      // Now get all values
      futures.clear();
      for (int i = 0; i < 20; i++) {
        futures.add(processor.get('key-$i', 'get-cmd-$i'));
      }
      
      final getResponses = await Future.wait(futures);
      
      // All GET operations should succeed and return correct values
      for (int i = 0; i < getResponses.length; i++) {
        expect(getResponses[i].status, equals(ResponseStatus.ok));
        expect(getResponses[i].value, equals('value-$i'));
      }
    });

    test('Anti-entropy basic concept validation', () async {
      // This test validates the basic concepts needed for anti-entropy
      // without implementing the full protocol
      
      final config1 = TestConfigurations.mosquittoBasic(
        clientId: 'anti-entropy-1',
        nodeId: 'anti-entropy-node-1',
      );
      
      final config2 = TestConfigurations.mosquittoBasic(
        clientId: 'anti-entropy-2',
        nodeId: 'anti-entropy-node-2',
      );
      
      final storage1 = InMemoryStorage(config1);
      final storage2 = InMemoryStorage(config2);
      
      await storage1.initialize();
      await storage2.initialize();
      
      final testKey = 'anti-entropy-key';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Node 1 gets a value first
      final entry1 = StorageEntry.value(
        key: testKey,
        value: 'from-node-1',
        timestampMs: timestamp,
        nodeId: config1.nodeId,
        seq: 1,
      );
      
      // Node 2 gets a newer value
      final entry2 = StorageEntry.value(
        key: testKey,
        value: 'from-node-2',
        timestampMs: timestamp + 1000,
        nodeId: config2.nodeId,
        seq: 1,
      );
      
      // Simulate anti-entropy sync: node 1 applies entry from node 2
      await storage1.put(testKey, entry1);
      await storage1.put(testKey, entry2); // Newer entry should win
      
      // Simulate anti-entropy sync: node 2 applies entry from node 1
      await storage2.put(testKey, entry2);
      await storage2.put(testKey, entry1); // Older entry should be ignored
      
      // Both nodes should converge to the newer value
      final result1 = await storage1.get(testKey);
      final result2 = await storage2.get(testKey);
      
      expect(result1!.value, equals('from-node-2'));
      expect(result2!.value, equals('from-node-2'));
      expect(result1.timestampMs, equals(result2.timestampMs));
    });
  });
}