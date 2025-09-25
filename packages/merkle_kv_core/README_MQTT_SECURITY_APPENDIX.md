# MQTT Security Appendix: Canonical Topic-level Authorization

When using the canonical topic scheme with prefix "merkle_kv", the TopicRouter performs a minimal client-side authorization check to fail fast:

- Devices are only allowed to publish command messages to their own command topic: merkle_kv/{clientId}/cmd
- Attempts to publish commands to other clients under the canonical prefix will throw an ApiException with code 300 (authorization error)
- Response and replication publishes are unaffected

Replication access levels (client-side pre-check):

| replicationAccess | Can publish replication? | Error code on deny |
|-------------------|--------------------------|--------------------|
| none              | No                       | 301                |
| read              | No (read-only)           | 301                |
| readWrite         | Yes                      | n/a                |

Add `replicationAccess` to `MerkleKVConfig` (default: readWrite) to control client ability to publish replication events under canonical scheme. Broker ACLs must still enforce server-side policy.

This mirrors the recommended broker ACLs and reduces noisy broker denials. For non-canonical prefixes (e.g., tests like "test_mkv"), no client-side restriction is applied.

Recommended Mosquitto ACL patterns for canonical scheme:

```
# Per-client access using MQTT %c (client ID)
pattern readwrite merkle_kv/%c/+
pattern readwrite merkle_kv/%c/+/+

# Optionally restrict replication to read-only for devices
topic read merkle_kv/replication/events
```

Client-side enforcement example:

```dart
final cfg = MerkleKVConfig.create(
  mqttHost: 'broker',
  clientId: 'device-1',
  nodeId: 'node-1',
  topicPrefix: 'merkle_kv',
);
final client = MqttClientImpl(cfg);
final router = TopicRouterImpl(cfg, client);

// Allowed (self-target)
await router.publishCommand('device-1', '{"op":"PING"}');

// Denied (cross-client)
await expectLater(
  () => router.publishCommand('device-2', '{"op":"PING"}'),
  throwsA(isA<ApiException>().having((e) => e.code, 'code', 300)),
);
```
