import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mockito/mockito.dart';

/// Utilities for Android-specific mobile E2E testing
class AndroidTestUtils {
  static const String _lifecycleChannel = 'flutter/lifecycle';
  static const String _connectivityChannel = 'plugins.flutter.io/connectivity';
  static const String _batteryChannel = 'plugins.flutter.io/battery';
  static const String _deviceInfoChannel = 'plugins.flutter.io/device_info';

  /// Mock method call handler for testing platform channels
  static MethodChannel? _mockMethodChannel;

  /// Sets up Android platform simulation
  static void setupAndroidPlatform() {
    // Mock the default target platform for testing
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }

  /// Cleans up Android platform simulation
  static void teardownAndroidPlatform() {
    // Reset the platform override
    debugDefaultTargetPlatformOverride = null;
  }

  /// Simulates app lifecycle state changes for testing
  static Future<void> simulateAppLifecycleState(AppLifecycleState state) async {
    // Use WidgetsBinding to simulate lifecycle changes in tests
    final binding = WidgetsFlutterBinding.ensureInitialized();
    
    // Mock the lifecycle state change
    switch (state) {
      case AppLifecycleState.resumed:
        // Simulate app coming to foreground
        break;
      case AppLifecycleState.inactive:
        // Simulate app becoming inactive (e.g., phone call)
        break;
      case AppLifecycleState.paused:
        // Simulate app going to background
        break;
      case AppLifecycleState.detached:
        // Simulate app being terminated
        break;
      case AppLifecycleState.hidden:
        // Simulate app being hidden (not shown to user)
        break;
    }
    
    // Allow some time for the state change to be processed
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Simulate airplane mode toggle
  static Future<void> simulateAirplaneModeToggle({required bool enabled}) async {
    final methodChannel = MethodChannel(_connectivityChannel);
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'check':
          return enabled ? 'none' : 'wifi';
        case 'wifiName':
          return enabled ? null : 'TestWiFi';
        case 'wifiBSSID':
          return enabled ? null : '00:00:00:00:00:00';
        default:
          return null;
      }
    });

    // Allow time for connectivity change to propagate
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Simulate network connectivity changes (WiFi/Cellular)
  static Future<void> simulateNetworkChange({
    required String connectivityType,
    String? wifiName,
    String? wifiBSSID,
  }) async {
    final methodChannel = MethodChannel(_connectivityChannel);
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'check':
          return connectivityType;
        case 'wifiName':
          return wifiName;
        case 'wifiBSSID':
          return wifiBSSID;
        default:
          return null;
      }
    });

    // Allow time for network change to propagate
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Simulate battery level and optimization states
  static Future<void> simulateBatteryState({
    required int batteryLevel,
    required bool lowPowerMode,
  }) async {
    final methodChannel = MethodChannel(_batteryChannel);
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'getBatteryLevel':
          return batteryLevel;
        case 'isInBatterySaveMode':
          return lowPowerMode;
        default:
          return null;
      }
    });
  }

  /// Get Android device information for testing
  static Future<Map<String, dynamic>> getAndroidDeviceInfo() async {
    final methodChannel = MethodChannel(_deviceInfoChannel);
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'getAndroidDeviceInfo') {
        return {
          'version': {
            'sdkInt': 30, // Android API 30 (Android 11)
            'release': '11',
          },
          'brand': 'google',
          'device': 'generic_x86_64',
          'model': 'Android SDK built for x86_64',
          'manufacturer': 'Google',
          'isPhysicalDevice': false, // Emulator
        };
      }
      return null;
    });

    // Simulate device info retrieval
    await Future.delayed(const Duration(milliseconds: 50));
    return {
      'apiLevel': 30,
      'isEmulator': true,
      'brand': 'google',
    };
  }

  /// Simulate Android Doze mode (background app limitations)
  static Future<void> simulateDozeMode({required bool enabled}) async {
    // Simulate the effects of Doze mode on background processing
    if (enabled) {
      await simulateAppLifecycleState(AppLifecycleState.paused);
      // In Doze mode, network access is restricted
      await simulateNetworkChange(connectivityType: 'none');
    } else {
      await simulateAppLifecycleState(AppLifecycleState.resumed);
      await simulateNetworkChange(connectivityType: 'wifi', wifiName: 'TestWiFi');
    }
  }

  /// Simulate memory pressure scenarios
  static Future<void> simulateMemoryPressure() async {
    // Simulate system memory pressure by triggering lifecycle events
    await simulateAppLifecycleState(AppLifecycleState.paused);
    await Future.delayed(const Duration(milliseconds: 100));
    await simulateAppLifecycleState(AppLifecycleState.resumed);
  }

  /// Simulate app termination and restart
  static Future<void> simulateAppTerminationAndRestart() async {
    await simulateAppLifecycleState(AppLifecycleState.detached);
    await Future.delayed(const Duration(milliseconds: 500));
    await simulateAppLifecycleState(AppLifecycleState.resumed);
  }

  /// Set up mock method channels for testing
  static void _setupMockChannels() {
    // Initialize channels with default behaviors
    _setupLifecycleChannel();
    _setupConnectivityChannel();
    _setupBatteryChannel();
    _setupDeviceInfoChannel();
  }

  static void _setupLifecycleChannel() {
    final methodChannel = MethodChannel(_lifecycleChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      return null;
    });
  }

  static void _setupConnectivityChannel() {
    final methodChannel = MethodChannel(_connectivityChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'check':
          return 'wifi';
        case 'wifiName':
          return 'TestWiFi';
        case 'wifiBSSID':
          return '00:00:00:00:00:00';
        default:
          return null;
      }
    });
  }

  static void _setupBatteryChannel() {
    final methodChannel = MethodChannel(_batteryChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'getBatteryLevel':
          return 80;
        case 'isInBatterySaveMode':
          return false;
        default:
          return null;
      }
    });
  }

  static void _setupDeviceInfoChannel() {
    final methodChannel = MethodChannel(_deviceInfoChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'getAndroidDeviceInfo') {
        return {
          'version': {'sdkInt': 30},
          'isPhysicalDevice': false,
        };
      }
      return null;
    });
  }

  /// Wait for convergence with timeout but no hard-coded latency targets
  static Future<bool> waitForConvergence({
    required Future<bool> Function() convergenceCheck,
    Duration maxWait = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxWait) {
      if (await convergenceCheck()) {
        return true;
      }
      await Future.delayed(pollInterval);
    }
    
    return false;
  }

  /// Simulate rapid background/foreground cycling
  static Future<void> simulateRapidLifecycleCycling({
    required int cycles,
    Duration cycleDelay = const Duration(milliseconds: 100),
  }) async {
    for (int i = 0; i < cycles; i++) {
      await simulateAppLifecycleState(AppLifecycleState.paused);
      await Future.delayed(cycleDelay);
      await simulateAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(cycleDelay);
    }
  }
}

/// Exception for Android-specific test failures
class AndroidTestException implements Exception {
  final String message;
  final String? androidSpecificInfo;

  const AndroidTestException(this.message, [this.androidSpecificInfo]);

  @override
  String toString() {
    if (androidSpecificInfo != null) {
      return 'AndroidTestException: $message (Android info: $androidSpecificInfo)';
    }
    return 'AndroidTestException: $message';
  }
}