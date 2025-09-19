import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../scenarios/e2e_scenario.dart';
import 'test_session_manager.dart';

/// Aggregates and manages test results, providing reporting and analysis capabilities
class TestResultAggregator {
  final List<TestSessionResult> _results = [];
  final String _outputDirectory;

  TestResultAggregator({String? outputDirectory})
      : _outputDirectory = outputDirectory ?? 'test_results';

  /// Record a successful test execution
  Future<void> recordSuccess(TestSession session, dynamic result) async {
    final sessionResult = TestSessionResult(
      session: session,
      success: true,
      result: result,
      timestamp: DateTime.now(),
    );

    _results.add(sessionResult);
    
    print('✅ Recorded successful test: ${session.scenario.name}');
    await _writeResultToFile(sessionResult);
  }

  /// Record a failed test execution
  Future<void> recordFailure(
    TestSession session,
    dynamic error,
    StackTrace? stackTrace,
  ) async {
    final sessionResult = TestSessionResult(
      session: session,
      success: false,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );

    _results.add(sessionResult);
    
    print('❌ Recorded failed test: ${session.scenario.name}');
    print('   Error: $error');
    
    await _writeResultToFile(sessionResult);
  }

  /// Generate comprehensive test report
  Future<TestReport> generateReport() async {
    final report = TestReport(
      results: List.from(_results),
      generatedAt: DateTime.now(),
    );

    await _writeReportToFile(report);
    return report;
  }

  /// Get test statistics
  TestStatistics getStatistics() {
    final totalTests = _results.length;
    final passedTests = _results.where((r) => r.success).length;
    final failedTests = totalTests - passedTests;
    
    final totalDuration = _results.fold<Duration>(
      Duration.zero,
      (sum, result) => sum + result.session.duration,
    );

    return TestStatistics(
      totalTests: totalTests,
      passedTests: passedTests,
      failedTests: failedTests,
      passRate: totalTests > 0 ? (passedTests / totalTests) * 100 : 0.0,
      totalDuration: totalDuration,
      averageDuration: totalTests > 0 
          ? Duration(milliseconds: totalDuration.inMilliseconds ~/ totalTests)
          : Duration.zero,
    );
  }

