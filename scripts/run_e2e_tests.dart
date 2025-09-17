#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Mobile E2E Test Orchestrator Runner
/// Dart implementation for executing E2E test suites
/// Supports integration with mobile_e2e_orchestrator.dart

void main(List<String> arguments) async {
  final runner = E2ETestRunner();
  await runner.run(arguments);
}

class E2ETestRunner {
  late final E2EConfig config;
  late final TestLogger logger;

  Future<void> run(List<String> arguments) async {
    try {
      // Parse command line arguments
      config = E2EConfig.fromArgs(arguments);
      logger = TestLogger(config.verbose);
      
      logger.info('Starting Mobile E2E Test Runner');
      logger.info('Platform: ${config.platform}');
      logger.info('Test Suite: ${config.testSuite}');
      logger.info('Device Pool: ${config.devicePool}');
      
      // Validate configuration
      await validateConfiguration();
      
      // Execute test pipeline
      await executeTestPipeline();
      
      logger.success('All tests completed successfully');
      exit(0);
      
    } catch (e, stackTrace) {
      logger.error('Test execution failed: $e');
      if (config.verbose) {
        logger.error('Stack trace:\n$stackTrace');
      }
      exit(1);
    }
  }

  Future<void> validateConfiguration() async {
    logger.info('Validating configuration...');
    
    // Check if test file exists
    if (config.testFile != null) {
      final testFile = File(config.testFile!);
      if (!await testFile.exists()) {
        throw Exception('Test file not found: ${config.testFile}');
      }
    }
    
    // For lifecycle tests, skip Appium validation if not available
    if (config.testSuite == 'lifecycle' && config.devicePool == 'emulator') {
      logger.info('Skipping Appium validation for lifecycle structure tests');
      logger.success('Configuration validated');
      return;
    }
    
    // Check Appium server
    if (config.devicePool != 'cloud') {
      final appiumHealthy = await checkAppiumServer();
      if (!appiumHealthy) {
        throw Exception('Appium server not responding on port ${config.appiumPort}');
      }
    }
    
    // Check platform-specific requirements
    if (config.platform == 'ios' && !Platform.isMacOS) {
      throw Exception('iOS testing requires macOS');
    }
    
    logger.success('Configuration validated');
  }

  Future<bool> checkAppiumServer() async {
    try {
      final client = HttpClient();
      final request = await client.get('localhost', config.appiumPort, '/status');
      final response = await request.close();
      final isHealthy = response.statusCode == 200;
      client.close();
      return isHealthy;
    } catch (e) {
      return false;
    }
  }

  Future<void> executeTestPipeline() async {
    logger.info('Executing test pipeline...');
    
    // Get test files to execute
    final testFiles = getTestFiles();
    
    final results = <TestResult>[];
    
    for (final testFile in testFiles) {
      logger.info('Executing test: $testFile');
      
      final result = await executeTestFile(testFile);
      results.add(result);
      
      if (!result.passed) {
        logger.error('Test failed: ${result.testName}');
        if (!config.continueOnFailure) {
          break;
        }
      } else {
        logger.success('Test passed: ${result.testName}');
      }
    }
    
    // Generate results summary
    await generateResultsSummary(results);
    
    // Check overall success
    final failedTests = results.where((r) => !r.passed).toList();
    if (failedTests.isNotEmpty) {
      throw Exception('${failedTests.length} test(s) failed');
    }
  }

  List<String> getTestFiles() {
    if (config.testFile != null) {
      return [config.testFile!];
    }
    
    // Determine test files based on test suite
    final baseDir = 'test/e2e';
    switch (config.testSuite) {
      case 'lifecycle':
        return ['$baseDir/tests/mobile_lifecycle_test.dart'];
      case 'network':
        return ['$baseDir/network/network_state_test.dart'];
      case 'convergence':
        return ['$baseDir/convergence/mobile_convergence_test.dart'];
      case 'all':
      default:
        return [
          '$baseDir/tests/mobile_lifecycle_test.dart',
          '$baseDir/network/network_state_test.dart',
          '$baseDir/convergence/mobile_convergence_test.dart',
        ];
    }
  }

  Future<TestResult> executeTestFile(String testFile) async {
    final testName = testFile.split('/').last.replaceAll('.dart', '');
    final startTime = DateTime.now();
    
    try {
      // Create test execution command - run the test file directly
      final args = [
        'run',
        testFile,
        '--platform', config.platform,
        '--device-pool', config.devicePool,
        '--appium-port', config.appiumPort.toString(),
      ];
      
      if (config.cloudProvider != null) {
        args.addAll(['--cloud-provider', config.cloudProvider!]);
      }
      
      if (config.verbose) {
        args.add('--verbose');
      }
      
      // Execute test
      final process = await Process.start('dart', args,
          workingDirectory: '/root/MerkleKV-Mobile');
      
      // Capture output
      final stdout = StringBuffer();
      final stderr = StringBuffer();
      
      process.stdout
          .transform(utf8.decoder)
          .listen((data) {
        stdout.write(data);
        if (config.verbose) {
          print(data.trim());
        }
      });
      
      process.stderr
          .transform(utf8.decoder)
          .listen((data) {
        stderr.write(data);
        if (config.verbose) {
          print(data.trim());
        }
      });
      
      final exitCode = await process.exitCode;
      final duration = DateTime.now().difference(startTime);
      
      // Save test output
      await saveTestOutput(testName, stdout.toString(), stderr.toString());
      
      return TestResult(
        testName: testName,
        passed: exitCode == 0,
        duration: duration,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
        exitCode: exitCode,
      );
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return TestResult(
        testName: testName,
        passed: false,
        duration: duration,
        stdout: '',
        stderr: e.toString(),
        exitCode: -1,
      );
    }
  }

