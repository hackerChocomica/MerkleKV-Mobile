import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'queue_storage_interface.dart';
import 'types.dart';

/// SQLite implementation of queue storage for persistent offline operations
/// 
/// Provides cross-app-restart persistence using SQLite database with proper
/// indexing for efficient priority-based retrieval and cleanup operations.
class SqliteQueueStorage implements QueueStorageInterface {
  static const String _databaseName = 'offline_queue.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'queued_operations';

  Database? _database;
  bool _isInitialized = false;

  /// Gets the database instance, initializing if needed
  Future<Database> get _db async {
    if (_database == null || !_isInitialized) {
      throw const StorageException('Storage not initialized. Call initialize() first.');
    }
    return _database!;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize ffi implementation for non-Flutter environments
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);

      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      _isInitialized = true;
    } catch (e) {
      throw StorageException('Failed to initialize SQLite storage', e);
    }
  }

  /// Creates the database tables and indexes
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        operation_id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        priority INTEGER NOT NULL,
        command_data BLOB NOT NULL,
        queued_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Create indexes for efficient querying
    await db.execute('CREATE INDEX idx_priority_queued_at ON $_tableName (priority DESC, queued_at ASC)');
    await db.execute('CREATE INDEX idx_queued_at ON $_tableName (queued_at ASC)');
  }

  /// Handles database schema upgrades
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations would go here
  }

  @override
  Future<void> storeOperation(QueuedOperation operation) async {
    final db = await _db;
    
    try {
      await db.insert(
        _tableName,
        {
          'operation_id': operation.operationId,
          'operation_type': operation.operationType,
          'priority': operation.priority.value,
          'command_data': operation.commandData,
          'queued_at': operation.queuedAt,
          'attempts': operation.attempts,
          'last_error': operation.lastError,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw StorageException('Failed to store operation ${operation.operationId}', e);
    }
  }

  @override
  Future<void> updateOperation(QueuedOperation operation) async {
    final db = await _db;
    
    try {
      final rowsAffected = await db.update(
        _tableName,
        {
          'operation_type': operation.operationType,
          'priority': operation.priority.value,
          'command_data': operation.commandData,
          'queued_at': operation.queuedAt,
          'attempts': operation.attempts,
          'last_error': operation.lastError,
        },
        where: 'operation_id = ?',
        whereArgs: [operation.operationId],
      );
      
      if (rowsAffected == 0) {
        throw StorageException('Operation ${operation.operationId} not found for update');
      }
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to update operation ${operation.operationId}', e);
    }
  }

  @override
  Future<List<QueuedOperation>> getAllOperations() async {
    final db = await _db;
    
    try {
      // Query ordered by priority (desc) then by queued_at (asc) for FIFO within priority
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'priority DESC, queued_at ASC',
      );
      
      return maps.map(_mapToOperation).toList();
    } catch (e) {
      throw StorageException('Failed to retrieve all operations', e);
    }
  }

  @override
  Future<List<QueuedOperation>> getOperationsByPriority(QueuePriority priority) async {
    final db = await _db;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'priority = ?',
        whereArgs: [priority.value],
        orderBy: 'queued_at ASC',  // FIFO within priority
      );
      
      return maps.map(_mapToOperation).toList();
    } catch (e) {
      throw StorageException('Failed to retrieve operations by priority ${priority.name}', e);
    }
  }

  @override
  Future<bool> removeOperation(String operationId) async {
    final db = await _db;
    
    try {
      final rowsAffected = await db.delete(
        _tableName,
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
      
      return rowsAffected > 0;
    } catch (e) {
      throw StorageException('Failed to remove operation $operationId', e);
    }
  }

  @override
  Future<int> removeOperations(List<String> operationIds) async {
    if (operationIds.isEmpty) return 0;
    
    final db = await _db;
    
    try {
      final batch = db.batch();
      for (final id in operationIds) {
        batch.delete(
          _tableName,
          where: 'operation_id = ?',
          whereArgs: [id],
        );
      }
      
      final results = await batch.commit(noResult: false);
      return results.fold<int>(0, (sum, result) => sum + (result as int));
    } catch (e) {
      throw StorageException('Failed to remove ${operationIds.length} operations', e);
    }
  }

  @override
  Future<int> removeExpiredOperations(Duration maxAge) async {
    final db = await _db;
    final cutoffTime = DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    
    try {
      return await db.delete(
        _tableName,
        where: 'queued_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      throw StorageException('Failed to remove expired operations', e);
    }
  }

  @override
  Future<Map<QueuePriority, int>> getOperationCounts() async {
    final db = await _db;
    
    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        'SELECT priority, COUNT(*) as count FROM $_tableName GROUP BY priority',
      );
      
      final counts = <QueuePriority, int>{
        QueuePriority.high: 0,
        QueuePriority.normal: 0,
        QueuePriority.low: 0,
      };
      
      for (final result in results) {
        final priority = _priorityFromValue(result['priority'] as int);
        counts[priority] = result['count'] as int;
      }
      
      return counts;
    } catch (e) {
      throw StorageException('Failed to get operation counts', e);
    }
  }

  @override
  Future<int?> getOldestOperationTimestamp() async {
    final db = await _db;
    
    try {
      final List<Map<String, dynamic>> results = await db.rawQuery(
        'SELECT MIN(queued_at) as oldest FROM $_tableName',
      );
      
      if (results.isNotEmpty && results.first['oldest'] != null) {
        return results.first['oldest'] as int;
      }
      return null;
    } catch (e) {
      throw StorageException('Failed to get oldest operation timestamp', e);
    }
  }

  @override
  Future<int> evictOldestOperations(QueuePriority priority, int count) async {
    if (count <= 0) return 0;
    
    final db = await _db;
    
    try {
      // Get the oldest operations of the specified priority
      final List<Map<String, dynamic>> operations = await db.query(
        _tableName,
        columns: ['operation_id'],
        where: 'priority = ?',
        whereArgs: [priority.value],
        orderBy: 'queued_at ASC',
        limit: count,
      );
      
      if (operations.isEmpty) return 0;
      
      final idsToRemove = operations.map((op) => op['operation_id'] as String).toList();
      return await removeOperations(idsToRemove);
    } catch (e) {
      throw StorageException('Failed to evict oldest operations', e);
    }
  }

  @override
  Future<int> getTotalOperationCount() async {
    final db = await _db;
    
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      throw StorageException('Failed to get total operation count', e);
    }
  }

  @override
  Future<void> clearAll() async {
    final db = await _db;
    
    try {
      await db.delete(_tableName);
    } catch (e) {
      throw StorageException('Failed to clear all operations', e);
    }
  }

  @override
  Future<void> dispose() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _isInitialized = false;
  }

  /// Converts database row to QueuedOperation
  QueuedOperation _mapToOperation(Map<String, dynamic> map) {
    return QueuedOperation(
      operationId: map['operation_id'] as String,
      operationType: map['operation_type'] as String,
      priority: _priorityFromValue(map['priority'] as int),
      commandData: map['command_data'] as List<int>,
      queuedAt: map['queued_at'] as int,
      attempts: map['attempts'] as int,
      lastError: map['last_error'] as String?,
    );
  }

  /// Converts numeric priority value to enum
  QueuePriority _priorityFromValue(int value) {
    switch (value) {
      case 3:
        return QueuePriority.high;
      case 2:
        return QueuePriority.normal;
      case 1:
        return QueuePriority.low;
      default:
        return QueuePriority.normal; // Default fallback
    }
  }
}