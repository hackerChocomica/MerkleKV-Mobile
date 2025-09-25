import 'dart:async';
import 'dart:math' as math;
import 'package:cbor/cbor.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../commands/command.dart';
import '../utils/logger.dart';
import 'queue_storage_interface.dart';
import 'sqlite_queue_storage.dart';
import 'types.dart';

/// Configuration for the offline operation queue
class OfflineQueueConfig {
  /// Maximum number of operations to keep in queue
  final int maxOperations;
  
  /// Maximum age for operations before expiration
  final Duration maxAge;
  
  /// Default priority for new operations
  final QueuePriority defaultPriority;
  
  /// Maximum number of retry attempts per operation
  final int maxRetryAttempts;
  
  /// Base delay between retry attempts
  final Duration retryBaseDelay;
  
  /// Maximum delay between retry attempts
  final Duration retryMaxDelay;
  
  /// Batch size for processing operations
  final int batchSize;

  const OfflineQueueConfig({
    this.maxOperations = 10000,
    this.maxAge = const Duration(days: 7),
    this.defaultPriority = QueuePriority.normal,
    this.maxRetryAttempts = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.retryMaxDelay = const Duration(minutes: 5),
    this.batchSize = 50,
  });
}

/// Enhanced offline operation queue with persistence and prioritization
/// 
/// Provides comprehensive offline operation queuing beyond basic outbox functionality.
/// Operations are persisted across app restarts, prioritized for efficient processing,
/// and automatically expired to prevent unbounded growth.
/// 
/// This queue is specifically for command operations and is separate from the 
/// replication outbox to ensure proper separation of concerns.
class OfflineOperationQueue {
  static final Logger _logger = Logger('OfflineOperationQueue');
  
  final OfflineQueueConfig _config;
  final QueueStorageInterface _storage;
  
  // Statistics tracking
  int _totalProcessed = 0;
  int _totalFailed = 0;
  int _totalDropped = 0;
  DateTime? _lastFlushTime;
  
  // Processing state
  bool _isProcessing = false;
  bool _isConnected = false;
  Timer? _processingTimer;
  Timer? _cleanupTimer;
  
  // Stream controllers for monitoring
  final StreamController<OfflineQueueStats> _statsController = 
      StreamController<OfflineQueueStats>.broadcast();
  
