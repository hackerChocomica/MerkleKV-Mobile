import 'dart:async';
import 'package:test/test.dart';

import '../../lib/src/commands/command.dart';
import '../../lib/src/offline/offline_operation_queue.dart';
import '../../lib/src/offline/queue_storage_interface.dart';
import '../../lib/src/offline/types.dart';

/// Mock storage implementation for testing
class MockQueueStorage implements QueueStorageInterface {
  final Map<String, QueuedOperation> _operations = {};
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> storeOperation(QueuedOperation operation) async {
    _throwIfNotInitialized();
    _operations[operation.operationId] = operation;
  }

  @override
  Future<void> updateOperation(QueuedOperation operation) async {
    _throwIfNotInitialized();
    if (!_operations.containsKey(operation.operationId)) {
      throw const StorageException('Operation not found');
    }
    _operations[operation.operationId] = operation;
  }

  @override
  Future<List<QueuedOperation>> getAllOperations() async {
    _throwIfNotInitialized();
    final ops = _operations.values.toList();
    // Sort by priority (high to low) then by queuedAt (oldest first)
    ops.sort((a, b) {
      final priorityComparison = b.priority.value.compareTo(a.priority.value);
      if (priorityComparison != 0) return priorityComparison;
      return a.queuedAt.compareTo(b.queuedAt);
    });
    return ops;
  }

  @override
  Future<List<QueuedOperation>> getOperationsByPriority(QueuePriority priority) async {
    _throwIfNotInitialized();
    final ops = _operations.values.where((op) => op.priority == priority).toList();
    ops.sort((a, b) => a.queuedAt.compareTo(b.queuedAt)); // FIFO within priority
    return ops;
  }

  @override
  Future<bool> removeOperation(String operationId) async {
    _throwIfNotInitialized();
    return _operations.remove(operationId) != null;
  }

  @override
  Future<int> removeOperations(List<String> operationIds) async {
    _throwIfNotInitialized();
    int removed = 0;
    for (final id in operationIds) {
      if (_operations.remove(id) != null) {
        removed++;
      }
    }
    return removed;
  }

  @override
  Future<int> removeExpiredOperations(Duration maxAge) async {
    _throwIfNotInitialized();
    final cutoffTime = DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    final toRemove = <String>[];
    
    for (final op in _operations.values) {
      if (op.queuedAt < cutoffTime) {
        toRemove.add(op.operationId);
      }
    }
    
    return await removeOperations(toRemove);
  }

  @override
  Future<Map<QueuePriority, int>> getOperationCounts() async {
    _throwIfNotInitialized();
    final counts = <QueuePriority, int>{
      QueuePriority.high: 0,
      QueuePriority.normal: 0,
      QueuePriority.low: 0,
    };
    
    for (final op in _operations.values) {
      counts[op.priority] = (counts[op.priority] ?? 0) + 1;
    }
    
    return counts;
  }

