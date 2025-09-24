/// Resource limits configuration for MerkleKV client.
///
/// This is an optional, declarative set of resource limit inputs that can be
/// supplied by the application. At present these values are not enforced by
/// the library (no-ops), but are plumbed through the configuration and
/// validated for basic correctness so future implementations can honor them.
class ResourceLimits {
  /// Maximum resident memory usage allowed for the client, in bytes.
  final int? memoryLimitBytes;

  /// Maximum persistent storage usage (on-disk) for the client, in bytes.
  final int? storageLimitBytes;

  /// Maximum upload bandwidth, in kilobits per second.
  final int? networkUploadKbps;

  /// Maximum download bandwidth, in kilobits per second.
  final int? networkDownloadKbps;

  /// Maximum CPU usage as an integer percentage (1-100).
  final int? cpuLimitPercent;

  /// Maximum read IOPS (I/O operations per second).
  final int? ioReadIops;

  /// Maximum write IOPS (I/O operations per second).
  final int? ioWriteIops;

  /// Upper bound for concurrent internal operations.
  final int? maxConcurrentOperations;

  /// Max MQTT messages the client may publish per second.
  final int? mqttMaxMessagesPerSecond;

  /// Maximum size of the outbox queue on disk, in bytes.
  final int? outboxMaxBytes;

  /// Maximum size of any in-memory caches/buffers, in bytes.
  final int? inMemoryCacheMaxBytes;

  const ResourceLimits({
    this.memoryLimitBytes,
    this.storageLimitBytes,
    this.networkUploadKbps,
    this.networkDownloadKbps,
    this.cpuLimitPercent,
    this.ioReadIops,
    this.ioWriteIops,
    this.maxConcurrentOperations,
    this.mqttMaxMessagesPerSecond,
    this.outboxMaxBytes,
    this.inMemoryCacheMaxBytes,
  });

  /// Returns a copy with any provided fields overridden.
  ResourceLimits copyWith({
    int? memoryLimitBytes,
    int? storageLimitBytes,
    int? networkUploadKbps,
    int? networkDownloadKbps,
    int? cpuLimitPercent,
    int? ioReadIops,
    int? ioWriteIops,
    int? maxConcurrentOperations,
    int? mqttMaxMessagesPerSecond,
    int? outboxMaxBytes,
    int? inMemoryCacheMaxBytes,
  }) {
    return ResourceLimits(
      memoryLimitBytes: memoryLimitBytes ?? this.memoryLimitBytes,
      storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
      networkUploadKbps: networkUploadKbps ?? this.networkUploadKbps,
      networkDownloadKbps: networkDownloadKbps ?? this.networkDownloadKbps,
      cpuLimitPercent: cpuLimitPercent ?? this.cpuLimitPercent,
      ioReadIops: ioReadIops ?? this.ioReadIops,
      ioWriteIops: ioWriteIops ?? this.ioWriteIops,
      maxConcurrentOperations:
          maxConcurrentOperations ?? this.maxConcurrentOperations,
      mqttMaxMessagesPerSecond:
          mqttMaxMessagesPerSecond ?? this.mqttMaxMessagesPerSecond,
      outboxMaxBytes: outboxMaxBytes ?? this.outboxMaxBytes,
      inMemoryCacheMaxBytes:
          inMemoryCacheMaxBytes ?? this.inMemoryCacheMaxBytes,
    );
  }

  /// Basic validation for non-negative numeric values and percentage bounds.
  void validate() {
    bool _nonNegative(String name, int? v) {
      if (v == null) return true;
      if (v < 0) {
        throw ArgumentError('$name must be non-negative');
      }
      return true;
    }

    _nonNegative('memoryLimitBytes', memoryLimitBytes);
    _nonNegative('storageLimitBytes', storageLimitBytes);
    _nonNegative('networkUploadKbps', networkUploadKbps);
    _nonNegative('networkDownloadKbps', networkDownloadKbps);
    _nonNegative('ioReadIops', ioReadIops);
    _nonNegative('ioWriteIops', ioWriteIops);
    _nonNegative('maxConcurrentOperations', maxConcurrentOperations);
    _nonNegative('mqttMaxMessagesPerSecond', mqttMaxMessagesPerSecond);
    _nonNegative('outboxMaxBytes', outboxMaxBytes);
    _nonNegative('inMemoryCacheMaxBytes', inMemoryCacheMaxBytes);

    if (cpuLimitPercent != null) {
      if (cpuLimitPercent! <= 0 || cpuLimitPercent! > 100) {
        throw ArgumentError('cpuLimitPercent must be in 1..100');
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'memoryLimitBytes': memoryLimitBytes,
      'storageLimitBytes': storageLimitBytes,
      'networkUploadKbps': networkUploadKbps,
      'networkDownloadKbps': networkDownloadKbps,
      'cpuLimitPercent': cpuLimitPercent,
      'ioReadIops': ioReadIops,
      'ioWriteIops': ioWriteIops,
      'maxConcurrentOperations': maxConcurrentOperations,
      'mqttMaxMessagesPerSecond': mqttMaxMessagesPerSecond,
      'outboxMaxBytes': outboxMaxBytes,
      'inMemoryCacheMaxBytes': inMemoryCacheMaxBytes,
    };
  }

  static ResourceLimits fromJson(Map<String, dynamic> json) {
    return ResourceLimits(
      memoryLimitBytes: json['memoryLimitBytes'] as int?,
      storageLimitBytes: json['storageLimitBytes'] as int?,
      networkUploadKbps: json['networkUploadKbps'] as int?,
      networkDownloadKbps: json['networkDownloadKbps'] as int?,
      cpuLimitPercent: json['cpuLimitPercent'] as int?,
      ioReadIops: json['ioReadIops'] as int?,
      ioWriteIops: json['ioWriteIops'] as int?,
      maxConcurrentOperations: json['maxConcurrentOperations'] as int?,
      mqttMaxMessagesPerSecond:
          json['mqttMaxMessagesPerSecond'] as int?,
      outboxMaxBytes: json['outboxMaxBytes'] as int?,
      inMemoryCacheMaxBytes: json['inMemoryCacheMaxBytes'] as int?,
    );
  }

  @override
  String toString() {
    return 'ResourceLimits('
        'mem: $memoryLimitBytes, storage: $storageLimitBytes, '
        'netUp: $networkUploadKbps, netDown: $networkDownloadKbps, '
        'cpu%: $cpuLimitPercent, ioR: $ioReadIops, ioW: $ioWriteIops, '
        'concurrency: $maxConcurrentOperations, mqttRps: $mqttMaxMessagesPerSecond, '
        'outbox: $outboxMaxBytes, cache: $inMemoryCacheMaxBytes)';
  }
}
