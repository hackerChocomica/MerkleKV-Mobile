# Mobile E2E Testing Framework

This directory contains the comprehensive Mobile E2E Testing Orchestrator for MerkleKV Mobile, designed to validate mobile-specific lifecycle scenarios, network state transitions, and convergence behavior across Android and iOS platforms.

## Architecture

The E2E testing framework follows a 3-layer architecture:

### Layer 1: Test Runner (Orchestrator)
- `orchestrator/` - Core test execution and scenario management
- `scenarios/` - Reusable test scenarios and configurations

### Layer 2: Appium Integration (Cross-Platform)
- `drivers/` - Appium-based mobile automation drivers
- `android/` - Android-specific test implementations
- `ios/` - iOS-specific test implementations

### Layer 3: Flutter Integration (White-box)
- `flutter/` - Flutter integration tests for deep inspection
- `network/` - Network state testing and simulation
- `convergence/` - Anti-entropy and synchronization testing

## Directory Structure

```
test/e2e/
├── orchestrator/           # Test execution orchestrator
│   ├── mobile_e2e_orchestrator.dart
│   ├── test_session_manager.dart
│   └── test_result_aggregator.dart
├── drivers/               # Appium and automation drivers
│   ├── appium_test_driver.dart
│   ├── mobile_lifecycle_manager.dart
│   └── network_state_manager.dart
├── flutter/               # Flutter integration tests
│   ├── merkle_kv_integration_test.dart
│   ├── lifecycle_integration_test.dart
│   └── state_persistence_test.dart
├── scenarios/             # Test scenario definitions
│   ├── e2e_scenario.dart
│   ├── mobile_lifecycle_scenarios.dart
│   └── network_scenarios.dart
├── android/               # Android-specific tests
│   ├── android_lifecycle_test.dart
│   ├── doze_mode_test.dart
│   └── battery_optimization_test.dart
├── ios/                   # iOS-specific tests
│   ├── ios_lifecycle_test.dart
│   ├── background_app_refresh_test.dart
│   └── low_power_mode_test.dart
├── network/               # Network state testing
│   ├── network_state_test.dart
│   ├── connectivity_transition_test.dart
│   └── airplane_mode_test.dart
└── convergence/           # Convergence and sync testing
    ├── mobile_convergence_test.dart
    ├── anti_entropy_test.dart
    └── multi_device_sync_test.dart
```

## Key Features

- **Cross-Platform Automation**: Unified testing across Android and iOS
- **Mobile Lifecycle Testing**: Background/foreground transitions, app suspension
- **Network State Management**: WiFi/cellular switching, airplane mode simulation
- **Convergence Validation**: Spec-compliant anti-entropy testing
- **Real Device Testing**: Support for physical devices and emulators
- **CI/CD Integration**: Automated testing in GitHub Actions

## Requirements

- Flutter SDK 3.16+
- Appium Server 2.0+
- Android SDK (for Android testing)
- Xcode (for iOS testing)
- Physical devices or emulators

## Quick Start

```bash
# Setup environment
./scripts/setup_e2e_environment.sh

# Run all E2E tests
./scripts/run_mobile_e2e.sh

# Run specific platform tests
./scripts/run_mobile_e2e.sh --platform android
./scripts/run_mobile_e2e.sh --platform ios

# Run specific scenario
./scripts/run_mobile_e2e.sh --scenario lifecycle
```

## Test Scenarios

### Mobile Lifecycle
- App background/foreground transitions
- App suspension and resumption
- App termination and restart
- System memory pressure handling

### Network State Transitions
- WiFi to cellular switching
- Airplane mode toggle and recovery
- Network interruption and reconnection
- Poor connectivity simulation

### Platform-Specific
- Android: Doze mode, battery optimization, background restrictions
- iOS: Background app refresh, low power mode, transport security

### Convergence Testing
- Anti-entropy synchronization during mobile state changes
- Multi-device convergence scenarios
- Operation recovery after network restoration
- Data persistence across app lifecycle events

## Compliance

All tests ensure compliance with:
- Locked Specification v1.0
- Mobile platform guidelines (Android, iOS)
- MQTT QoS=1 and retain=false requirements
- Timeout specifications (10s/20s/30s)
- Security and privacy requirements