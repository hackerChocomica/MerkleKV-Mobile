# MQTT Security Configuration

This short guide shows how to configure TLS and authentication for the MerkleKV MQTT client using the new `MqttSecurityConfig`.

## Simple TLS with username/password

```dart
final config = MerkleKVConfig(
  mqttHost: 'broker.example.com',
  mqttPort: 8883,
  mqttUseTls: true,
  clientId: 'mobile-client-1',
  nodeId: 'node-1',
  username: '<from-keystore>',
  password: '<from-keystore>',
);
```

## Explicit TLS/auth via MqttSecurityConfig

```dart
final config = MerkleKVConfig(
  mqttHost: 'broker.example.com',
  mqttPort: 8883,
  clientId: 'mobile-client-1',
  nodeId: 'node-1',
  mqttSecurity: MqttSecurityConfig(
    enableTLS: true,
    minTLSVersion: TLSVersion.v1_2,
    enforceHostnameValidation: true,
    enforceSANValidation: true,
    validateCertificateChain: true,
    authMethod: AuthenticationMethod.usernamePassword,
    username: '<from-keystore>',
    password: '<from-keystore>',
    // Optionally trust a custom CA
    caCertPath: '/path/to/ca.crt',
    // Or use mutual TLS
    // authMethod: AuthenticationMethod.clientCertificate,
    // clientCertPath: '/path/to/client.crt',
    // clientKeyPath: '/path/to/client.key',
    // clientKeyPassword: '<from-keystore>',
  ),
);
```

Notes:
- Secrets are intentionally not serialized in JSON; supply them at runtime from secure storage.
- TLS 1.2+ is required; hostname and certificate chain are validated by default.
- Cipher suite pinning is platform-specific; see below.

## Platform-specific cipher suites (optional)

Dart's `SecurityContext` uses the platform TLS stack. Fine-grained cipher control is OS-dependent and may not be available uniformly from Dart. If you need strict cipher pinning, you can:
- Provide hardened broker-side policies (preferable)
- Add a thin platform hook to configure cipher suites (Android/iOS) before MQTT connection

Open an issue if you need a sample hook; we can provide a minimal plugin scaffold.
