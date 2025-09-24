import 'package:test/test.dart';
import 'package:merkle_kv_core/src/config/mqtt_security_config.dart';
import 'package:merkle_kv_core/src/mqtt/mqtt_client_impl.dart' show MqttClientImpl;

void main() {
  group('MqttSecurityConfig', () {
    test('JSON round-trip masks secrets and restores via params', () {
      final sec = MqttSecurityConfig(
        enableTLS: true,
        minTLSVersion: TLSVersion.v1_2,
        enforceHostnameValidation: true,
        enforceSANValidation: true,
        caCertPath: '/path/ca.pem',
        authMethod: AuthenticationMethod.clientCertificate,
        username: 'user',
        password: 'pass',
        clientCertPath: '/path/client.crt',
        clientKeyPath: '/path/client.key',
        clientKeyPassword: 'kpass',
        validateCertificateChain: true,
      );

      final json = sec.toJson();
      expect(json['password'], '***');
      expect(json['clientKeyPassword'], '***');
      expect(json['minTLSVersion'], 'v1_2');
      expect(json['authMethod'], 'clientCertificate');

      final decoded = MqttSecurityConfig.fromJson(
        json,
        username: 'user',
        password: 'pass',
        clientKeyPassword: 'kpass',
      );
      expect(decoded.enableTLS, isTrue);
      expect(decoded.minTLSVersion, TLSVersion.v1_2);
      expect(decoded.enforceHostnameValidation, isTrue);
      expect(decoded.enforceSANValidation, isTrue);
      expect(decoded.caCertPath, '/path/ca.pem');
      expect(decoded.authMethod, AuthenticationMethod.clientCertificate);
      expect(decoded.username, 'user');
      expect(decoded.password, 'pass');
      expect(decoded.clientCertPath, '/path/client.crt');
      expect(decoded.clientKeyPath, '/path/client.key');
      expect(decoded.clientKeyPassword, 'kpass');
      expect(decoded.validateCertificateChain, isTrue);
    });
  });

  group('TLS error classification', () {
    test('classifies common TLS failures into stable messages', () {
      expect(MqttClientImpl.classifyTlsError('CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate'),
          'certificate chain validation failed');
      expect(MqttClientImpl.classifyTlsError('wrong version number'), 'TLS version too old');
      expect(MqttClientImpl.classifyTlsError('certificate expired at 2023-01-01'), 'certificate expired');
      expect(MqttClientImpl.classifyTlsError('certificate verify failed: Hostname mismatch'),
          'hostname validation failed');
      expect(MqttClientImpl.classifyTlsError('Subject Alternative Name missing or invalid'),
          'SAN validation failed');
    });
  });
}
