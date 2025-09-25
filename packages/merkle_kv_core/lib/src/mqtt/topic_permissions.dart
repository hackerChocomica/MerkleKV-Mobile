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
  final bool isController;

  const TopicPermissions({
    required this.clientId,
    this.replicationAccess = ReplicationAccess.readWrite,
    this.isController = false,
  });

  /// A controller can publish to any client; non-controller only to self.
  bool canPublishCommand(String targetClientId) =>
      isController || clientId == targetClientId;

  /// Response publish is always allowed for local client.
  bool canPublishResponse() => true;

  bool canSubscribeToResponsesOf(String targetClientId) =>
      isController ? true : targetClientId == clientId;

  /// Replication publish requires readWrite replication access.
  bool canPublishReplication() =>
      replicationAccess == ReplicationAccess.readWrite;
}
