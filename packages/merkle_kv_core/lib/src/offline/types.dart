/// Priority levels for offline operations
enum QueuePriority {
  /// High priority - User-initiated operations requiring immediate feedback
  high,
  /// Normal priority - Background operations with eventual consistency
  normal,
  /// Low priority - Cleanup operations that can be delayed
  low;

  /// Returns numeric value for priority comparison (higher number = higher priority)
  int get value {
    switch (this) {
      case QueuePriority.high:
        return 3;
      case QueuePriority.normal:
        return 2;
      case QueuePriority.low:
        return 1;
    }
  }
}

/// Represents a queued operation in the offline queue
class QueuedOperation {
  /// Unique identifier for the operation
  final String operationId;
  
  /// Type of operation (GET, SET, DELETE, etc.)
  final String operationType;
  
  /// Priority level for the operation
  final QueuePriority priority;
  
  /// Serialized command data (CBOR-encoded)
  final List<int> commandData;
  
  /// Timestamp when operation was queued (milliseconds since epoch)
  final int queuedAt;
  
  /// Number of retry attempts made
  final int attempts;
  
  /// Last error message if operation failed
  final String? lastError;

  const QueuedOperation({
    required this.operationId,
    required this.operationType,
    required this.priority,
    required this.commandData,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
  });

  /// Creates a copy with updated fields
  QueuedOperation copyWith({
    String? operationId,
    String? operationType,
    QueuePriority? priority,
    List<int>? commandData,
    int? queuedAt,
    int? attempts,
    String? lastError,
  }) {
    return QueuedOperation(
      operationId: operationId ?? this.operationId,
      operationType: operationType ?? this.operationType,
      priority: priority ?? this.priority,
      commandData: commandData ?? this.commandData,
      queuedAt: queuedAt ?? this.queuedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Converts to JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'operationType': operationType,
      'priority': priority.name,
      'commandData': commandData,
      'queuedAt': queuedAt,
      'attempts': attempts,
      'lastError': lastError,
    };
  }

  /// Creates instance from JSON map
  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      operationId: json['operationId'] as String,
      operationType: json['operationType'] as String,
      priority: QueuePriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => QueuePriority.normal,
      ),
      commandData: List<int>.from(json['commandData'] as List),
      queuedAt: json['queuedAt'] as int,
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  /// Returns age of the operation in milliseconds
  int get ageMs => DateTime.now().millisecondsSinceEpoch - queuedAt;
  
  /// Returns age of the operation as Duration
  Duration get age => Duration(milliseconds: ageMs);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueuedOperation && other.operationId == operationId;
  }

  @override
  int get hashCode => operationId.hashCode;

  @override
  String toString() {
    return 'QueuedOperation(id: $operationId, type: $operationType, '
           'priority: ${priority.name}, attempts: $attempts, age: ${age.inSeconds}s)';
  }
}

/// Statistics about the offline operation queue
class OfflineQueueStats {
  /// Total number of operations in queue by priority
  final Map<QueuePriority, int> operationsByPriority;
  
  /// Total number of operations processed successfully
  final int totalProcessed;
  
  /// Total number of operations that failed permanently
  final int totalFailed;
  
  /// Total number of operations dropped due to capacity limits
  final int totalDropped;
  
  /// Oldest operation age in milliseconds
  final int? oldestOperationAgeMs;
  
  /// Last successful flush timestamp
  final DateTime? lastFlushTime;

  const OfflineQueueStats({
    required this.operationsByPriority,
    required this.totalProcessed,
    required this.totalFailed,
    required this.totalDropped,
    this.oldestOperationAgeMs,
    this.lastFlushTime,
  });

  /// Total number of operations in queue
  int get totalOperations => operationsByPriority.values.fold(0, (sum, count) => sum + count);

  /// Returns age of oldest operation as Duration, or null if no operations
  Duration? get oldestOperationAge => 
      oldestOperationAgeMs != null ? Duration(milliseconds: oldestOperationAgeMs!) : null;
}