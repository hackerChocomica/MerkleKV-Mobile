## Offline Operation Queue - API Examples

### Basic Usage

```dart
import 'package:merkle_kv_core/merkle_kv_core.dart';

// Create and initialize the offline queue
final queue = OfflineOperationQueue();
await queue.initialize();

// Queue a command when offline
final command = Command(
  id: 'cmd-123',
  op: 'SET',
  key: 'user:john',
  value: 'John Smith',
);

final operationId = await queue.queueOperation(
  command,
  priority: QueuePriority.high,
);

// Check queue status
final stats = await queue.getStats();
print('Operations in queue: ${stats.totalOperations}');
print('High priority: ${stats.operationsByPriority[QueuePriority.high]}');
```

### Configuration Options

```dart
// Custom configuration
final config = OfflineQueueConfig(
  maxOperations: 5000,           // Limit queue to 5,000 operations
  maxAge: Duration(days: 3),     // Expire operations after 3 days
  defaultPriority: QueuePriority.normal,
  maxRetryAttempts: 5,           // Retry failed operations 5 times
  batchSize: 25,                 // Process 25 operations per batch
);

final queue = OfflineOperationQueue(config: config);
await queue.initialize();
```

### Priority Management

```dart
// Different priority levels
await queue.queueOperation(userCommand, priority: QueuePriority.high);    // User action
await queue.queueOperation(syncCommand, priority: QueuePriority.normal);  // Background sync
await queue.queueOperation(cleanupCommand, priority: QueuePriority.low);  // Cleanup task

// Processing order: High → Normal → Low
// Within each priority: FIFO (first-in, first-out)
```

### Connection State Management

```dart
// Monitor connection state
queue.isConnected = false;  // Queue operations offline
// ... operations are stored persistently

queue.isConnected = true;   // Trigger processing when online
// ... operations are processed automatically in priority order
```

### Monitoring and Statistics

```dart
// Get current queue statistics
final stats = await queue.getStats();

print('Total operations: ${stats.totalOperations}');
print('High priority: ${stats.operationsByPriority[QueuePriority.high]}');
print('Normal priority: ${stats.operationsByPriority[QueuePriority.normal]}');
print('Low priority: ${stats.operationsByPriority[QueuePriority.low]}');
print('Total processed: ${stats.totalProcessed}');
print('Total failed: ${stats.totalFailed}');
print('Total dropped: ${stats.totalDropped}');

if (stats.oldestOperationAge != null) {
  print('Oldest operation: ${stats.oldestOperationAge!.inMinutes} minutes old');
}

// Stream statistics for real-time monitoring
queue.statsStream.listen((stats) {
  print('Queue size changed: ${stats.totalOperations}');
});
```

### Manual Operation Management

```dart
// Remove a specific operation
final removed = await queue.removeOperation('operation-id-123');

// Clear all operations (for testing or reset)
await queue.clear();
```

### Custom Storage Implementation

```dart
// Use custom storage backend
class MyCustomStorage implements QueueStorageInterface {
  // ... implement all required methods
}

final queue = OfflineOperationQueue(
  storage: MyCustomStorage(),
);
```

### Cleanup and Disposal

```dart
// Always dispose when done
await queue.dispose();
```

## Architecture Overview

### Separation from Replication Outbox

The offline operation queue is **distinct** from the replication outbox:

- **Offline Queue**: Stores user commands (SET, GET, DELETE) when device is offline
- **Replication Outbox**: Stores replication events for eventual consistency

### Priority System

1. **High Priority**: User-initiated operations requiring immediate feedback
   - User clicks, form submissions, critical updates
   - Processed first when connection is restored

2. **Normal Priority**: Background operations with eventual consistency
   - Automatic syncs, periodic updates
   - Default priority level

3. **Low Priority**: Cleanup and maintenance operations
   - Log cleanup, cache optimization, non-critical updates
   - Processed last, can be evicted if queue is full

### Persistence Strategy

- Uses SQLite for reliable cross-restart persistence
- Operations survive app crashes and device reboots
- Efficient indexing for priority-based retrieval
- Automatic cleanup of expired operations

### Capacity Management

- Configurable maximum operation count (default: 10,000)
- Automatic eviction when capacity is reached:
  1. Remove expired operations first
  2. Remove oldest low-priority operations
  3. Remove oldest normal-priority operations
  4. Remove oldest high-priority operations (last resort)

### Error Handling and Retries

- Configurable retry attempts (default: 3)
- Exponential backoff with jitter
- Permanent failure handling after max retries
- Graceful degradation on storage errors

## Performance Characteristics

- **Memory Usage**: Operations stored on disk, minimal memory footprint
- **Startup Time**: Fast initialization, loads metadata only
- **Processing**: Batched processing for efficiency (default: 50 operations per batch)
- **Storage**: SQLite with proper indexing for fast priority-based queries

## Integration with MerkleKV

The offline queue integrates seamlessly with the existing MerkleKV architecture:

1. **Command Processing**: Queued operations use the same Command structure
2. **MQTT Integration**: Automatic processing when MQTT connection is available  
3. **Timeout Management**: Respects existing timeout policies
4. **Metrics**: Integrates with existing metrics collection
5. **Configuration**: Uses the same configuration system