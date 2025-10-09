/// Rich connection log model for streaming to UIs.
class ConnectionLogEntry {
  final DateTime timestamp;
  final String level; // DEBUG, INFO, WARN, ERROR
  final String message;
  final String? tag; // optional category/module tag
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?>? context; // optional structured context

  const ConnectionLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
    this.context,
  });

  Map<String, Object?> toJson() => {
        'ts': timestamp.toIso8601String(),
        'level': level,
        'message': message,
        if (tag != null) 'tag': tag,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (context != null) 'context': context,
      };
}

/// Tiny ANSI color helper for spicy, vibrant console output.
class Ansi {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
  static const italic = '\x1B[3m';
  static const underline = '\x1B[4m';
  static const blink = '\x1B[5m';
  static const inverse = '\x1B[7m';

  static const black = '\x1B[30m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';

  static const bgRed = '\x1B[41m';
  static const bgGreen = '\x1B[42m';
  static const bgYellow = '\x1B[43m';
  static const bgBlue = '\x1B[44m';
  static const bgMagenta = '\x1B[45m';
  static const bgCyan = '\x1B[46m';
  static const bgWhite = '\x1B[47m';
}

/// Format a [ConnectionLogEntry] to an ANSI, eye-catching string.
String formatAnsi(ConnectionLogEntry e) {
  final ts = e.timestamp.toIso8601String();
  final tag = e.tag != null ? ' ${Ansi.dim}[${e.tag}]${Ansi.reset}' : '';
  final base = '${Ansi.bold}$ts${Ansi.reset} $tag ${e.message}';
  switch (e.level) {
    case 'DEBUG':
      return '${Ansi.cyan}${Ansi.dim}◈ DEBUG${Ansi.reset} $base';
    case 'INFO':
      return '${Ansi.green}${Ansi.bold}✔ INFO ${Ansi.reset} $base';
    case 'WARN':
      return '${Ansi.yellow}${Ansi.bold}${Ansi.bgBlue}⚠ WARN ${Ansi.reset} $base';
    case 'ERROR':
      final errLine = e.error != null
          ? '\n${Ansi.red}${Ansi.bold}↳ Error:${Ansi.reset} ${e.error}'
          : '';
      final stLine = e.stackTrace != null
          ? '\n${Ansi.magenta}${Ansi.dim}↳ Stack:${Ansi.reset} ${e.stackTrace}'
          : '';
      return '${Ansi.bgRed}${Ansi.white}${Ansi.bold}✖ ERROR${Ansi.reset} $base$errLine$stLine';
    default:
      return '$base';
  }
}
