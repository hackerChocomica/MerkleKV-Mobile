import 'package:test/test.dart';
import 'test_config.dart';

void main() {
  group('Integration Test Environment Check', () {
    test('MQTT broker configuration is available', () {
      expect(IntegrationTestConfig.mosquittoHost, isNotEmpty);
      expect(IntegrationTestConfig.mosquittoPort, greaterThan(0));
    }, tags: ['integration']);

    test('Test configurations can be created', () {
      final config = TestConfigurations.mosquittoBasic(
        clientId: 'test-client',
        nodeId: 'test-node',
      );
      
      expect(config.mqttHost, equals('localhost'));
      expect(config.mqttPort, equals(1883));
    }, tags: ['integration']);
  });
}