  /// Write individual result to file
  Future<void> _writeResultToFile(TestSessionResult result) async {
    try {
      final directory = Directory(_outputDirectory);
      await directory.create(recursive: true);

      final fileName = '${result.session.id}_${result.timestamp.millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final json = {
        'sessionId': result.session.id,
        'scenarioName': result.session.scenario.name,
        'success': result.success,
        'timestamp': result.timestamp.toIso8601String(),
        'duration': result.session.duration.inMilliseconds,
        'metadata': result.session.metadata,
        if (!result.success) ...{
          'error': result.error?.toString(),
          'stackTrace': result.stackTrace?.toString(),
        },
        if (result.success && result.result != null) ...{
          'result': _serializeResult(result.result),
        },
      };

      await file.writeAsString(jsonEncode(json));
      
    } catch (error) {
      print('⚠️ Warning: Failed to write result to file: $error');
    }
  }

  /// Write comprehensive report to file
  Future<void> _writeReportToFile(TestReport report) async {
    try {
      final directory = Directory(_outputDirectory);
      await directory.create(recursive: true);

      final fileName = 'test_report_${report.generatedAt.millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final statistics = getStatistics();
      
      final json = {
        'generatedAt': report.generatedAt.toIso8601String(),
        'statistics': {
          'totalTests': statistics.totalTests,
          'passedTests': statistics.passedTests,
          'failedTests': statistics.failedTests,
          'passRate': statistics.passRate,
          'totalDuration': statistics.totalDuration.inMilliseconds,
          'averageDuration': statistics.averageDuration.inMilliseconds,
        },
        'results': report.results.map((result) => {
          'sessionId': result.session.id,
          'scenarioName': result.session.scenario.name,
          'success': result.success,
          'timestamp': result.timestamp.toIso8601String(),
          'duration': result.session.duration.inMilliseconds,
        }).toList(),
      };

      await file.writeAsString(jsonEncode(json));
      
      // Also write human-readable summary
      await _writeHumanReadableReport(report, statistics);
      
    } catch (error) {
      print('⚠️ Warning: Failed to write report to file: $error');
    }
  }

  /// Write human-readable report
  Future<void> _writeHumanReadableReport(TestReport report, TestStatistics stats) async {
    try {
      final fileName = 'test_summary_${report.generatedAt.millisecondsSinceEpoch}.txt';
      final file = File('$_outputDirectory/$fileName');

      final buffer = StringBuffer();
      buffer.writeln('Mobile E2E Test Report');
      buffer.writeln('Generated: ${report.generatedAt}');
      buffer.writeln('');
      buffer.writeln('SUMMARY');
      buffer.writeln('=======');
      buffer.writeln('Total Tests: ${stats.totalTests}');
      buffer.writeln('Passed: ${stats.passedTests}');
      buffer.writeln('Failed: ${stats.failedTests}');
      buffer.writeln('Pass Rate: ${stats.passRate.toStringAsFixed(1)}%');
      buffer.writeln('Total Duration: ${_formatDuration(stats.totalDuration)}');
      buffer.writeln('Average Duration: ${_formatDuration(stats.averageDuration)}');
      buffer.writeln('');

      if (stats.failedTests > 0) {
        buffer.writeln('FAILED TESTS');
        buffer.writeln('============');
        for (final result in report.results.where((r) => !r.success)) {
          buffer.writeln('${result.session.scenario.name}');
          buffer.writeln('  Error: ${result.error}');
          buffer.writeln('  Duration: ${_formatDuration(result.session.duration)}');
          buffer.writeln('');
        }
      }

      buffer.writeln('ALL TESTS');
      buffer.writeln('=========');
      for (final result in report.results) {
        final status = result.success ? 'PASS' : 'FAIL';
        final duration = _formatDuration(result.session.duration);
        buffer.writeln('[$status] ${result.session.scenario.name} ($duration)');
      }

      await file.writeAsString(buffer.toString());
      
    } catch (error) {
      print('⚠️ Warning: Failed to write human-readable report: $error');
    }
  }

  /// Serialize test result for JSON output
  Map<String, dynamic> _serializeResult(dynamic result) {
    try {
      if (result == null) return {};
      
      // Handle common result types
      if (result is Map<String, dynamic>) return result;
      if (result is List) return {'items': result};
      if (result is String) return {'value': result};
      if (result is num) return {'value': result};
      if (result is bool) return {'value': result};
      
      // Try to convert to string representation
      return {'toString': result.toString()};
      
    } catch (error) {
      return {'serializationError': error.toString()};
    }
  }

  /// Format duration for human reading
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s';
    }
  }

  /// Clear all results
  void clearResults() {
    _results.clear();
  }

  /// Get all results
  List<TestSessionResult> get results => List.unmodifiable(_results);
}

/// Result of a test session execution
class TestSessionResult {
  final TestSession session;
  final bool success;
  final dynamic result;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  TestSessionResult({
    required this.session,
    required this.success,
    this.result,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });
}

/// Comprehensive test report
class TestReport {
  final List<TestSessionResult> results;
  final DateTime generatedAt;

  TestReport({
    required this.results,
    required this.generatedAt,
  });

  /// Get failed results
  List<TestSessionResult> get failedResults => 
      results.where((r) => !r.success).toList();

  /// Get successful results
  List<TestSessionResult> get successfulResults => 
      results.where((r) => r.success).toList();
}

/// Test execution statistics
class TestStatistics {
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final double passRate;
  final Duration totalDuration;
  final Duration averageDuration;

  TestStatistics({
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.passRate,
    required this.totalDuration,
    required this.averageDuration,
  });

  @override
  String toString() {
    return 'TestStatistics(total: $totalTests, passed: $passedTests, '
           'failed: $failedTests, passRate: ${passRate.toStringAsFixed(1)}%)';
  }
}