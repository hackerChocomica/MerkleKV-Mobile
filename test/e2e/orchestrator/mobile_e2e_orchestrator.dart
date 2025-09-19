import 'dart:async';
import 'package:test/test.dart';
import '../drivers/appium_test_driver.dart';
import '../drivers/mobile_lifecycle_manager.dart';
import '../drivers/network_state_manager.dart';
import '../scenarios/e2e_scenario.dart';
import 'test_session_manager.dart';
import 'test_result_aggregator.dart';

/// Main orchestrator for Mobile E2E testing that coordinates the 3-layer architecture:
/// Layer 1: Test Runner (this class)
/// Layer 2: Appium Integration (cross-platform automation)
/// Layer 3: Flutter Integration (white-box testing)
class MobileE2EOrchestrator {
  final AppiumTestDriver? _appiumDriver;
  final MobileLifecycleManager _lifecycleManager;
  final NetworkStateManager _networkManager;
  final TestSessionManager _sessionManager;
  final TestResultAggregator _resultAggregator;

  MobileE2EOrchestrator({
    AppiumTestDriver? appiumDriver,
    required MobileLifecycleManager lifecycleManager,
    required NetworkStateManager networkManager,
    TestSessionManager? sessionManager,
    TestResultAggregator? resultAggregator,
  })  : _appiumDriver = appiumDriver,
        _lifecycleManager = lifecycleManager,
        _networkManager = networkManager,
        _sessionManager = sessionManager ?? TestSessionManager(),
        _resultAggregator = resultAggregator ?? TestResultAggregator();

  /// Execute a complete E2E test scenario with proper session management
  Future<TestResult> executeE2EScenario(E2EScenario scenario) async {
    print('🚀 Starting E2E scenario: ${scenario.name}');
    
    final testSession = await _sessionManager.initializeSession(scenario);
    
    try {
      // Pre-conditions setup
      await _executePreConditions(scenario);
      
      // Main scenario execution
      final result = await _executeMainScenario(scenario);
      
      // Post-conditions validation
      await _validatePostConditions(scenario);
      
      await _resultAggregator.recordSuccess(testSession, result);
      return result;
      
    } catch (error, stackTrace) {
      await _resultAggregator.recordFailure(testSession, error, stackTrace);
      rethrow;
    } finally {
      await _sessionManager.cleanupSession(testSession);
    }
  }

  /// Execute multiple scenarios in sequence or parallel
  Future<List<TestResult>> executeScenarios(
    List<E2EScenario> scenarios, {
    bool parallel = false,
  }) async {
    if (parallel) {
      return await Future.wait(
        scenarios.map((scenario) => executeE2EScenario(scenario)),
      );
    } else {
      final results = <TestResult>[];
      for (final scenario in scenarios) {
        results.add(await executeE2EScenario(scenario));
      }
      return results;
    }
  }

  /// Setup pre-conditions for scenario execution
  Future<void> _executePreConditions(E2EScenario scenario) async {
    print('📋 Setting up pre-conditions for ${scenario.name}');
    
    // Initialize MQTT broker if needed
    if (scenario.requiresMqttBroker) {
      await _sessionManager.startMqttBroker();
    }
    
    // Setup network state
    if (scenario.initialNetworkState != null) {
      await _networkManager.configureNetworkState(scenario.initialNetworkState!);
    }
    
    // Initialize mobile app if needed
    if (scenario.requiresAppLaunch && _appiumDriver != null) {
      await _appiumDriver!.launchApp();
      await _appiumDriver!.waitForAppReady();
    }
    
    // Execute custom pre-conditions
    for (final preCondition in scenario.preConditions) {
      await preCondition.execute();
    }
  }

  /// Execute the main scenario steps
  Future<TestResult> _executeMainScenario(E2EScenario scenario) async {
    print('⚡ Executing main scenario: ${scenario.name}');
    
    final stopwatch = Stopwatch()..start();
    final stepResults = <StepResult>[];
    
    for (int i = 0; i < scenario.steps.length; i++) {
      final step = scenario.steps[i];
      print('  Step ${i + 1}/${scenario.steps.length}: ${step.description}');
      
      try {
        final stepResult = await _executeStep(step);
        stepResults.add(stepResult);
        
        // Add delay between steps if specified
        if (step.delayAfter != null) {
          await Future.delayed(step.delayAfter!);
        }
        
      } catch (error, stackTrace) {
        final failedResult = StepResult(
          step: step,
          success: false,
          error: error,
          stackTrace: stackTrace,
        );
        stepResults.add(failedResult);
        
        if (!step.continueOnFailure) {
          throw E2EScenarioException(
            'Step failed: ${step.description}',
            stepResults,
            error,
            stackTrace,
          );
        }
      }
    }
    
    stopwatch.stop();
    
    return TestResult(
      scenario: scenario,
      stepResults: stepResults,
      duration: stopwatch.elapsed,
      success: stepResults.every((result) => result.success),
    );
  }

  /// Execute a single test step
  Future<StepResult> _executeStep(TestStep step) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await step.execute(
        appiumDriver: _appiumDriver,
        lifecycleManager: _lifecycleManager,
        networkManager: _networkManager,
      );
      
      stopwatch.stop();
      
      return StepResult(
        step: step,
        success: true,
        duration: stopwatch.elapsed,
      );
      
    } catch (error, stackTrace) {
      stopwatch.stop();
      
      return StepResult(
        step: step,
        success: false,
        duration: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Validate post-conditions after scenario execution
  Future<void> _validatePostConditions(E2EScenario scenario) async {
    print('✅ Validating post-conditions for ${scenario.name}');
    
    for (final postCondition in scenario.postConditions) {
      await postCondition.validate();
    }
  }

  /// Cleanup resources and prepare for next test
  Future<void> cleanup() async {
    await _appiumDriver?.cleanup();
    await _networkManager.cleanup();
    await _lifecycleManager.cleanup();
    await _sessionManager.cleanup();
  }
}

/// Result of executing a complete test scenario
class TestResult {
  final E2EScenario scenario;
  final List<StepResult> stepResults;
  final Duration duration;
  final bool success;
  final DateTime timestamp;

  TestResult({
    required this.scenario,
    required this.stepResults,
    required this.duration,
    required this.success,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Get failed steps
  List<StepResult> get failedSteps => stepResults.where((r) => !r.success).toList();

  /// Get successful steps
  List<StepResult> get successfulSteps => stepResults.where((r) => r.success).toList();

  /// Generate summary report
  String generateSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Test Result: ${scenario.name}');
    buffer.writeln('Status: ${success ? "PASSED" : "FAILED"}');
    buffer.writeln('Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('Steps: ${successfulSteps.length}/${stepResults.length} passed');
    
    if (failedSteps.isNotEmpty) {
      buffer.writeln('Failed Steps:');
      for (final failed in failedSteps) {
        buffer.writeln('  - ${failed.step.description}: ${failed.error}');
      }
    }
    
    return buffer.toString();
  }
}

/// Result of executing a single test step
class StepResult {
  final TestStep step;
  final bool success;
  final Duration? duration;
  final dynamic error;
  final StackTrace? stackTrace;

  StepResult({
    required this.step,
    required this.success,
    this.duration,
    this.error,
    this.stackTrace,
  });
}

/// Exception thrown when E2E scenario fails
class E2EScenarioException implements Exception {
  final String message;
  final List<StepResult> stepResults;
  final dynamic originalError;
  final StackTrace? originalStackTrace;

  E2EScenarioException(
    this.message,
    this.stepResults,
    this.originalError,
    this.originalStackTrace,
  );

  @override
  String toString() => 'E2EScenarioException: $message';
}