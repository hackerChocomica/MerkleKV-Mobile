# Android Mobile E2E Testing Documentation

## Overview

This document provides comprehensive guidance for implementing and running end-to-end (E2E) testing on Android platforms for the MerkleKV Mobile project. The testing framework focuses on mobile-specific lifecycle scenarios, network state transitions, and Locked Specification-compliant convergence behavior.

## Table of Contents

1. [Test Architecture](#test-architecture)
2. [Setup and Installation](#setup-and-installation)
3. [Test Suites](#test-suites)
4. [Running Tests](#running-tests)
5. [CI/CD Integration](#cicd-integration)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

## Test Architecture

### Framework Structure

```
test/mobile_e2e/
├── utils/
│   ├── android_test_utils.dart          # Android platform utilities
│   └── merkle_kv_mobile_test_helper.dart # MerkleKV test helpers
└── android/
    ├── android_lifecycle_test.dart       # Lifecycle testing
    ├── android_network_state_test.dart   # Network state testing
    ├── android_convergence_test.dart     # Convergence validation
    ├── android_platform_specific_test.dart # Platform features
    ├── android_multi_device_test.dart    # Multi-device sync
    └── android_security_test.dart        # Security testing
```

### Key Testing Principles

- **Spec-Compliant Convergence**: Tests focus on Locked Specification compliance rather than hard-coded latency targets
- **Platform-Specific Behavior**: Tests validate Android API 21+ specific features
- **Real Device Compatibility**: Tests are designed to run on both emulators and physical devices
- **Minimal Changes**: Integration with existing codebase requires minimal modifications

## Setup and Installation

### Prerequisites

- **Flutter SDK**: 3.16.0 or higher
- **Dart SDK**: 3.0.0 or higher
- **Android SDK**: API Level 21 (Android 5.0) or higher
- **Java**: JDK 17 or higher
- **Docker**: For MQTT broker testing

### Installation Steps

1. **Install Dependencies**
   ```bash
   cd apps/flutter_demo
   flutter pub get
   ```

2. **Start MQTT Broker**
   ```bash
   docker run -d --name test-mosquitto -p 1883:1883 eclipse-mosquitto:1.6
   ```

3. **Verify Setup**
   ```bash
   # Check MQTT broker connectivity
   ../../scripts/mqtt_health_check.sh
   
   # Verify Flutter environment
   flutter doctor
   ```

### Android Emulator Setup

#### Creating Test Emulators

```bash
# Create Android emulators for different API levels
sdkmanager "system-images;android-21;google_apis;x86_64"
sdkmanager "system-images;android-26;google_apis;x86_64"
sdkmanager "system-images;android-30;google_apis;x86_64"

# Create AVDs
avdmanager create avd -n "Android_21" -k "system-images;android-21;google_apis;x86_64"
avdmanager create avd -n "Android_26" -k "system-images;android-26;google_apis;x86_64"
avdmanager create avd -n "Android_30" -k "system-images;android-30;google_apis;x86_64"
```

#### Emulator Configuration

```bash
# Start emulator with appropriate settings
emulator -avd Android_30 -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim
```

## Test Suites

### 1. Android Lifecycle Tests (`android_lifecycle_test.dart`)

**Purpose**: Validates app behavior during background/foreground transitions, app suspension/resumption, and state preservation.

**Key Test Cases**:
- Background transition preserves connection state
- App suspension and resumption maintains data integrity
- App termination and restart recovers persistent state
- Rapid background/foreground cycling maintains stability
- Android Doze mode simulation
- Battery optimization compliance

**Example Usage**:
```bash
flutter test test/mobile_e2e/android/android_lifecycle_test.dart
```

### 2. Network State Tests (`android_network_state_test.dart`)

**Purpose**: Tests airplane mode simulation, WiFi/cellular switching, and network interruption handling.

**Key Test Cases**:
- Airplane mode toggle triggers proper reconnection
- WiFi to cellular network switching
- Network interruption and restoration with operation queuing
- Poor connectivity simulation with retry mechanisms
- Multiple network interface changes
- Extended offline period recovery

**Example Usage**:
```bash
flutter test test/mobile_e2e/android/android_network_state_test.dart
```

### 3. Convergence Validation Tests (`android_convergence_test.dart`)

**Purpose**: Validates anti-entropy synchronization during mobile state transitions without hard-coded latency targets.

**Key Test Cases**:
- Anti-entropy during background/foreground transitions
- Convergence during network state changes
- Spec-compliant convergence behavior
- Anti-entropy during airplane mode simulation
- Concurrent operations with state transitions
- Anti-entropy interval compliance

**Example Usage**:
```bash
flutter test test/mobile_e2e/android/android_convergence_test.dart
```

### 4. Platform-Specific Tests (`android_platform_specific_test.dart`)

**Purpose**: Tests Android API 21+ specific features including battery optimization and background execution compliance.

**Key Test Cases**:
- Android API level compliance (21+)
- Battery optimization impact on background operations
- Android Doze mode compliance
- Memory management and system pressure handling
- Background execution policy compliance
- API-specific feature testing (Android 6.0+, 8.0+, 9.0+, 10+)

**Example Usage**:
```bash
flutter test test/mobile_e2e/android/android_platform_specific_test.dart
```

### 5. Multi-Device Synchronization Tests (`android_multi_device_test.dart`)

**Purpose**: Tests mobile-to-mobile and mobile-to-desktop convergence scenarios.

**Key Test Cases**:
- Mobile-to-mobile synchronization across Android devices
- Mobile-to-desktop synchronization
- Multi-device convergence with offline/online scenarios
- Concurrent operations across device types
- Network switching during multi-device sync
- Cross-platform convergence validation

**Example Usage**:
```bash
flutter test test/mobile_e2e/android/android_multi_device_test.dart
```

### 6. Security Tests (`android_security_test.dart`)

**Purpose**: Tests certificate validation, network security policies, and secure storage.

**Key Test Cases**:
- Android certificate validation
- Network Security Config compliance
- Secure storage and data protection
- Privacy and permissions compliance
- Security hardening measures
- GDPR and platform policy compliance

**Example Usage**:
```bash
flutter test test/mobile_e2e/android/android_security_test.dart
```

## Running Tests

### Local Development

#### Run All Android E2E Tests
```bash
cd apps/flutter_demo
flutter test test/mobile_e2e/android/
```

#### Run Specific Test Suite
```bash
flutter test test/mobile_e2e/android/android_lifecycle_test.dart
```

#### Run Tests with Coverage
```bash
flutter test test/mobile_e2e/android/ --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Emulator Testing

#### Single Emulator
```bash
# Start emulator
emulator -avd Android_30 -no-window

# Run tests
flutter test test/mobile_e2e/android/ --device-id emulator-5554
```

#### Multiple Emulators (API Level Matrix)
```bash
# Test across multiple Android versions
for api in 21 26 30; do
  emulator -avd Android_$api -no-window &
  sleep 30
  flutter test test/mobile_e2e/android/ --device-id emulator-555$(($api - 20))
  adb -s emulator-555$(($api - 20)) emu kill
done
```

### Physical Device Testing

```bash
# Enable USB debugging on device
adb devices

# Run tests on connected device
flutter test test/mobile_e2e/android/ --device-id <device-id>
```

## CI/CD Integration

### GitHub Actions

The project includes comprehensive GitHub Actions workflow (`.github/workflows/android-mobile-e2e.yml`) with:

- **Matrix Testing**: Multiple Android API levels (21, 26, 29, 30, 33)
- **Emulator Testing**: Automated AVD creation and caching
- **Firebase Test Lab**: Real device testing on Google's infrastructure
- **AWS Device Farm**: Extended device coverage (nightly tests)
- **Test Reporting**: Automated result collection and PR comments

#### Triggering CI Tests

```bash
# Push to trigger CI
git push origin feature/mobile-e2e-android

# Manual workflow dispatch
gh workflow run "Android Mobile E2E Tests"
```

### Firebase Test Lab Integration

#### Setup

1. Create Firebase project
2. Enable Test Lab API
3. Configure service account credentials
4. Set up results bucket

#### Running Tests

```bash
# Build test APKs
flutter build apk --debug
flutter build apk --debug --target=test_driver/integration_test.dart

# Upload and run on Firebase Test Lab
gcloud firebase test android run \
  --type instrumentation \
  --app build/app/outputs/flutter-apk/app-debug.apk \
  --test build/app/outputs/flutter-apk/app-debug-androidTest.apk \
  --device model=Pixel2,version=28 \
  --device model=NexusLowRes,version=25 \
  --timeout 20m
```

### AWS Device Farm Integration

#### Setup

1. Create AWS Device Farm project
2. Configure AWS credentials
3. Set up device pools

#### Running Tests

```bash
# Upload APK and test package
aws devicefarm create-upload --project-arn $PROJECT_ARN --name app-debug.apk --type ANDROID_APP
aws devicefarm create-upload --project-arn $PROJECT_ARN --name test.apk --type INSTRUMENTATION_TEST_PACKAGE

# Schedule test run
aws devicefarm schedule-run --project-arn $PROJECT_ARN --app-arn $APP_ARN --device-pool-arn $DEVICE_POOL_ARN
```

## Troubleshooting

### Common Issues

#### 1. MQTT Broker Connection Issues

**Problem**: Tests fail with MQTT connection errors

**Solution**:
```bash
# Check broker status
docker ps | grep mosquitto

# Restart broker
docker stop test-mosquitto && docker rm test-mosquitto
docker run -d --name test-mosquitto -p 1883:1883 eclipse-mosquitto:1.6

# Verify connectivity
../../scripts/mqtt_health_check.sh
```

#### 2. Emulator Performance Issues

**Problem**: Tests timeout or run slowly on emulators

**Solution**:
```bash
# Use hardware acceleration
emulator -avd Android_30 -gpu host

# Increase emulator RAM
emulator -avd Android_30 -memory 4096

# Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

#### 3. Test Timeouts

**Problem**: Tests timeout during convergence validation

**Solution**:
- Check network connectivity
- Verify MQTT broker is running
- Increase timeout values in test configuration
- Check for resource constraints on test device

#### 4. Platform Channel Errors

**Problem**: Mock platform channels not working correctly

**Solution**:
```dart
// Ensure proper test environment initialization
await AndroidTestUtils.initializeAndroidTestEnvironment();

// Reset mock channels between tests
AndroidTestUtils.cleanupTestEnvironment();
```

### Debug Configuration

#### Enable Debug Logging

```dart
// In test setup
debugPrint('Test debug logging enabled');

// Add to test configuration
config = MerkleKVMobileTestHelper.createMobileTestConfig(
  clientId: 'debug_client',
  enableDebugLogging: true,
);
```

#### Capture Test Artifacts

```bash
# Capture screenshots during test failures
flutter test --reporter json > test_results.json

# Save emulator logs
adb logcat > emulator_logs.txt
```

## Best Practices

### Test Design

1. **Use Realistic Scenarios**: Test scenarios should reflect real mobile usage patterns
2. **Avoid Hard-Coded Timing**: Use convergence checks instead of fixed delays
3. **Test Edge Cases**: Include rapid state changes, poor connectivity, and resource constraints
4. **Validate Spec Compliance**: Ensure tests verify Locked Specification requirements

### Performance Optimization

1. **Parallel Test Execution**: Run independent tests in parallel where possible
2. **Efficient Setup/Teardown**: Minimize expensive operations in test setup
3. **Resource Management**: Properly clean up connections and resources
4. **Caching**: Use CI caching for emulator images and dependencies

### Maintenance

1. **Regular Updates**: Keep test dependencies and Android SDK versions current
2. **Monitor Test Reliability**: Track test flakiness and address unstable tests
3. **Device Coverage**: Regularly update device matrix for testing
4. **Documentation**: Keep test documentation in sync with implementation changes

## Test Configuration

### Environment Variables

```bash
# Test configuration
export MQTT_BROKER_HOST=localhost
export MQTT_BROKER_PORT=1883
export TEST_TIMEOUT_MULTIPLIER=1.5
export ANDROID_MIN_API_LEVEL=21
```

### Test Data Management

```dart
// Use helper methods for consistent test data
final testData = MerkleKVMobileTestHelper.createTestDataSet(
  keyCount: 10,
  keyPrefix: 'test_scenario',
);

// Validate payload limits
MerkleKVMobileTestHelper.validatePayloadLimits(
  key: testKey,
  value: testValue,
);
```

## Reporting and Metrics

### Test Metrics Collection

- **Test Execution Time**: Monitor test performance across different Android versions
- **Convergence Time**: Track convergence behavior without hard-coded expectations
- **Device Performance**: Monitor resource usage during tests
- **Failure Rates**: Track test reliability across different configurations

### Automated Reporting

The CI pipeline automatically generates:
- Test result summaries
- Coverage reports
- Performance metrics
- Device compatibility matrices
- Failure analysis reports

## Security Considerations

### Test Environment Security

1. **Isolated Testing**: Tests run in isolated environments
2. **Credential Management**: Use secure credential storage for CI/CD
3. **Network Security**: Test MQTT connections use appropriate security settings
4. **Data Protection**: Test data follows privacy and security guidelines

### Compliance Testing

- **Android Security Policies**: Tests verify compliance with Android security requirements
- **Network Security Config**: Validate proper network security configuration
- **Certificate Validation**: Test proper certificate handling and validation
- **Privacy Compliance**: Ensure test data handling follows privacy regulations

## Future Enhancements

### Planned Improvements

1. **Enhanced Device Coverage**: Expand testing to more Android device manufacturers
2. **Performance Benchmarking**: Add detailed performance metrics collection
3. **Automated Regression Detection**: Implement automated detection of performance regressions
4. **Advanced Network Simulation**: Add more sophisticated network condition simulation
5. **Battery Usage Testing**: Integrate actual battery usage measurement

### Contributing

When adding new Android E2E tests:

1. Follow existing test structure and naming conventions
2. Include proper documentation and comments
3. Validate tests work on multiple Android API levels
4. Ensure tests are deterministic and reliable
5. Add appropriate CI/CD integration
6. Update this documentation as needed

## Support

For questions or issues with Android E2E testing:

1. Check this documentation first
2. Review existing test implementations for patterns
3. Check CI logs for detailed error information
4. Create issues with detailed reproduction steps
5. Include device information and logs when reporting problems

---

This documentation provides comprehensive guidance for implementing and maintaining Android mobile E2E testing for the MerkleKV Mobile project. Regular updates ensure it remains current with project evolution and Android platform changes.