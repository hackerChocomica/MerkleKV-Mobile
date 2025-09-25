import 'dart:developer' as developer;

/// Simple logging utility for consistent log formatting
class Logger {
  final String _name;
  
  Logger(this._name);
  
  /// Log info level message
  void info(String message) {
    developer.log(message, name: _name, level: 800);
  }
  
  /// Log warning level message
  void warning(String message) {
    developer.log(message, name: _name, level: 900);
  }
  
  /// Log severe/error level message
  void severe(String message) {
    developer.log(message, name: _name, level: 1000);
  }
  
  /// Log fine level message (debug)
  void fine(String message) {
    developer.log(message, name: _name, level: 500);
  }
}