/// Base exception class for MerkleKV operations.
///
/// All MerkleKV-specific exceptions extend this class to provide
/// structured error handling with specific exception types per Locked Spec §12.
abstract class MerkleKVException implements Exception {
  /// Human-readable error message
  final String message;

  /// Optional underlying cause of the exception
  final Object? cause;

  /// Stack trace when exception occurred
  final StackTrace? stackTrace;

  const MerkleKVException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => 'MerkleKVException: $message';
}

/// Exception thrown when connection-related operations fail.
///
/// This includes failures to connect, disconnect, or perform operations
/// when the client is not connected and offline queue is disabled.
class ConnectionException extends MerkleKVException {
  /// Connection state when the error occurred
  final String? connectionState;

  const ConnectionException(
    super.message, {
    this.connectionState,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'ConnectionException: $message';
}

/// Exception thrown when input validation fails.
///
/// This includes invalid key lengths, unsupported characters,
/// or malformed parameters.
class ValidationException extends MerkleKVException {
  /// The parameter or field that failed validation
  final String? field;

  /// The invalid value that caused the validation failure
  final dynamic value;

  const ValidationException(
    super.message, {
    this.field,
    this.value,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception thrown when an operation times out.
///
/// Timeouts are enforced per Locked Spec with different durations
/// for single-key (10s), multi-key (20s), and sync operations (30s).
class TimeoutException extends MerkleKVException {
  /// The operation that timed out
  final String operation;

  /// Timeout duration in milliseconds
  final int timeoutMs;

  const TimeoutException(
    super.message, {
    required this.operation,
    required this.timeoutMs,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'TimeoutException: $message (operation: $operation, timeout: ${timeoutMs}ms)';
}

/// Exception thrown when payload size limits are exceeded.
///
/// Enforces UTF-8 byte-size caps per Locked Spec §11:
/// - Key size: ≤256 bytes
/// - Value size: ≤256 KiB
/// - Command payload: ≤512 KiB
/// - CBOR replication payload: ≤300 KiB
class PayloadException extends MerkleKVException {
  /// The type of payload that exceeded limits
  final String payloadType;

  /// Actual payload size in bytes
  final int actualSize;

  /// Maximum allowed size in bytes
  final int maxSize;

  const PayloadException(
    super.message, {
    required this.payloadType,
    required this.actualSize,
    required this.maxSize,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 
      'PayloadException: $message (type: $payloadType, actual: ${actualSize}B, max: ${maxSize}B)';
}

/// Exception thrown for internal errors or unexpected states.
///
/// This should be used sparingly and typically indicates a bug
/// or unrecoverable internal state.
class InternalException extends MerkleKVException {
  /// Error code for categorization
  final int? errorCode;

  const InternalException(
    super.message, {
    this.errorCode,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'InternalException: $message';
}

/// Exception thrown when an operation is not supported.
///
/// This can occur when attempting to use features that are not
/// available in the current configuration or runtime environment.
class UnsupportedOperationException extends MerkleKVException {
  /// The operation that is not supported
  final String operation;

  const UnsupportedOperationException(
    super.message, {
    required this.operation,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'UnsupportedOperationException: $message (operation: $operation)';
}