  Future<void> saveTestOutput(String testName, String stdout, String stderr) async {
    final logsDir = Directory('test/e2e/logs');
    await logsDir.create(recursive: true);
    
    // Save stdout
    final stdoutFile = File('${logsDir.path}/${testName}_${config.platform}_stdout.log');
    await stdoutFile.writeAsString(stdout);
    
    // Save stderr
    final stderrFile = File('${logsDir.path}/${testName}_${config.platform}_stderr.log');
    await stderrFile.writeAsString(stderr);
  }

  Future<void> generateResultsSummary(List<TestResult> results) async {
    logger.info('Generating results summary...');
    
    final reportsDir = Directory('test/e2e/reports');
    await reportsDir.create(recursive: true);
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final reportFile = File('${reportsDir.path}/summary_${config.platform}_$timestamp.json');
    
    final summary = {
      'platform': config.platform,
      'testSuite': config.testSuite,
      'devicePool': config.devicePool,
      'timestamp': DateTime.now().toIso8601String(),
      'totalTests': results.length,
      'passedTests': results.where((r) => r.passed).length,
      'failedTests': results.where((r) => !r.passed).length,
      'totalDuration': results.fold<Duration>(
        Duration.zero,
        (sum, result) => sum + result.duration,
      ).inMilliseconds,
      'results': results.map((r) => r.toJson()).toList(),
    };
    
    await reportFile.writeAsString(JsonEncoder.withIndent('  ').convert(summary));
    
    logger.info('Results summary saved: ${reportFile.path}');
    
    // Print summary to console
    logger.info('Test Results Summary:');
    logger.info('  Total: ${results.length}');
    logger.info('  Passed: ${results.where((r) => r.passed).length}');
    logger.info('  Failed: ${results.where((r) => !r.passed).length}');
    
    final totalDuration = results.fold<Duration>(
      Duration.zero,
      (sum, result) => sum + result.duration,
    );
    logger.info('  Duration: ${totalDuration.inSeconds}s');
  }
}

class E2EConfig {
  final String platform;
  final String testSuite;
  final String devicePool;
  final String? cloudProvider;
  final String? testFile;
  final int appiumPort;
  final bool verbose;
  final bool continueOnFailure;

  E2EConfig({
    required this.platform,
    required this.testSuite,
    required this.devicePool,
    this.cloudProvider,
    this.testFile,
    required this.appiumPort,
    required this.verbose,
    required this.continueOnFailure,
  });

  factory E2EConfig.fromArgs(List<String> args) {
    String platform = 'android';
    String testSuite = 'all';
    String devicePool = 'emulator';
    String? cloudProvider;
    String? testFile;
    int appiumPort = 4723;
    bool verbose = false;
    bool continueOnFailure = false;

    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--platform':
          if (i + 1 < args.length) platform = args[++i];
          break;
        case '--test-suite':
          if (i + 1 < args.length) testSuite = args[++i];
          break;
        case '--device-pool':
          if (i + 1 < args.length) devicePool = args[++i];
          break;
        case '--cloud-provider':
          if (i + 1 < args.length) cloudProvider = args[++i];
          break;
        case '--test-file':
          if (i + 1 < args.length) testFile = args[++i];
          break;
        case '--appium-port':
          if (i + 1 < args.length) appiumPort = int.parse(args[++i]);
          break;
        case '--verbose':
          verbose = true;
          break;
        case '--continue-on-failure':
          continueOnFailure = true;
          break;
        case '--help':
          _printHelp();
          exit(0);
      }
    }

    return E2EConfig(
      platform: platform,
      testSuite: testSuite,
      devicePool: devicePool,
      cloudProvider: cloudProvider,
      testFile: testFile,
      appiumPort: appiumPort,
      verbose: verbose,
      continueOnFailure: continueOnFailure,
    );
  }

  static void _printHelp() {
    print('''
Mobile E2E Test Runner (Dart)

Usage: dart run scripts/run_e2e_tests.dart [OPTIONS]

Options:
  --platform PLATFORM        Target platform: android, ios (default: android)
  --test-suite SUITE         Test suite: all, lifecycle, network, convergence (default: all)
  --device-pool POOL         Device pool: emulator, local, cloud (default: emulator)
  --cloud-provider PROVIDER  Cloud provider: browserstack, saucelabs
  --test-file FILE           Specific test file to run
  --appium-port PORT         Appium server port (default: 4723)
  --verbose                  Enable verbose output
  --continue-on-failure      Continue execution even if tests fail
  --help                     Show this help message

Examples:
  dart run scripts/run_e2e_tests.dart --platform android --test-suite all
  dart run scripts/run_e2e_tests.dart --platform ios --test-suite lifecycle --verbose
  dart run scripts/run_e2e_tests.dart --device-pool cloud --cloud-provider browserstack
''');
  }
}

class TestResult {
  final String testName;
  final bool passed;
  final Duration duration;
  final String stdout;
  final String stderr;
  final int exitCode;

  TestResult({
    required this.testName,
    required this.passed,
    required this.duration,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'testName': testName,
      'passed': passed,
      'duration': duration.inMilliseconds,
      'stdout': stdout,
      'stderr': stderr,
      'exitCode': exitCode,
    };
  }
}

class TestLogger {
  final bool verbose;

  TestLogger(this.verbose);

  void info(String message) {
    print('[INFO] $message');
  }

  void success(String message) {
    print('[SUCCESS] $message');
  }

  void warning(String message) {
    print('[WARNING] $message');
  }

  void error(String message) {
    print('[ERROR] $message');
  }

  void debug(String message) {
    if (verbose) {
      print('[DEBUG] $message');
    }
  }
}