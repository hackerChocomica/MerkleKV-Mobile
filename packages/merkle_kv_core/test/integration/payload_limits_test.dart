import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';

import 'test_config.dart';

void main() {
  group('Basic Payload Limits Tests', () {
    
    test('Storage handles normal-sized keys and values', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'payload-client-basic',
        nodeId: 'payload-node-basic',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      // Test normal-sized key and value (well within limits)
      const normalKey = 'normal-test-key';
      const normalValue = 'normal test value that is reasonably sized';
      
      final setResponse = await processor.set(normalKey, normalValue, 'cmd-1');
      expect(setResponse.status, equals(ResponseStatus.ok));
      
      final getResponse = await processor.get(normalKey, 'cmd-2');
      expect(getResponse.status, equals(ResponseStatus.ok));
      expect(getResponse.value, equals(normalValue));
    });

    test('Storage handles maximum allowed key size', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'payload-max-key-client',
        nodeId: 'payload-max-key-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      // Create a key that's exactly at the limit (256 bytes UTF-8)
      final maxSizeKey = 'k' * 255; // 255 ASCII chars = 255 bytes
      const value = 'test-value';
      
      final setResponse = await processor.set(maxSizeKey, value, 'cmd-1');
      expect(setResponse.status, equals(ResponseStatus.ok));
      
      final getResponse = await processor.get(maxSizeKey, 'cmd-2');
      expect(getResponse.status, equals(ResponseStatus.ok));
      expect(getResponse.value, equals(value));
    });

    test('Storage handles large values within limits', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'payload-large-value-client',
        nodeId: 'payload-large-value-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      const key = 'large-value-key';
      // Create a large value (but well within 256KiB limit)
      final largeValue = 'x' * 10000; // 10KB
      
      final setResponse = await processor.set(key, largeValue, 'cmd-1');
      expect(setResponse.status, equals(ResponseStatus.ok));
      
      final getResponse = await processor.get(key, 'cmd-2');
      expect(getResponse.status, equals(ResponseStatus.ok));
      expect(getResponse.value, equals(largeValue));
    });

    test('Command creation handles various payload sizes', () async {
      // Test normal command
      final normalCommand = Command.set(
        id: 'normal-cmd',
        key: 'normal-key',
        value: 'normal value',
      );
      
      expect(normalCommand.toJsonString().length, lessThan(1000));
      
      // Test command with larger payload
      final largerCommand = Command.set(
        id: 'larger-cmd', 
        key: 'larger-key',
        value: 'x' * 1000, // 1KB value
      );
      
      final jsonString = largerCommand.toJsonString();
      expect(jsonString.length, greaterThan(1000));
      expect(jsonString.length, lessThan(10000)); // Still reasonable
      
      // Verify it can be parsed back
      final parsedCommand = Command.fromJsonString(jsonString);
      expect(parsedCommand.key, equals(largerCommand.key));
      expect(parsedCommand.value, equals(largerCommand.value));
    });

    test('Response creation handles various payload sizes', () async {
      // Test normal response
      final normalResponse = Response.ok(
        id: 'normal-resp',
        value: 'normal response value',
      );
      
      expect(normalResponse.toJsonString().length, lessThan(500));
      
      // Test response with larger value
      final largerResponse = Response.ok(
        id: 'larger-resp',
        value: 'y' * 1000, // 1KB response value
      );
      
      final jsonString = largerResponse.toJsonString();
      expect(jsonString.length, greaterThan(1000));
      
      // Verify it can be parsed back
      final parsedResponse = Response.fromJsonString(jsonString);
      expect(parsedResponse.value, equals(largerResponse.value));
      expect(parsedResponse.id, equals(largerResponse.id));
    });

    test('Bulk operations handle multiple items', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'payload-bulk-client',
        nodeId: 'payload-bulk-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      // Test multiple SET/GET operations
      for (int i = 0; i < 50; i++) {
        final setResponse = await processor.set('bulk-key-$i', 'bulk-value-$i', 'bulk-cmd-$i');
        expect(setResponse.status, equals(ResponseStatus.ok));
      }
      
      // Verify all values were stored
      for (int i = 0; i < 50; i++) {
        final getResponse = await processor.get('bulk-key-$i', 'bulk-get-$i');
        expect(getResponse.status, equals(ResponseStatus.ok));
        expect(getResponse.value, equals('bulk-value-$i'));
      }
    });

    test('UTF-8 encoding is handled correctly', () async {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'payload-utf8-client',
        nodeId: 'payload-utf8-node',
      );
      
      final storage = InMemoryStorage(config);
      await storage.initialize();
      final processor = CommandProcessorImpl(config, storage);
      
      // Test UTF-8 characters in key and value
      const utf8Key = 'test-ключ-键-🔑';
      const utf8Value = 'test-значение-值-💎 with emoji and unicode';
      
      final setResponse = await processor.set(utf8Key, utf8Value, 'utf8-cmd');
      expect(setResponse.status, equals(ResponseStatus.ok));
      
      final getResponse = await processor.get(utf8Key, 'utf8-get');
      expect(getResponse.status, equals(ResponseStatus.ok));
      expect(getResponse.value, equals(utf8Value));
    });
  });
}