import 'package:test/test.dart';

import '../../../lib/src/offline/types.dart';

/// Tests for offline queue types and data structures
void main() {
  group('QueuePriority', () {
    test('priority values are ordered correctly', () {
      expect(QueuePriority.high.value, 3);
      expect(QueuePriority.normal.value, 2);
      expect(QueuePriority.low.value, 1);
      
      // High priority should have higher value than normal
      expect(QueuePriority.high.value > QueuePriority.normal.value, isTrue);
      // Normal priority should have higher value than low
      expect(QueuePriority.normal.value > QueuePriority.low.value, isTrue);
    });
  });

  group('QueuedOperation', () {
    test('creates operation with required fields', () {
      final operation = QueuedOperation(
        operationId: 'test-id',
        operationType: 'SET',
        priority: QueuePriority.high,
        commandData: [1, 2, 3, 4],
        queuedAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(operation.operationId, 'test-id');
      expect(operation.operationType, 'SET');
      expect(operation.priority, QueuePriority.high);
      expect(operation.commandData, [1, 2, 3, 4]);
      expect(operation.attempts, 0); // Default value
      expect(operation.lastError, isNull); // Default value
    });

    test('copyWith updates specified fields', () {
      final original = QueuedOperation(
        operationId: 'test-id',
        operationType: 'SET',
        priority: QueuePriority.normal,
        commandData: [1, 2, 3],
        queuedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final updated = original.copyWith(
        attempts: 2,
        lastError: 'Connection failed',
      );

      expect(updated.operationId, original.operationId); // Unchanged
      expect(updated.operationType, original.operationType); // Unchanged
      expect(updated.priority, original.priority); // Unchanged
      expect(updated.attempts, 2); // Changed
      expect(updated.lastError, 'Connection failed'); // Changed
    });

    test('toJson and fromJson round trip', () {
      final original = QueuedOperation(
        operationId: 'test-op-123',
        operationType: 'GET',
        priority: QueuePriority.low,
        commandData: [10, 20, 30],
        queuedAt: 1234567890,
        attempts: 1,
        lastError: 'Network timeout',
      );

      final json = original.toJson();
      final restored = QueuedOperation.fromJson(json);

      expect(restored.operationId, original.operationId);
      expect(restored.operationType, original.operationType);
      expect(restored.priority, original.priority);
      expect(restored.commandData, original.commandData);
      expect(restored.queuedAt, original.queuedAt);
      expect(restored.attempts, original.attempts);
      expect(restored.lastError, original.lastError);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'operationId': 'test-id',
        'operationType': 'DELETE',
        'priority': 'high',
        'commandData': [5, 6, 7],
        'queuedAt': 9876543210,
        // attempts and lastError are missing
      };

      final operation = QueuedOperation.fromJson(json);
      
      expect(operation.attempts, 0); // Default value
      expect(operation.lastError, isNull); // Default value
    });

    test('fromJson handles invalid priority gracefully', () {
      final json = {
        'operationId': 'test-id',
        'operationType': 'SET',
        'priority': 'invalid-priority', // Invalid priority
        'commandData': [1, 2],
        'queuedAt': 1000000,
      };

      final operation = QueuedOperation.fromJson(json);
      
      expect(operation.priority, QueuePriority.normal); // Falls back to normal
    });

    test('age calculation works correctly', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final fiveMinutesAgoMs = nowMs - (5 * 60 * 1000);
      
      final operation = QueuedOperation(
        operationId: 'test-id',
        operationType: 'SET',
        priority: QueuePriority.normal,
        commandData: [1, 2, 3],
        queuedAt: fiveMinutesAgoMs,
      );

      // Age should be approximately 5 minutes (allowing for small timing differences)
      expect(operation.age.inMinutes, closeTo(5, 1));
    });

    test('equality comparison works correctly', () {
      final op1 = QueuedOperation(
        operationId: 'same-id',
        operationType: 'SET',
        priority: QueuePriority.high,
        commandData: [1, 2, 3],
        queuedAt: 1000,
      );

      final op2 = QueuedOperation(
        operationId: 'same-id', // Same ID
        operationType: 'GET', // Different type
        priority: QueuePriority.low, // Different priority
        commandData: [4, 5, 6], // Different data
        queuedAt: 2000, // Different time
      );

      final op3 = QueuedOperation(
        operationId: 'different-id',
        operationType: 'SET',
        priority: QueuePriority.high,
        commandData: [1, 2, 3],
        queuedAt: 1000,
      );

      // Operations with same ID are equal
      expect(op1 == op2, isTrue);
      expect(op1.hashCode, op2.hashCode);
      
      // Operations with different IDs are not equal
      expect(op1 == op3, isFalse);
    });
  });

  group('OfflineQueueStats', () {
    test('calculates total operations correctly', () {
      final stats = OfflineQueueStats(
        operationsByPriority: {
          QueuePriority.high: 5,
          QueuePriority.normal: 10,
          QueuePriority.low: 3,
        },
        totalProcessed: 100,
        totalFailed: 5,
        totalDropped: 2,
      );

      expect(stats.totalOperations, 18); // 5 + 10 + 3
    });

    test('handles oldest operation age conversion', () {
      final stats = OfflineQueueStats(
        operationsByPriority: {
          QueuePriority.high: 1,
          QueuePriority.normal: 0,
          QueuePriority.low: 0,
        },
        totalProcessed: 0,
        totalFailed: 0,
        totalDropped: 0,
        oldestOperationAgeMs: 300000, // 5 minutes
      );

      expect(stats.oldestOperationAge, isNotNull);
      expect(stats.oldestOperationAge!.inMinutes, 5);
    });

    test('handles null oldest operation age', () {
      final stats = OfflineQueueStats(
        operationsByPriority: {
          QueuePriority.high: 0,
          QueuePriority.normal: 0,
          QueuePriority.low: 0,
        },
        totalProcessed: 0,
        totalFailed: 0,
        totalDropped: 0,
        oldestOperationAgeMs: null, // No operations
      );

      expect(stats.oldestOperationAge, isNull);
    });
  });
}