  /// Creates offline operation queue with configuration
  /// 
  /// [config] - Queue configuration options
  /// [storage] - Optional custom storage implementation (defaults to SQLite)
  OfflineOperationQueue({
    OfflineQueueConfig? config,
    QueueStorageInterface? storage,
  }) : _config = config ?? const OfflineQueueConfig(),
       _storage = storage ?? SqliteQueueStorage() {
    
    // Schedule periodic cleanup of expired operations
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) => _cleanup());
  }

  /// Stream of queue statistics for monitoring
  Stream<OfflineQueueStats> get statsStream => _statsController.stream;

  /// Initializes the queue and loads persisted operations
  Future<void> initialize() async {
    try {
      await _storage.initialize();
      _logger.info('Offline operation queue initialized');
      
      // Emit initial statistics
      await _emitStats();
    } catch (e) {
      _logger.severe('Failed to initialize offline operation queue: $e');
      rethrow;
    }
  }

  /// Updates connection state and triggers processing if connected
  set isConnected(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _logger.info('Connection state changed: ${connected ? 'connected' : 'disconnected'}');
      
      if (connected && !_isProcessing) {
        _scheduleProcessing();
      }
    }
  }

  /// Gets current connection state
  bool get isConnected => _isConnected;

  /// Queues an operation for offline processing
  /// 
  /// [command] - The command to queue
  /// [priority] - Priority level (defaults to config.defaultPriority)
  /// 
  /// Returns the generated operation ID
  Future<String> queueOperation(
    Command command, {
    QueuePriority? priority,
  }) async {
    final operationId = _generateOperationId();
    final effectivePriority = priority ?? _config.defaultPriority;
    
    try {
      // Serialize command to CBOR
      final commandJson = command.toJson();
      final commandCbor = cbor.encode(CborValue(commandJson));
      
      final operation = QueuedOperation(
        operationId: operationId,
        operationType: command.op,
        priority: effectivePriority,
        commandData: commandCbor,
        queuedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      // Check capacity and evict if necessary
      await _ensureCapacity();
      
      await _storage.storeOperation(operation);
      
      _logger.info('Queued operation $operationId (${command.op}, priority: ${effectivePriority.name})');
      
      // Trigger processing if connected
      if (_isConnected && !_isProcessing) {
        _scheduleProcessing();
      }
      
      await _emitStats();
      return operationId;
      
    } catch (e) {
      _logger.severe('Failed to queue operation: $e');
      rethrow;
    }
  }

  /// Removes a specific operation from the queue
  /// 
  /// [operationId] - ID of operation to remove
  /// 
  /// Returns true if operation was found and removed
  Future<bool> removeOperation(String operationId) async {
    try {
      final removed = await _storage.removeOperation(operationId);
      if (removed) {
        _logger.info('Removed operation $operationId from queue');
        await _emitStats();
      }
      return removed;
    } catch (e) {
      _logger.severe('Failed to remove operation $operationId: $e');
      return false;
    }
  }

  /// Gets current queue statistics
  Future<OfflineQueueStats> getStats() async {
    try {
      final counts = await _storage.getOperationCounts();
      final oldestTimestamp = await _storage.getOldestOperationTimestamp();
      
      return OfflineQueueStats(
        operationsByPriority: counts,
        totalProcessed: _totalProcessed,
        totalFailed: _totalFailed,
        totalDropped: _totalDropped,
        oldestOperationAgeMs: oldestTimestamp != null 
            ? DateTime.now().millisecondsSinceEpoch - oldestTimestamp
            : null,
        lastFlushTime: _lastFlushTime,
      );
    } catch (e) {
      _logger.severe('Failed to get queue statistics: $e');
      // Return default stats on error
      return OfflineQueueStats(
        operationsByPriority: {
          QueuePriority.high: 0,
          QueuePriority.normal: 0,
          QueuePriority.low: 0,
        },
        totalProcessed: _totalProcessed,
        totalFailed: _totalFailed,
        totalDropped: _totalDropped,
        oldestOperationAgeMs: null,
        lastFlushTime: _lastFlushTime,
      );
    }
  }

  /// Clears all operations from the queue
  Future<void> clear() async {
    try {
      await _storage.clearAll();
      _logger.info('Cleared all operations from queue');
      await _emitStats();
    } catch (e) {
      _logger.severe('Failed to clear queue: $e');
      rethrow;
    }
  }

  /// Ensures queue doesn't exceed capacity limits
  Future<void> _ensureCapacity() async {
    final totalCount = await _storage.getTotalOperationCount();
    
    if (totalCount >= _config.maxOperations) {
      // Evict oldest low-priority operations first
      final toEvict = (totalCount - _config.maxOperations) + 1;
      
      // Try to evict low priority first
      int evicted = await _storage.evictOldestOperations(QueuePriority.low, toEvict);
      _totalDropped += evicted;
      
      // If we still need to evict more, try normal priority
      if (evicted < toEvict) {
        final remaining = toEvict - evicted;
        final normalEvicted = await _storage.evictOldestOperations(QueuePriority.normal, remaining);
        evicted += normalEvicted;
        _totalDropped += normalEvicted;
      }
      
      // Last resort: evict high priority
      if (evicted < toEvict) {
        final remaining = toEvict - evicted;
        final highEvicted = await _storage.evictOldestOperations(QueuePriority.high, remaining);
        evicted += highEvicted;
        _totalDropped += highEvicted;
      }
      
      if (evicted > 0) {
        _logger.warning('Evicted $evicted operations to maintain capacity limit');
      }
    }
  }

  /// Schedules processing of queued operations
  void _scheduleProcessing() {
    if (_isProcessing) return;
    
    _processingTimer?.cancel();
    _processingTimer = Timer(const Duration(milliseconds: 100), _processQueue);
  }

  /// Processes queued operations in batches
  Future<void> _processQueue() async {
    if (_isProcessing || !_isConnected) return;
    
    _isProcessing = true;
    
    try {
      final operations = await _storage.getAllOperations();
      if (operations.isEmpty) {
        _isProcessing = false;
        return;
      }
      
      _logger.info('Processing ${operations.length} queued operations');
      
      // Process in batches
      for (int i = 0; i < operations.length; i += _config.batchSize) {
        if (!_isConnected) break; // Stop if disconnected
        
        final batch = operations.skip(i).take(_config.batchSize).toList();
        await _processBatch(batch);
      }
      
      _lastFlushTime = DateTime.now();
      await _emitStats();
      
    } catch (e) {
      _logger.severe('Error processing queue: $e');
    } finally {
      _isProcessing = false;
      
      // Check if there are more operations to process
      if (_isConnected) {
        final remaining = await _storage.getTotalOperationCount();
        if (remaining > 0) {
          _scheduleProcessing();
        }
      }
    }
  }

  /// Processes a batch of operations
  Future<void> _processBatch(List<QueuedOperation> batch) async {
    final futures = batch.map(_processOperation).toList();
    await Future.wait(futures, eagerError: false);
  }

  /// Processes a single operation
  Future<void> _processOperation(QueuedOperation operation) async {
    try {
      // Check if operation has expired
      if (operation.age > _config.maxAge) {
        await _storage.removeOperation(operation.operationId);
        _logger.info('Removed expired operation ${operation.operationId}');
        return;
      }
      
      // Check retry limits
      if (operation.attempts >= _config.maxRetryAttempts) {
        await _storage.removeOperation(operation.operationId);
        _totalFailed++;
        _logger.warning('Operation ${operation.operationId} exceeded retry limit, removing');
        return;
      }
      
      // Deserialize and execute command
      final decoded = cbor.decode(operation.commandData);
      final commandJson = _extractJsonFromCbor(decoded);
      final command = Command.fromJson(Map<String, dynamic>.from(commandJson));
      
      // TODO: Execute command through command processor
      // For now, simulate successful processing
      await _simulateCommandExecution(command);
      
      // Remove successfully processed operation
      await _storage.removeOperation(operation.operationId);
      _totalProcessed++;
      
      _logger.info('Successfully processed operation ${operation.operationId}');
      
    } catch (e) {
      _logger.warning('Failed to process operation ${operation.operationId}: $e');
      
      // Update operation with error and increment attempts
      final updatedOp = operation.copyWith(
        attempts: operation.attempts + 1,
        lastError: e.toString(),
      );
      
      // For now, just update the operation. In a full implementation,
      // we would schedule the retry after calculating the delay with _calculateRetryDelay()
      await _storage.updateOperation(updatedOp);
    }
  }

  /// Simulates command execution (placeholder for actual implementation)
  Future<void> _simulateCommandExecution(Command command) async {
    // In the actual implementation, this would execute the command
    // through the command processor
    await Future.delayed(const Duration(milliseconds: 10));
  }

  /// Extracts JSON object from CBOR-decoded value
  Map<String, dynamic> _extractJsonFromCbor(dynamic cborValue) {
    if (cborValue is CborValue) {
      final value = cborValue.toObject();
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    } else if (cborValue is Map) {
      return Map<String, dynamic>.from(cborValue);
    }
    throw const FormatException('Invalid CBOR format for command data');
  }

  /// Performs cleanup of expired operations
  Future<void> _cleanup() async {
    try {
      final removed = await _storage.removeExpiredOperations(_config.maxAge);
      if (removed > 0) {
        _logger.info('Cleaned up $removed expired operations');
        await _emitStats();
      }
    } catch (e) {
      _logger.severe('Error during cleanup: $e');
    }
  }

  /// Emits current statistics to stream
  Future<void> _emitStats() async {
    try {
      final stats = await getStats();
      _statsController.add(stats);
    } catch (e) {
      _logger.severe('Failed to emit stats: $e');
    }
  }

  /// Generates unique operation ID
  String _generateOperationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(0xFFFFFF);
    final combined = '$timestamp-$random';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Disposes of the queue and releases resources
  Future<void> dispose() async {
    _processingTimer?.cancel();
    _cleanupTimer?.cancel();
    await _statsController.close();
    
    try {
      await _storage.dispose();
    } catch (e) {
      _logger.severe('Error disposing storage: $e');
    }
    
    _logger.info('Offline operation queue disposed');
  }
}