/// TLS versions supported for MQTT connections.
enum TLSVersion { v1_2, v1_3 }

/// Authentication methods supported for MQTT.
enum AuthenticationMethod { usernamePassword, clientCertificate }

/// Security configuration for MQTT connections.
///
/// This is an optional, advisory configuration used to enable TLS and
/// configure credential sources. Enforcement depends on platform TLS
/// capabilities available via dart:io SecurityContext.
class MqttSecurityConfig {
  final bool enableTLS; // default: false
  final TLSVersion minTLSVersion; // minimum: TLS 1.2
  final bool enforceHostnameValidation; // default: true
  final bool enforceSANValidation; // default: true
  final String? caCertPath; // CA certificate file path (PEM)
  final AuthenticationMethod authMethod; // username/password or client cert

  // Username/password auth (sensitive; should come from secure storage)
  final String? username;
  final String? password;

  // Client certificate auth with full chain validation
  final String? clientCertPath; // PEM-encoded client certificate (chain)
  final String? clientKeyPath; // PEM-encoded private key
  final String? clientKeyPassword; // optional key password
  final bool validateCertificateChain; // default: true

  const MqttSecurityConfig({
    this.enableTLS = false,
    this.minTLSVersion = TLSVersion.v1_2,
    this.enforceHostnameValidation = true,
    this.enforceSANValidation = true,
    this.caCertPath,
    this.authMethod = AuthenticationMethod.usernamePassword,
    this.username,
    this.password,
    this.clientCertPath,
    this.clientKeyPath,
    this.clientKeyPassword,
    this.validateCertificateChain = true,
  });

  MqttSecurityConfig copyWith({
    bool? enableTLS,
    TLSVersion? minTLSVersion,
    bool? enforceHostnameValidation,
    bool? enforceSANValidation,
    String? caCertPath,
    AuthenticationMethod? authMethod,
    String? username,
    String? password,
    String? clientCertPath,
    String? clientKeyPath,
    String? clientKeyPassword,
    bool? validateCertificateChain,
  }) {
    return MqttSecurityConfig(
      enableTLS: enableTLS ?? this.enableTLS,
      minTLSVersion: minTLSVersion ?? this.minTLSVersion,
      enforceHostnameValidation:
          enforceHostnameValidation ?? this.enforceHostnameValidation,
      enforceSANValidation: enforceSANValidation ?? this.enforceSANValidation,
      caCertPath: caCertPath ?? this.caCertPath,
      authMethod: authMethod ?? this.authMethod,
      username: username ?? this.username,
      password: password ?? this.password,
      clientCertPath: clientCertPath ?? this.clientCertPath,
      clientKeyPath: clientKeyPath ?? this.clientKeyPath,
      clientKeyPassword: clientKeyPassword ?? this.clientKeyPassword,
      validateCertificateChain:
          validateCertificateChain ?? this.validateCertificateChain,
    );
  }

  Map<String, dynamic> toJson() => {
        'enableTLS': enableTLS,
        'minTLSVersion': minTLSVersion.name,
        'enforceHostnameValidation': enforceHostnameValidation,
        'enforceSANValidation': enforceSANValidation,
        'caCertPath': caCertPath,
        'authMethod': authMethod.name,
        'username': username,
        'password': password == null ? null : '***', // do not serialize secret
        'clientCertPath': clientCertPath,
        'clientKeyPath': clientKeyPath,
        'clientKeyPassword': clientKeyPassword == null ? null : '***',
        'validateCertificateChain': validateCertificateChain,
      };

  static MqttSecurityConfig fromJson(Map<String, dynamic> json,
      {String? username, String? password, String? clientKeyPassword}) {
    return MqttSecurityConfig(
      enableTLS: (json['enableTLS'] as bool?) ?? false,
      minTLSVersion: _parseTls(json['minTLSVersion']) ?? TLSVersion.v1_2,
      enforceHostnameValidation:
          (json['enforceHostnameValidation'] as bool?) ?? true,
      enforceSANValidation: (json['enforceSANValidation'] as bool?) ?? true,
      caCertPath: json['caCertPath'] as String?,
      authMethod:
          _parseAuth(json['authMethod']) ?? AuthenticationMethod.usernamePassword,
      username: username,
      password: password,
      clientCertPath: json['clientCertPath'] as String?,
      clientKeyPath: json['clientKeyPath'] as String?,
      clientKeyPassword: clientKeyPassword,
      validateCertificateChain:
          (json['validateCertificateChain'] as bool?) ?? true,
    );
  }

  static TLSVersion? _parseTls(Object? v) {
    if (v is String) {
      return TLSVersion.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TLSVersion.v1_2,
      );
    }
    return null;
  }

  static AuthenticationMethod? _parseAuth(Object? v) {
    if (v is String) {
      return AuthenticationMethod.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AuthenticationMethod.usernamePassword,
      );
    }
    return null;
  }
}
