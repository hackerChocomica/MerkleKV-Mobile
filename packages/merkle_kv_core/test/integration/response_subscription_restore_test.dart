import 'dart:async';
import 'package:test/test.dart';
import 'package:merkle_kv_core/merkle_kv_core.dart';
import '../utils/test_broker_helper.dart';
import 'test_config.dart';

void main() {
  group('Response subscription restoration (controller)', () {
    late MerkleKVConfig controllerCfg;
    late MerkleKVConfig deviceCfg;
    late MqttClientImpl controllerClient;
    late MqttClientImpl deviceClient;
    late TopicRouterImpl controllerRouter;
    late TopicRouterImpl deviceRouter;

    setUpAll(() async {
      await TestBrokerHelper.ensureBroker(port: IntegrationTestConfig.mosquittoPort);
      controllerCfg = TestConfigurations.mosquittoBasic(
        clientId: 'ctrl-restore',
        nodeId: 'node-ctrl-restore',
      ).copyWith(isController: true, topicPrefix: 'merkle_kv');
      deviceCfg = TestConfigurations.mosquittoBasic(
        clientId: 'dev-restore',
        nodeId: 'node-dev-restore',
      ).copyWith(topicPrefix: 'merkle_kv');
      controllerClient = MqttClientImpl(controllerCfg);
      deviceClient = MqttClientImpl(deviceCfg);
      await controllerClient.connect();
      await deviceClient.connect();
      controllerRouter = TopicRouterImpl(controllerCfg, controllerClient);
      deviceRouter = TopicRouterImpl(deviceCfg, deviceClient);
    });

    tearDownAll(() async {
      await controllerRouter.dispose();
      await deviceRouter.dispose();
      await controllerClient.disconnect();
      await deviceClient.disconnect();
    });

    test('controller receives device responses after reconnect', () async {
      final responses = <String>[];

      await controllerRouter.subscribeToResponsesOf('dev-restore', (topic, payload) {
        responses.add(payload);
      });

      await deviceRouter.publishResponse('r1');
      await Future.delayed(const Duration(milliseconds: 300));
      expect(responses, contains('r1'));

      await controllerClient.disconnect();
      await Future.delayed(const Duration(milliseconds: 200));
      await controllerClient.connect();
      // Deterministically wait for router to finish restoring subscriptions
      await controllerRouter.waitForRestore(timeout: const Duration(seconds: 2));

      await deviceRouter.publishResponse('r2');
      // Small delay to allow message propagation after ensured restore
      await Future.delayed(const Duration(milliseconds: 250));
      expect(responses, containsAll(['r1', 'r2']));
    });
  });
}