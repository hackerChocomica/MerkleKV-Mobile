# Battery Awareness Testing

This directory contains two types of battery-related tests for the MerkleKV Mobile project:

## Test Categories

### 1. Simulation Tests (Mock Tests)
**Location:** `android/`, `ios/` directories  
**Purpose:** Test mobile platform behavior simulation  
**What they test:** Mock simulators that simulate platform behavior without testing actual implementation

**Files:**
- `android/battery_optimization_test.dart` - Mock Android battery optimization scenarios
- `android/doze_mode_test.dart` - Mock Android Doze mode scenarios  
- `ios/low_power_mode_test.dart` - Mock iOS Low Power Mode scenarios
- `ios/background_app_refresh_test.dart` - Mock iOS Background App Refresh scenarios

**What they DON'T test:**
- Actual battery awareness functionality from the source code
- Real battery optimization logic
- Actual MQTT connection adaptations
- Configuration integration

These tests use mock simulators (e.g., `MockAndroidBatterySimulator`, `MockiOSLowPowerSimulator`) that only print messages and manipulate internal state variables. They validate test infrastructure but not the actual battery awareness implementation.

### 2. Integration Tests (Real Implementation Tests)
**Location:** `tests/battery_awareness_integration_test.dart`  
**Purpose:** Test the actual battery awareness implementation  
**What they test:** Real battery awareness functionality from the source code

**Test Coverage:**
- `BatteryAwarenessManager` functionality
- `BatteryStatus` monitoring and streaming
- `BatteryOptimization` logic with different battery levels
- `BatteryAwareConnectionLifecycleManager` adaptive behavior
- Configuration integration with `MerkleKVConfig`
- Real-time battery response and updates

**What they DO test:**
- Actual battery optimization algorithms
- Real configuration integration
- Battery status monitoring streams
- Adaptive MQTT keep-alive intervals
- Operation throttling logic
- Charging detection and behavior

## Running Tests

### Run Only Simulation Tests (Default)
```bash
dart test/e2e/tests/battery_test_runner.dart --verbose
```

### Run Integration Tests (Actual Implementation)
```bash
dart test/e2e/tests/battery_test_runner.dart --integration --verbose
```

### Run All Tests (Both Simulation and Integration)
```bash
dart test/e2e/tests/battery_test_runner.dart --all --verbose
```

### Run Integration Tests Only
```bash
dart test/e2e/tests/battery_awareness_integration_test.dart --verbose
```

## Understanding Test Results

### ✅ When Simulation Tests Pass
- The test infrastructure works correctly
- Mock simulators behave as expected
- Platform scenario simulation is working
- **Does NOT mean the actual battery awareness functionality works**

### ✅ When Integration Tests Pass
- The actual battery awareness implementation is working
- Configuration integration is correct
- Battery optimization logic is functioning
- MQTT adaptation is working as designed
- **This validates the real source code functionality**

### ❌ When Integration Tests Fail But Simulation Tests Pass
This indicates:
- Mock tests are not testing the real implementation
- There are bugs in the actual battery awareness code
- Configuration or integration issues exist
- The real functionality doesn't work despite mock tests passing

## Recommendation

**Always run integration tests (`--integration` or `--all`) to validate that the actual battery awareness functionality is working correctly.** 

The simulation tests are useful for platform behavior validation, but they don't test the real implementation that users will interact with.

## Example Output

### Simulation Tests Only
```
[INFO] === ANDROID BATTERY SIMULATION TESTS ===
[SUCCESS] Android Battery Optimization - PASSED
[SUCCESS] Android Doze Mode - PASSED

[INFO] Run with --integration or --all to test the actual battery awareness implementation.
[INFO] Current tests only validate mock simulators, not the real functionality.
```

### Integration Tests Included
```
[INFO] === BATTERY AWARENESS INTEGRATION TESTS ===
[SUCCESS] Battery Awareness Integration - PASSED

[SUCCESS] Integration tests passed - the actual battery awareness implementation is working correctly.
```

This testing structure ensures both platform simulation validation and real implementation verification.