import 'dart:convert';
import 'dart:typed_data';

import 'exceptions.dart';

/// Utility class for validating MerkleKV inputs according to Locked Spec §11.
///
/// Enforces UTF-8 byte-size caps:
/// - Key size: ≤256 bytes
/// - Value size: ≤256 KiB (262,144 bytes)
/// - Command payload: ≤512 KiB (524,288 bytes)
/// - CBOR replication payload: ≤300 KiB (307,200 bytes)
class InputValidator {
  /// Maximum key size in UTF-8 bytes (Locked Spec §11)
  static const int maxKeyBytes = 256;

  /// Maximum value size in UTF-8 bytes (Locked Spec §11)
  static const int maxValueBytes = 262144; // 256 KiB

  /// Maximum command payload size in UTF-8 bytes (Locked Spec §11)
  static const int maxCommandPayloadBytes = 524288; // 512 KiB

  /// Maximum CBOR replication payload size in UTF-8 bytes (Locked Spec §11)
  static const int maxCborPayloadBytes = 307200; // 300 KiB

  /// Validates a key string according to Locked Spec §11.
  ///
  /// Throws [ValidationException] if:
  /// - Key is null or empty
  /// - Key exceeds 256 UTF-8 bytes
  /// - Key contains invalid characters
  static void validateKey(String? key) {
    if (key == null || key.isEmpty) {
      throw const ValidationException(
        'Key cannot be null or empty',
        field: 'key',
        value: null,
      );
    }

    final keyBytes = utf8.encode(key);
    if (keyBytes.length > maxKeyBytes) {
      throw ValidationException(
        'Key exceeds maximum size of $maxKeyBytes UTF-8 bytes',
        field: 'key',
        value: key,
      );
    }

    // Validate key characters (avoid control characters and null bytes)
    if (key.contains('\u0000')) {
      throw ValidationException(
        'Key cannot contain null characters',
        field: 'key',
        value: key,
      );
    }

    // Check for other control characters that might cause issues
    if (key.codeUnits.any((code) => code < 32 && code != 9 && code != 10 && code != 13)) {
      throw ValidationException(
        'Key contains invalid control characters',
        field: 'key',
        value: key,
      );
    }
  }

  /// Validates a value string according to Locked Spec §11.
  ///
  /// Throws [ValidationException] if value exceeds 256 KiB UTF-8 bytes.
  /// Null values are allowed for deletion operations.
  static void validateValue(String? value) {
    if (value == null) {
      return; // Null values are allowed for deletion
    }

    final valueBytes = utf8.encode(value);
    if (valueBytes.length > maxValueBytes) {
      throw ValidationException(
        'Value exceeds maximum size of $maxValueBytes UTF-8 bytes (${_formatBytes(maxValueBytes)})',
        field: 'value',
        value: value,
      );
    }
  }

  /// Validates a list of keys for bulk operations.
  ///
  /// Throws [ValidationException] if:
  /// - Keys list is null or empty
  /// - Any key is invalid
  /// - Total payload would exceed limits
  static void validateKeys(List<String>? keys) {
    if (keys == null || keys.isEmpty) {
      throw const ValidationException(
        'Keys list cannot be null or empty',
        field: 'keys',
        value: null,
      );
    }

    // Validate each key individually
    for (int i = 0; i < keys.length; i++) {
      try {
        validateKey(keys[i]);
      } catch (e) {
        throw ValidationException(
          'Invalid key at index $i: ${e.toString()}',
          field: 'keys[$i]',
          value: keys[i],
        );
      }
    }

    // Check total payload size
    final totalBytes = _calculateKeysPayloadSize(keys);
    if (totalBytes > maxCommandPayloadBytes) {
      throw ValidationException(
        'Keys payload exceeds maximum size of $maxCommandPayloadBytes UTF-8 bytes (${_formatBytes(maxCommandPayloadBytes)})',
        field: 'keys',
        value: keys,
      );
    }
  }

