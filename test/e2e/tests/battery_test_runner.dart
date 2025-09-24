#!/usr/bin/env dart

/// Battery Test Suite Validator
/// 
/// This runner validates both the mock simulation tests and the actual
/// battery awareness integration tests to ensure comprehensive coverage.

import 'dart:io';

import '../android/battery_optimization_test.dart';
import '../android/doze_mode_test.dart';
import '../ios/low_power_mode_test.dart';
import '../ios/background_app_refresh_test.dart';
import 'battery_awareness_integration_test.dart';

void main(List<String> args) async {
  print('[INFO] Starting Battery Test Suite Validation');
  
  // Parse arguments
  bool verbose = args.contains('--verbose');
  bool includeIntegration = args.contains('--integration') || args.contains('--all');
  String platform = 'all';
  
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--platform' && i + 1 < args.length) {
      platform = args[i + 1];
      break;
    }
  }
  
  final results = <String, bool>{};
  var totalTests = 0;
  var passedTests = 0;
  
  try {
    // Integration Tests (Test actual battery awareness implementation)
    if (includeIntegration) {
      print('\n[INFO] === BATTERY AWARENESS INTEGRATION TESTS ===');
      
      totalTests++;
      try {
        if (verbose) print('[INFO] Running Battery Awareness Integration Tests...');
        final integrationResults = await BatteryAwarenessIntegrationTest.runBatteryAwarenessTests(verbose: verbose);
        final passed = integrationResults.values.every((result) => result);
        results['battery_awareness_integration'] = passed;
        if (passed) passedTests++;
        print('[SUCCESS] Battery Awareness Integration - ${passed ? 'PASSED' : 'FAILED'}');
        
        if (!passed) {
          print('[WARNING] Integration tests failed - the actual battery awareness implementation has issues');
        }
      } catch (e) {
        results['battery_awareness_integration'] = false;
        print('[ERROR] Battery Awareness Integration - FAILED: $e');
      }
    }
    
    // Android Battery Tests (Mock simulation tests)
    if (platform == 'all' || platform == 'android') {
      print('\n[INFO] === ANDROID BATTERY SIMULATION TESTS ===');
      
      // Android Battery Optimization Tests
      totalTests++;
      try {
        if (verbose) print('[INFO] Running Android Battery Optimization Tests...');
        final batteryResults = await AndroidBatteryOptimizationTest.runBatteryOptimizationTests(verbose: verbose);
        final passed = batteryResults.values.every((result) => result);
        results['android_battery_optimization'] = passed;
        if (passed) passedTests++;
        print('[SUCCESS] Android Battery Optimization - ${passed ? 'PASSED' : 'FAILED'}');
      } catch (e) {
        results['android_battery_optimization'] = false;
        print('[ERROR] Android Battery Optimization - FAILED: $e');
      }
      
      // Android Doze Mode Tests
      totalTests++;
      try {
        if (verbose) print('[INFO] Running Android Doze Mode Tests...');
        final dozeResults = await AndroidDozeModeTest.runDozeModeTests(verbose: verbose);
        final passed = dozeResults.values.every((result) => result);
        results['android_doze_mode'] = passed;
        if (passed) passedTests++;
        print('[SUCCESS] Android Doze Mode - ${passed ? 'PASSED' : 'FAILED'}');
      } catch (e) {
        results['android_doze_mode'] = false;
        print('[ERROR] Android Doze Mode - FAILED: $e');
      }
    }
    
    // iOS Battery Tests (Mock simulation tests) 
    if (platform == 'all' || platform == 'ios') {
      print('\n[INFO] === iOS BATTERY SIMULATION TESTS ===');
      
      // iOS Low Power Mode Tests
      totalTests++;
      try {
        if (verbose) print('[INFO] Running iOS Low Power Mode Tests...');
        final lowPowerResults = await IOSLowPowerModeTest.runLowPowerModeTests(verbose: verbose);
        final passed = lowPowerResults.values.every((result) => result);
        results['ios_low_power_mode'] = passed;
        if (passed) passedTests++;
        print('[SUCCESS] iOS Low Power Mode - ${passed ? 'PASSED' : 'FAILED'}');
      } catch (e) {
        results['ios_low_power_mode'] = false;
        print('[ERROR] iOS Low Power Mode - FAILED: $e');
      }
      
      // iOS Background App Refresh Tests
      totalTests++;
      try {
        if (verbose) print('[INFO] Running iOS Background App Refresh Tests...');
        final barResults = await IOSBackgroundAppRefreshTest.runBackgroundAppRefreshTests(verbose: verbose);
        final passed = barResults.values.every((result) => result);
        results['ios_background_app_refresh'] = passed;
        if (passed) passedTests++;
        print('[SUCCESS] iOS Background App Refresh - ${passed ? 'PASSED' : 'FAILED'}');
      } catch (e) {
        results['ios_background_app_refresh'] = false;
        print('[ERROR] iOS Background App Refresh - FAILED: $e');
      }
    }
    
    // Print summary
    print('\n[INFO] ========== Battery Test Suite Results ==========');
    print('[INFO] Platform: $platform');
    print('[INFO] Integration Tests: ${includeIntegration ? 'INCLUDED' : 'SKIPPED (use --integration or --all)'}');
    print('[INFO] Total Tests: $totalTests');
    print('[INFO] Passed: $passedTests');
    print('[INFO] Failed: ${totalTests - passedTests}');
    print('[INFO] Success Rate: ${totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0.0'}%');
    
    // Categorize test results
    print('\n[INFO] Test Results by Category:');
    if (includeIntegration) {
      final integrationPassed = results['battery_awareness_integration'] ?? false;
      print('[INFO] ${integrationPassed ? '✅' : '❌'} Integration Tests (Real Implementation)');
    }
    
    final simulationTests = results.entries.where((e) => e.key != 'battery_awareness_integration');
    if (simulationTests.isNotEmpty) {
      final simulationPassed = simulationTests.every((e) => e.value);
      print('[INFO] ${simulationPassed ? '✅' : '❌'} Simulation Tests (Mock Behavior)');
    }
    
    print('\n[INFO] Detailed Results:');
    for (final entry in results.entries) {
      final status = entry.value ? '✅ PASS' : '❌ FAIL';
      final type = entry.key == 'battery_awareness_integration' ? '(Integration)' : '(Simulation)';
      print('[INFO] $status - ${entry.key} $type');
    }
    print('[INFO] ================================================\n');
    
    // Provide guidance based on results
    if (includeIntegration) {
      final integrationPassed = results['battery_awareness_integration'] ?? false;
      if (!integrationPassed) {
        print('[WARNING] Integration tests failed - this indicates issues with the actual battery awareness implementation.');
        print('[WARNING] The simulation tests passing doesn\'t mean the real functionality works.');
      } else {
        print('[SUCCESS] Integration tests passed - the actual battery awareness implementation is working correctly.');
      }
    } else {
      print('[INFO] Run with --integration or --all to test the actual battery awareness implementation.');
      print('[INFO] Current tests only validate mock simulators, not the real functionality.');
    }
    
    // Exit with appropriate code
    if (passedTests == totalTests) {
      print('[SUCCESS] All battery tests passed! 🔋');
      exit(0);
    } else {
      print('[ERROR] ${totalTests - passedTests} battery test(s) failed');
      exit(1);
    }
    
  } catch (e, stackTrace) {
    print('[FATAL] Battery test execution failed: $e');
    if (verbose) {
      print('[DEBUG] Stack trace: $stackTrace');
    }
    exit(1);
  }
}