#!/usr/bin/env dart

/// Comprehensive E2E Test Validation Script
/// 
/// Validates all E2E tests including the new battery test suite
/// to ensure everything is working correctly before CI/CD integration.

import 'dart:io';

void main(List<String> args) async {
  print('[INFO] Starting Comprehensive E2E Test Validation');
  print('[INFO] ================================================');
  
  final results = <String, bool>{};
  var totalSuites = 0;
  var passedSuites = 0;
  
  try {
    // Test 1: Mobile Lifecycle Tests (including battery scenarios)
    totalSuites++;
    try {
      print('\n[INFO] === MOBILE LIFECYCLE TESTS ===');
      final process1 = await Process.run(
        'dart',
        ['mobile_lifecycle_test.dart'],
        workingDirectory: '/home/runner/work/MerkleKV-Mobile/MerkleKV-Mobile/test/e2e/tests',
        environment: {'PATH': '/usr/local/dart-sdk/bin:\$HOME/.pub-cache/bin:\$PATH'},
      );
      
      final passed = process1.exitCode == 0;
      results['mobile_lifecycle'] = passed;
      if (passed) passedSuites++;
      print('[SUCCESS] Mobile Lifecycle Tests - ${passed ? 'PASSED' : 'FAILED'}');
      if (!passed) {
        print('[ERROR] Exit code: ${process1.exitCode}');
        print('[ERROR] Stderr: ${process1.stderr}');
      }
    } catch (e) {
      results['mobile_lifecycle'] = false;
      print('[ERROR] Mobile Lifecycle Tests - EXCEPTION: $e');
    }
    
    // Test 2: Battery Test Suite
    totalSuites++;
    try {
      print('\n[INFO] === BATTERY TEST SUITE ===');
      final process2 = await Process.run(
        'dart',
        ['battery_test_runner.dart'],
        workingDirectory: '/home/runner/work/MerkleKV-Mobile/MerkleKV-Mobile/test/e2e/tests',
        environment: {'PATH': '/usr/local/dart-sdk/bin:\$HOME/.pub-cache/bin:\$PATH'},
      );
      
      final passed = process2.exitCode == 0;
      results['battery_tests'] = passed;
      if (passed) passedSuites++;
      print('[SUCCESS] Battery Test Suite - ${passed ? 'PASSED' : 'FAILED'}');
      if (!passed) {
        print('[ERROR] Exit code: ${process2.exitCode}');
        print('[ERROR] Stderr: ${process2.stderr}');
      }
    } catch (e) {
      results['battery_tests'] = false;
      print('[ERROR] Battery Test Suite - EXCEPTION: $e');
    }
    
    // Test 3: Android E2E Tests (lifecycle suite)
    totalSuites++;
    try {
      print('\n[INFO] === ANDROID E2E TESTS ===');
      final process3 = await Process.run(
        'dart',
        ['android_e2e_test.dart', '--suite', 'lifecycle'],
        workingDirectory: '/home/runner/work/MerkleKV-Mobile/MerkleKV-Mobile/test/e2e/tests',
        environment: {'PATH': '/usr/local/dart-sdk/bin:\$HOME/.pub-cache/bin:\$PATH'},
      );
      
      final passed = process3.exitCode == 0;
      results['android_e2e'] = passed;
      if (passed) passedSuites++;
      print('[SUCCESS] Android E2E Tests - ${passed ? 'PASSED' : 'FAILED'}');
      if (!passed) {
        print('[ERROR] Exit code: ${process3.exitCode}');
        print('[ERROR] Stderr: ${process3.stderr}');
      }
    } catch (e) {
      results['android_e2e'] = false;
      print('[ERROR] Android E2E Tests - EXCEPTION: $e');
    }
    
    // Test 4: iOS E2E Tests (lifecycle suite)
    totalSuites++;
    try {
      print('\n[INFO] === iOS E2E TESTS ===');
      final process4 = await Process.run(
        'dart',
        ['ios_e2e_test.dart', '--suite', 'lifecycle'],
        workingDirectory: '/home/runner/work/MerkleKV-Mobile/MerkleKV-Mobile/test/e2e/tests',
        environment: {'PATH': '/usr/local/dart-sdk/bin:\$HOME/.pub-cache/bin:\$PATH'},
      );
      
      final passed = process4.exitCode == 0;
      results['ios_e2e'] = passed;
      if (passed) passedSuites++;
      print('[SUCCESS] iOS E2E Tests - ${passed ? 'PASSED' : 'FAILED'}');
      if (!passed) {
        print('[ERROR] Exit code: ${process4.exitCode}');
        print('[ERROR] Stderr: ${process4.stderr}');
      }
    } catch (e) {
      results['ios_e2e'] = false;
      print('[ERROR] iOS E2E Tests - EXCEPTION: $e');
    }
    
    // Test 5: Static Analysis on Battery Test Files
    totalSuites++;
    try {
      print('\n[INFO] === STATIC ANALYSIS ===');
      final process5 = await Process.run(
        'dart',
        ['analyze', 'test/e2e/android', 'test/e2e/ios', 'test/e2e/tests/mobile_lifecycle_test.dart', 'test/e2e/scenarios/mobile_lifecycle_scenarios.dart'],
        workingDirectory: '/home/runner/work/MerkleKV-Mobile/MerkleKV-Mobile',
        environment: {'PATH': '/usr/local/dart-sdk/bin:\$HOME/.pub-cache/bin:\$PATH'},
      );
      
      final passed = process5.exitCode <= 2; // Allow warnings and info
      results['static_analysis'] = passed;
      if (passed) passedSuites++;
      print('[SUCCESS] Static Analysis - ${passed ? 'PASSED' : 'FAILED'}');
      if (!passed) {
        print('[ERROR] Exit code: ${process5.exitCode}');
        print('[ERROR] Stderr: ${process5.stderr}');
      }
    } catch (e) {
      results['static_analysis'] = false;
      print('[ERROR] Static Analysis - EXCEPTION: $e');
    }
    
    // Final Results
    print('\n[INFO] ========== COMPREHENSIVE E2E VALIDATION RESULTS ==========');
    print('[INFO] Total Test Suites: $totalSuites');
    print('[INFO] Passed Suites: $passedSuites');
    print('[INFO] Failed Suites: ${totalSuites - passedSuites}');
    print('[INFO] Success Rate: ${totalSuites > 0 ? (passedSuites / totalSuites * 100).toStringAsFixed(1) : '0.0'}%');
    print('[INFO] ');
    
    for (final entry in results.entries) {
      final status = entry.value ? '✅ PASS' : '❌ FAIL';
      print('[INFO] $status - ${entry.key}');
    }
    
    print('[INFO] ================================================');
    
    if (passedSuites == totalSuites) {
      print('\n[SUCCESS] 🎉 All E2E test suites passed! Battery tests are fully integrated.');
      print('[SUCCESS] Ready for CI/CD integration and production use.');
      exit(0);
    } else {
      print('\n[ERROR] ${totalSuites - passedSuites} test suite(s) failed.');
      print('[ERROR] Please review failed tests before proceeding with CI/CD integration.');
      exit(1);
    }
    
  } catch (e, stackTrace) {
    print('[FATAL] Comprehensive validation failed: $e');
    print('[FATAL] Stack trace: $stackTrace');
    exit(1);
  }
}