  /// Validates key-value pairs for bulk set operations.
  ///
  /// Throws [ValidationException] if:
  /// - Map is null or empty
  /// - Any key or value is invalid
  /// - Total payload would exceed limits
  static void validateKeyValues(Map<String, String>? keyValues) {
    if (keyValues == null || keyValues.isEmpty) {
      throw const ValidationException(
        'Key-value map cannot be null or empty',
        field: 'keyValues',
        value: null,
      );
    }

    int totalBytes = 0;

    // Validate each key-value pair
    keyValues.forEach((key, value) {
      validateKey(key);
      validateValue(value);
      
      totalBytes += utf8.encode(key).length;
      totalBytes += utf8.encode(value).length;
    });

    // Check total payload size
    if (totalBytes > maxCommandPayloadBytes) {
      throw ValidationException(
        'Key-value payload exceeds maximum size of $maxCommandPayloadBytes UTF-8 bytes (${_formatBytes(maxCommandPayloadBytes)})',
        field: 'keyValues',
        value: keyValues,
      );
    }
  }

  /// Validates a numeric amount for increment/decrement operations.
  ///
  /// Throws [ValidationException] if amount would cause integer overflow.
  static void validateAmount(int amount) {
    // Check for potential overflow scenarios
    // Dart's int is 64-bit signed, so we check against its actual bounds
    const maxInt64 = 9223372036854775807; // 2^63 - 1
    const minInt64 = -9223372036854775808; // -2^63

    if (amount > maxInt64 || amount < minInt64) {
      throw ValidationException(
        'Amount exceeds 64-bit integer bounds',
        field: 'amount',
        value: amount,
      );
    }
  }

  /// Validates command payload size for network transmission.
  ///
  /// Throws [PayloadException] if the serialized command would exceed limits.
  static void validateCommandPayload(Uint8List payload) {
    if (payload.length > maxCommandPayloadBytes) {
      throw PayloadException(
        'Command payload exceeds maximum size',
        payloadType: 'command',
        actualSize: payload.length,
        maxSize: maxCommandPayloadBytes,
      );
    }
  }

  /// Validates CBOR payload size for replication events.
  ///
  /// Throws [PayloadException] if the CBOR payload would exceed limits.
  static void validateCborPayload(Uint8List payload) {
    if (payload.length > maxCborPayloadBytes) {
      throw PayloadException(
        'CBOR payload exceeds maximum size',
        payloadType: 'cbor',
        actualSize: payload.length,
        maxSize: maxCborPayloadBytes,
      );
    }
  }

  /// Validates a client ID or node ID.
  ///
  /// Throws [ValidationException] if:
  /// - ID is null or empty
  /// - ID exceeds reasonable length
  /// - ID contains invalid characters
  static void validateIdentifier(String? id, String fieldName) {
    if (id == null || id.isEmpty) {
      throw ValidationException(
        '$fieldName cannot be null or empty',
        field: fieldName,
        value: id,
      );
    }

    if (id.length > 128) {
      throw ValidationException(
        '$fieldName exceeds maximum length of 128 characters',
        field: fieldName,
        value: id,
      );
    }

    // Check for valid identifier characters (alphanumeric, dash, underscore)
    final validPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!validPattern.hasMatch(id)) {
      throw ValidationException(
        '$fieldName contains invalid characters (only alphanumeric, dash, and underscore allowed)',
        field: fieldName,
        value: id,
      );
    }
  }

  /// Calculates the UTF-8 byte size of a keys list for payload validation.
  static int _calculateKeysPayloadSize(List<String> keys) {
    int totalBytes = 0;
    for (final key in keys) {
      totalBytes += utf8.encode(key).length;
    }
    return totalBytes;
  }

  /// Formats byte count in human-readable format.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KiB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MiB';
    }
  }
}

/// Utility functions for common validation patterns.
extension ValidationExtensions on String? {
  /// Validates this string as a key.
  void validateAsKey() => InputValidator.validateKey(this);

  /// Validates this string as a value.
  void validateAsValue() => InputValidator.validateValue(this);

  /// Validates this string as an identifier.
  void validateAsIdentifier(String fieldName) => 
      InputValidator.validateIdentifier(this, fieldName);
}

extension KeyListValidation on List<String>? {
  /// Validates this list as a keys list.
  void validateAsKeys() => InputValidator.validateKeys(this);
}

extension KeyValueMapValidation on Map<String, String>? {
  /// Validates this map as key-value pairs.
  void validateAsKeyValues() => InputValidator.validateKeyValues(this);
}