/// Replication access levels for canonical topic scheme.
enum ReplicationAccess {
  /// No access to replication topic.
  none,

  /// Read-only access (may subscribe if/when subscription API exists).
  read,

  /// Full read/write access (may publish replication events).
  readWrite,
}

/// Encapsulates canonical topic permission logic (Locked Spec §10.3).
///
/// This provides fast in-process authorization prior to broker ACL evaluation
/// to fail fast and reduce broker-side noise/log volume.
class TopicPermissions {
  final String clientId;
  final ReplicationAccess replicationAccess;

  const TopicPermissions({
    required this.clientId,
    this.replicationAccess = ReplicationAccess.readWrite,
  });

  /// A client can only publish commands to its own command topic.
  bool canPublishCommand(String targetClientId) => clientId == targetClientId;

  /// Response publish is always allowed for the local client (loopback semantics).
  bool canPublishResponse() => true;

  /// Replication publish requires readWrite replication access.
  bool canPublishReplication() => replicationAccess == ReplicationAccess.readWrite;
}
