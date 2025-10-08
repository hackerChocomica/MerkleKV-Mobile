/// Simple logging interface for the connection lifecycle manager.
/// 
/// This provides a lightweight abstraction over logging that can be 
/// configured or replaced as needed without changing the core implementation.
import 'dart:async';

import 'log_entry.dart';

abstract class ConnectionLogger {
  /// Log a debug message.
  void debug(String message);
  
  /// Log an informational message.
  void info(String message);
  
  /// Log a warning message.
  void warn(String message);
  
  /// Log an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Default implementation that outputs to console with timestamps.
/// 
/// In production, this could be replaced with package:logging or
/// another logging framework integration.
class DefaultConnectionLogger implements ConnectionLogger {
  final String prefix;
  final bool enableDebug;
  
  const DefaultConnectionLogger({
    this.prefix = 'ConnectionLifecycle',
    this.enableDebug = true,
  });
  
  @override
  void debug(String message) {
    if (enableDebug) {
      _log('DEBUG', message);
    }
  }
  
  @override
  void info(String message) {
    _log('INFO', message);
  }
  
  @override
  void warn(String message) {
    _log('WARN', message);
  }
  
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    if (error != null) {
      _log('ERROR', 'Error details: $error');
    }
    if (stackTrace != null) {
      _log('ERROR', 'Stack trace: $stackTrace');
    }
  }
  
  void _log(String level, String message) {
    // ignore: avoid_print
    print('[${DateTime.now().toIso8601String()}] $level $prefix: $message');
  }
}

/// Silent logger implementation for testing or when logging is disabled.
class SilentConnectionLogger implements ConnectionLogger {
  const SilentConnectionLogger();
  
  @override
  void debug(String message) {}
  
  @override
  void info(String message) {}
  
  @override
  void warn(String message) {}
  
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// A streaming logger that blasts vibrant, console-style logs and exposes
/// a broadcast stream for UI consoles. It also keeps a rolling buffer
/// so late subscribers can render recent history instantly.
class StreamConnectionLogger implements ConnectionLogger {
  final String tag;
  final bool enableDebug;
  final int bufferSize;
  final bool mirrorToConsole;

  final StreamController<ConnectionLogEntry> _controller =
      StreamController<ConnectionLogEntry>.broadcast();
  final List<ConnectionLogEntry> _buffer = <ConnectionLogEntry>[];

  StreamConnectionLogger({
    this.tag = 'MQTT-Core',
    this.enableDebug = true,
    this.bufferSize = 500,
    this.mirrorToConsole = true,
  });

  /// A broadcast stream of rich log entries suitable for app UIs.
  Stream<ConnectionLogEntry> get stream => _controller.stream;

  /// Returns a copy of the current rolling buffer (most recent last).
  List<ConnectionLogEntry> get bufferSnapshot => List.unmodifiable(_buffer);

  /// Returns a filtered view of the live stream. Filters are optional and
  /// composed with AND semantics when multiple are provided.
  Stream<ConnectionLogEntry> filtered({
    Set<String>? levels,
    String? tag,
    String? contains,
  }) {
    return stream.where((e) {
      if (levels != null && levels.isNotEmpty && !levels.contains(e.level)) {
        return false;
      }
      if (tag != null && tag.isNotEmpty && e.tag != tag) {
        return false;
      }
      if (contains != null && contains.isNotEmpty) {
        final text = '${e.message} ${e.error ?? ''} ${e.stackTrace ?? ''}';
        if (!text.toLowerCase().contains(contains.toLowerCase())) {
          return false;
        }
      }
      return true;
    });
  }

  /// Clears the rolling buffer. Does not affect the live stream.
  void clear() {
    _buffer.clear();
  }

  void _emit(ConnectionLogEntry e) {
    // Maintain rolling buffer
    _buffer.add(e);
    if (_buffer.length > bufferSize) {
      _buffer.removeRange(0, _buffer.length - bufferSize);
    }
    // Emit to subscribers
    if (!_controller.isClosed) {
      _controller.add(e);
    }
    // Optional console mirror with color
    if (mirrorToConsole) {
      // ignore: avoid_print
      print(formatAnsi(e));
    }
  }

  @override
  void debug(String message) {
    if (!enableDebug) return;
    _emit(ConnectionLogEntry(
      timestamp: DateTime.now(),
      level: 'DEBUG',
      message: message,
      tag: tag,
    ));
  }

  @override
  void info(String message) {
    _emit(ConnectionLogEntry(
      timestamp: DateTime.now(),
      level: 'INFO',
      message: message,
      tag: tag,
    ));
  }

  @override
  void warn(String message) {
    _emit(ConnectionLogEntry(
      timestamp: DateTime.now(),
      level: 'WARN',
      message: message,
      tag: tag,
    ));
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _emit(ConnectionLogEntry(
      timestamp: DateTime.now(),
      level: 'ERROR',
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  /// Close the stream when the logger is disposed.
  Future<void> dispose() async {
    await _controller.close();
  }
}