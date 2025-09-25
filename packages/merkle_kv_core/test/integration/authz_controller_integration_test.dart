import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import 'package:merkle_kv_core/src/commands/error_classifier.dart';
import 'test_config.dart';
import '../utils/test_broker_helper.dart';

void main() {
  group('Authorization Integration (Controller)', () {
    setUpAll(() async {
      await TestBrokerHelper.ensureBroker(port: IntegrationTestConfig.mosquittoPort);
    });

    test('controller can publish cross-client command and export metrics', () async {
      final controllerCfg = TestConfigurations.mosquittoBasic(
        clientId: 'controller-int',
        nodeId: 'node-controller',
      ).copyWith(isController: true, topicPrefix: 'merkle_kv');

      final deviceCfg = TestConfigurations.mosquittoBasic(
        clientId: 'device-int',
        nodeId: 'node-device',
      ).copyWith(topicPrefix: 'merkle_kv');

      final controllerClient = MqttClientImpl(controllerCfg);
      final deviceClient = MqttClientImpl(deviceCfg);

      await controllerClient.connect();
      await deviceClient.connect();

      final controllerRouter = TopicRouterImpl(controllerCfg, controllerClient);
      final deviceRouter = TopicRouterImpl(deviceCfg, deviceClient);

      // Device attempts cross-client (should fail)
      expect(
        () => deviceRouter.publishCommand('controller-int', 'ping'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 300)),
      );

      // Controller publishes to device (allowed)
      await controllerRouter.publishCommand('device-int', 'ping');
      expect(controllerRouter.authzMetrics.commandAllowed, 1);

      // Controller exports metrics
      await controllerRouter.publishAuthzMetrics();

      await controllerRouter.dispose();
      await deviceRouter.dispose();
      await controllerClient.disconnect();
      await deviceClient.disconnect();
    });
  });
}