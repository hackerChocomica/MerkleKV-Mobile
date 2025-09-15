import 'dart:math';

/// Utility class for generating UUIDs and unique identifiers.
///
/// Provides methods for generating UUIDv4 identifiers for command correlation
/// and other purposes within MerkleKV operations.
class UuidGenerator {
  static final Random _random = Random.secure();

  /// Generates a UUIDv4 string.
  ///
  /// Returns a randomly generated UUID in the standard format:
  /// xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  ///
  /// Where:
  /// - x is any hexadecimal digit
  /// - y is one of 8, 9, A, or B
  /// - The version number (4) is in the third group
  static String generate() {
    // Generate 16 random bytes
    final bytes = List<int>.generate(16, (i) => _random.nextInt(256));
    
    // Set version (4) and variant bits according to RFC 4122
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // Variant bits
    
    // Convert to hex string with dashes
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    
    return '${hex.substring(0, 8)}-'
           '${hex.substring(8, 12)}-'
           '${hex.substring(12, 16)}-'
           '${hex.substring(16, 20)}-'
           '${hex.substring(20, 32)}';
  }

  /// Generates a short unique identifier (8 characters).
  ///
  /// Useful for generating shorter IDs when full UUIDs are not needed.
  /// Not guaranteed to be globally unique, but suitable for local operations.
  static String generateShort() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (index) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Validates if a string is a valid UUID format.
  ///
  /// Returns true if the string matches the UUID pattern, false otherwise.
  static bool isValidUuid(String? uuid) {
    if (uuid == null) return false;
    
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    
    return uuidRegex.hasMatch(uuid);
  }
}