  @override
  Future<int?> getOldestOperationTimestamp() async {
    _throwIfNotInitialized();
    if (_operations.isEmpty) return null;
    
    return _operations.values
        .map((op) => op.queuedAt)
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Future<int> evictOldestOperations(QueuePriority priority, int count) async {
    _throwIfNotInitialized();
    final priorityOps = await getOperationsByPriority(priority);
    final toRemove = priorityOps.take(count).map((op) => op.operationId).toList();
    return await removeOperations(toRemove);
  }

  @override
  Future<int> getTotalOperationCount() async {
    _throwIfNotInitialized();
    return _operations.length;
  }

  @override
  Future<void> clearAll() async {
    _throwIfNotInitialized();
    _operations.clear();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _operations.clear();
  }

  void _throwIfNotInitialized() {
    if (!_initialized || _disposed) {
      throw const StorageException('Storage not initialized or disposed');
    }
  }

  // Test helpers
  bool get isInitialized => _initialized;
  bool get isDisposed => _disposed;
  int get operationCount => _operations.length;
}

/// Integration tests for offline operation queue
void main() {
  group('OfflineOperationQueue Integration Tests', () {
    late OfflineOperationQueue queue;
    late MockQueueStorage storage;

    setUp(() async {
      storage = MockQueueStorage();
      queue = OfflineOperationQueue(
        config: const OfflineQueueConfig(
          maxOperations: 100,
          maxAge: Duration(days: 1),
          batchSize: 10,
        ),
        storage: storage,
      );
      await queue.initialize();
    });

    tearDown(() async {
      await queue.dispose();
    });

    test('initializes storage on startup', () async {
      expect(storage.isInitialized, isTrue);
    });

    test('queues operation when offline', () async {
      // Queue is offline initially
      expect(queue.isConnected, isFalse);

      final command = Command(
        id: 'test-cmd-1',
        op: 'SET',
        key: 'test-key',
        value: 'test-value',
      );

      final operationId = await queue.queueOperation(command);
      expect(operationId, isNotEmpty);
      expect(storage.operationCount, 1);

      final stats = await queue.getStats();
      expect(stats.totalOperations, 1);
      expect(stats.operationsByPriority[QueuePriority.normal], 1);
    });

    test('queues operations with different priorities', () async {
      final command1 = Command(id: 'cmd-1', op: 'SET', key: 'key1', value: 'value1');
      final command2 = Command(id: 'cmd-2', op: 'GET', key: 'key2');
      final command3 = Command(id: 'cmd-3', op: 'DELETE', key: 'key3');

      await queue.queueOperation(command1, priority: QueuePriority.high);
      await queue.queueOperation(command2, priority: QueuePriority.normal);
      await queue.queueOperation(command3, priority: QueuePriority.low);

      final stats = await queue.getStats();
      expect(stats.totalOperations, 3);
      expect(stats.operationsByPriority[QueuePriority.high], 1);
      expect(stats.operationsByPriority[QueuePriority.normal], 1);
      expect(stats.operationsByPriority[QueuePriority.low], 1);
    });

    test('operations are ordered by priority', () async {
      // Add operations in reverse priority order
      final lowCmd = Command(id: 'low', op: 'SET', key: 'low', value: '1');
      final normalCmd = Command(id: 'normal', op: 'SET', key: 'normal', value: '2');
      final highCmd = Command(id: 'high', op: 'SET', key: 'high', value: '3');

      await queue.queueOperation(lowCmd, priority: QueuePriority.low);
      await queue.queueOperation(normalCmd, priority: QueuePriority.normal);
      await queue.queueOperation(highCmd, priority: QueuePriority.high);

      final operations = await storage.getAllOperations();
      expect(operations.length, 3);
      
      // Should be ordered high, normal, low
      expect(operations[0].priority, QueuePriority.high);
      expect(operations[1].priority, QueuePriority.normal);
      expect(operations[2].priority, QueuePriority.low);
    });

    test('FIFO ordering within same priority', () async {
      final cmd1 = Command(id: 'cmd1', op: 'SET', key: 'key1', value: 'value1');
      final cmd2 = Command(id: 'cmd2', op: 'SET', key: 'key2', value: 'value2');
      final cmd3 = Command(id: 'cmd3', op: 'SET', key: 'key3', value: 'value3');

      // All same priority, added in order
      await queue.queueOperation(cmd1, priority: QueuePriority.normal);
      await Future.delayed(const Duration(milliseconds: 1)); // Ensure different timestamps
      await queue.queueOperation(cmd2, priority: QueuePriority.normal);
      await Future.delayed(const Duration(milliseconds: 1));
      await queue.queueOperation(cmd3, priority: QueuePriority.normal);

      final normalOps = await storage.getOperationsByPriority(QueuePriority.normal);
      expect(normalOps.length, 3);
      
      // Should be in FIFO order (oldest first)
      expect(normalOps[0].queuedAt <= normalOps[1].queuedAt, isTrue);
      expect(normalOps[1].queuedAt <= normalOps[2].queuedAt, isTrue);
    });

    test('removes operation successfully', () async {
      final command = Command(id: 'test-cmd', op: 'SET', key: 'test', value: 'test');
      final operationId = await queue.queueOperation(command);

      expect(storage.operationCount, 1);
      
      final removed = await queue.removeOperation(operationId);
      expect(removed, isTrue);
      expect(storage.operationCount, 0);

      final stats = await queue.getStats();
      expect(stats.totalOperations, 0);
    });

    test('returns false when removing non-existent operation', () async {
      final removed = await queue.removeOperation('non-existent-id');
      expect(removed, isFalse);
    });

    test('clears all operations', () async {
      // Add some operations
      final cmd1 = Command(id: 'cmd1', op: 'SET', key: 'key1', value: 'value1');
      final cmd2 = Command(id: 'cmd2', op: 'SET', key: 'key2', value: 'value2');
      
      await queue.queueOperation(cmd1);
      await queue.queueOperation(cmd2);
      expect(storage.operationCount, 2);

      await queue.clear();
      expect(storage.operationCount, 0);

      final stats = await queue.getStats();
      expect(stats.totalOperations, 0);
    });

    test('disposes storage properly', () async {
      await queue.dispose();
      expect(storage.isDisposed, isTrue);
    });

    test('stats include aging information', () async {
      final command = Command(id: 'test-cmd', op: 'SET', key: 'test', value: 'test');
      await queue.queueOperation(command);

      final stats = await queue.getStats();
      expect(stats.oldestOperationAge, isNotNull);
      expect(stats.oldestOperationAge!.inMilliseconds >= 0, isTrue);
    });
  });

  group('OfflineOperationQueue Configuration Tests', () {
    test('uses provided configuration', () async {
      final config = OfflineQueueConfig(
        maxOperations: 50,
        maxAge: const Duration(hours: 12),
        defaultPriority: QueuePriority.high,
        maxRetryAttempts: 5,
        batchSize: 25,
      );

      final storage = MockQueueStorage();
      final queue = OfflineOperationQueue(config: config, storage: storage);
      await queue.initialize();

      final command = Command(id: 'test', op: 'SET', key: 'key', value: 'value');
      await queue.queueOperation(command); // Should use high priority as default

      final operations = await storage.getAllOperations();
      expect(operations[0].priority, QueuePriority.high);

      await queue.dispose();
    });
  });
}