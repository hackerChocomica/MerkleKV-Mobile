/// Simple in-memory counters for topic authorization decisions.
///
/// Minimal implementation (single-isolate usage). Extend with streams or
/// external export if aggregation is required.
class TopicAuthzMetrics {
  int commandAllowed = 0;
  int commandDenied = 0;
  int replicationAllowed = 0;
  int replicationDenied = 0;

  void reset() {
    commandAllowed = 0;
    commandDenied = 0;
    replicationAllowed = 0;
    replicationDenied = 0;
  }

  Map<String, Object> toJson() => {
        'commandAllowed': commandAllowed,
        'commandDenied': commandDenied,
        'replicationAllowed': replicationAllowed,
        'replicationDenied': replicationDenied,
      };

  @override
  String toString() => 'TopicAuthzMetrics(${toJson()})';
}
