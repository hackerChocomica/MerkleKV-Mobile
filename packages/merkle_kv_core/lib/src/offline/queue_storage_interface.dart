import 'dart:async';
import 'types.dart';

/// Abstract interface for persistent queue storage
/// 
/// Provides methods to persist offline operations across app restarts using
/// platform-appropriate storage (SQLite on mobile). Operations are stored
/// with priority and expiration metadata for efficient retrieval and management.
abstract class QueueStorageInterface {
  /// Initializes the storage backend
  /// 
  /// Creates necessary tables and indexes for operation storage.
  /// Must be called before using other storage operations.
  Future<void> initialize();

  /// Stores a queued operation persistently
  /// 
  /// [operation] - The operation to store
  /// 
  /// Throws [StorageException] if storage operation fails
  Future<void> storeOperation(QueuedOperation operation);

  /// Updates an existing operation (e.g., increment attempts, update error)
  /// 
  /// [operation] - The updated operation
  /// 
  /// Throws [StorageException] if operation doesn't exist or update fails
  Future<void> updateOperation(QueuedOperation operation);

  /// Retrieves all operations ordered by priority (high to low) and age (oldest first within priority)
  /// 
  /// Returns operations in processing order: High priority first, then Normal, then Low.
  /// Within each priority level, returns oldest operations first (FIFO).
  Future<List<QueuedOperation>> getAllOperations();

  /// Retrieves operations by priority level
  /// 
  /// [priority] - Priority level to filter by
  /// 
  /// Returns operations sorted by age (oldest first)
  Future<List<QueuedOperation>> getOperationsByPriority(QueuePriority priority);

  /// Removes a specific operation from storage
  /// 
  /// [operationId] - Unique identifier of operation to remove
  /// 
  /// Returns true if operation was found and removed, false otherwise
  Future<bool> removeOperation(String operationId);

  /// Removes multiple operations in a single transaction
  /// 
  /// [operationIds] - List of operation IDs to remove
  /// 
  /// Returns number of operations actually removed
  Future<int> removeOperations(List<String> operationIds);

  /// Removes expired operations older than the specified duration
  /// 
  /// [maxAge] - Maximum age of operations to keep
  /// 
  /// Returns number of operations removed
  Future<int> removeExpiredOperations(Duration maxAge);

  /// Gets count of operations by priority level
  /// 
  /// Returns map with count for each priority level
  Future<Map<QueuePriority, int>> getOperationCounts();

  /// Gets the oldest operation timestamp (for age calculations)
  /// 
  /// Returns null if no operations exist
  Future<int?> getOldestOperationTimestamp();

  /// Removes oldest operations of the specified priority to make room
  /// 
  /// [priority] - Priority level to evict from
  /// [count] - Number of operations to remove
  /// 
  /// Returns number of operations actually removed
  Future<int> evictOldestOperations(QueuePriority priority, int count);

  /// Gets total number of operations in storage
  Future<int> getTotalOperationCount();

  /// Clears all operations from storage
  /// 
  /// Used for testing or complete reset
  Future<void> clearAll();

  /// Disposes of storage resources
  /// 
  /// Should be called when storage is no longer needed
  Future<void> dispose();
}

/// Exception thrown when storage operations fail
class StorageException implements Exception {
  /// Error message describing the failure
  final String message;
  
  /// Optional underlying cause
  final Object? cause;
  
  const StorageException(this.message, [this.cause]);
  
  @override
  String toString() {
    if (cause != null) {
      return 'StorageException: $message (cause: $cause)';
    }
    return 'StorageException: $message';
  }
}