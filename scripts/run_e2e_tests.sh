#!/bin/bash

# Mobile E2E Test Runner Script
# Executes comprehensive E2E tests for MerkleKV Mobile application
# Supports local, emulator, and cloud device testing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
E2E_DIR="$PROJECT_ROOT/test/e2e"
LOGS_DIR="$E2E_DIR/logs"
REPORTS_DIR="$E2E_DIR/reports"
SCREENSHOTS_DIR="$E2E_DIR/screenshots"

# Default values
PLATFORM="android"
TEST_SUITE="all"
DEVICE_POOL="emulator"
CLOUD_PROVIDER=""
APPIUM_PORT="4723"
MQTT_PORT="1883"
VERBOSE=false
DRY_RUN=false
PARALLEL=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Mobile E2E Test Runner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -p, --platform PLATFORM      Target platform: android, ios (default: android)
    -s, --suite SUITE            Test suite: all, lifecycle, network, convergence (default: all)
    -d, --device-pool POOL       Device pool: emulator, local, cloud (default: emulator)
    -c, --cloud PROVIDER         Cloud provider: browserstack, saucelabs (required for cloud pool)
    --appium-port PORT           Appium server port (default: 4723)
    --mqtt-port PORT             MQTT broker port (default: 1883)
    --parallel                   Run tests in parallel (experimental)
    --dry-run                    Show what would be executed without running
    -v, --verbose                Enable verbose output
    -h, --help                   Show this help message

EXAMPLES:
    # Run all tests on Android emulator
    $0 --platform android --suite all

    # Run lifecycle tests on iOS simulator
    $0 --platform ios --suite lifecycle --device-pool local

    # Run convergence tests on cloud devices
    $0 --platform android --suite convergence --device-pool cloud --cloud browserstack

    # Dry run to see execution plan
    $0 --platform ios --suite network --dry-run

ENVIRONMENT VARIABLES:
    BROWSERSTACK_USERNAME        BrowserStack username (for cloud testing)
    BROWSERSTACK_ACCESS_KEY      BrowserStack access key (for cloud testing)
    SAUCELABS_USERNAME           Sauce Labs username (for cloud testing)
    SAUCELABS_ACCESS_KEY         Sauce Labs access key (for cloud testing)
    APPIUM_LOG_LEVEL            Appium log level (default: info)
    FLUTTER_DART_DEV            Enable Flutter development mode
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--platform)
                PLATFORM="$2"
                shift 2
                ;;
            -s|--suite)
                TEST_SUITE="$2"
                shift 2
                ;;
            -d|--device-pool)
                DEVICE_POOL="$2"
                shift 2
                ;;
            -c|--cloud)
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            --appium-port)
                APPIUM_PORT="$2"
                shift 2
                ;;
            --mqtt-port)
                MQTT_PORT="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    # Validate platform
    if [[ ! "$PLATFORM" =~ ^(android|ios)$ ]]; then
        log_error "Invalid platform: $PLATFORM. Must be 'android' or 'ios'"
        exit 1
    fi

    # Validate test suite
    if [[ ! "$TEST_SUITE" =~ ^(all|lifecycle|network|convergence)$ ]]; then
        log_error "Invalid test suite: $TEST_SUITE. Must be 'all', 'lifecycle', 'network', or 'convergence'"
        exit 1
    fi

    # Validate device pool
    if [[ ! "$DEVICE_POOL" =~ ^(emulator|local|cloud)$ ]]; then
        log_error "Invalid device pool: $DEVICE_POOL. Must be 'emulator', 'local', or 'cloud'"
        exit 1
    fi

    # Validate cloud provider if using cloud devices
    if [[ "$DEVICE_POOL" == "cloud" ]]; then
        if [[ -z "$CLOUD_PROVIDER" ]]; then
            log_error "Cloud provider required when using cloud device pool"
            exit 1
        fi
        if [[ ! "$CLOUD_PROVIDER" =~ ^(browserstack|saucelabs)$ ]]; then
            log_error "Invalid cloud provider: $CLOUD_PROVIDER. Must be 'browserstack' or 'saucelabs'"
            exit 1
        fi
    fi

    # Validate cloud credentials
    if [[ "$DEVICE_POOL" == "cloud" && "$CLOUD_PROVIDER" == "browserstack" ]]; then
        if [[ -z "$BROWSERSTACK_USERNAME" || -z "$BROWSERSTACK_ACCESS_KEY" ]]; then
            log_error "BrowserStack credentials required: BROWSERSTACK_USERNAME and BROWSERSTACK_ACCESS_KEY"
            exit 1
        fi
    fi

    if [[ "$DEVICE_POOL" == "cloud" && "$CLOUD_PROVIDER" == "saucelabs" ]]; then
        if [[ -z "$SAUCELABS_USERNAME" || -z "$SAUCELABS_ACCESS_KEY" ]]; then
            log_error "Sauce Labs credentials required: SAUCELABS_USERNAME and SAUCELABS_ACCESS_KEY"
            exit 1
        fi
    fi
}

# Setup directories
setup_directories() {
    log_info "Setting up test directories..."
    mkdir -p "$LOGS_DIR" "$REPORTS_DIR" "$SCREENSHOTS_DIR"
    
    # Clean previous results if not dry run
    if [[ "$DRY_RUN" == "false" ]]; then
        rm -rf "$LOGS_DIR"/* "$REPORTS_DIR"/* "$SCREENSHOTS_DIR"/* 2>/dev/null || true
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check Dart
    if ! command -v dart &> /dev/null; then
        missing_deps+=("dart")
    fi
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        missing_deps+=("flutter")
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    # Check Appium
    if ! command -v appium &> /dev/null; then
        missing_deps+=("appium")
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Platform-specific checks
    if [[ "$PLATFORM" == "android" ]]; then
        if [[ -z "$ANDROID_HOME" ]]; then
            missing_deps+=("Android SDK (ANDROID_HOME not set)")
        fi
    fi
    
    if [[ "$PLATFORM" == "ios" ]]; then
        if [[ "$(uname)" != "Darwin" ]]; then
            log_error "iOS testing requires macOS"
            exit 1
        fi
        if ! command -v xcrun &> /dev/null; then
            missing_deps+=("Xcode command line tools")
        fi
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Start MQTT broker
start_mqtt_broker() {
    log_info "Starting MQTT broker on port $MQTT_PORT..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would start MQTT broker"
        return
    fi
    
    # Stop existing broker if running
    docker stop test-mosquitto 2>/dev/null || true
    docker rm test-mosquitto 2>/dev/null || true
    
    # Start new broker
    docker run -d --name test-mosquitto -p "$MQTT_PORT:1883" eclipse-mosquitto:1.6
    
    # Wait for broker to be ready
    sleep 5
    
    # Health check
    if ! "$PROJECT_ROOT/scripts/mqtt_health_check.sh"; then
        log_error "MQTT broker health check failed"
        exit 1
    fi
    
    log_success "MQTT broker started successfully"
}

# Start Appium server
start_appium_server() {
    log_info "Starting Appium server on port $APPIUM_PORT..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would start Appium server"
        return
    fi
    
    # Kill existing Appium processes
    pkill -f appium || true
    
    # Setup log level
    local log_level="${APPIUM_LOG_LEVEL:-info}"
    if [[ "$VERBOSE" == "true" ]]; then
        log_level="debug"
    fi
    
    # Start Appium server
    local appium_log="$LOGS_DIR/appium.log"
    appium server --port "$APPIUM_PORT" --allow-cors --log-level "$log_level" > "$appium_log" 2>&1 &
    local appium_pid=$!
    
    # Wait for server to start
    sleep 10
    
    # Check if server is running
    if ! kill -0 $appium_pid 2>/dev/null; then
        log_error "Appium server failed to start. Check logs: $appium_log"
        exit 1
    fi
    
    # Test connection
    if ! curl -s "http://localhost:$APPIUM_PORT/status" > /dev/null; then
        log_error "Appium server not responding on port $APPIUM_PORT"
        exit 1
    fi
    
    log_success "Appium server started successfully (PID: $appium_pid)"
    echo "$appium_pid" > "$LOGS_DIR/appium.pid"
}

# Setup device
setup_device() {
    log_info "Setting up $PLATFORM device for $DEVICE_POOL testing..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would setup device"
        return
    fi
    
    case "$DEVICE_POOL" in
        "emulator")
            if [[ "$PLATFORM" == "android" ]]; then
                setup_android_emulator
            else
                setup_ios_simulator
            fi
            ;;
        "local")
            log_info "Using local device - ensure device is connected and authorized"
            ;;
        "cloud")
            log_info "Using cloud devices - $CLOUD_PROVIDER"
            ;;
    esac
}

# Setup Android emulator
setup_android_emulator() {
    log_info "Setting up Android emulator..."
    
    # Check if emulator is already running
    if adb devices | grep -q emulator; then
        log_info "Android emulator already running"
        return
    fi
    
    # Create AVD if it doesn't exist
    local avd_name="test_avd_api29"
    if ! "$ANDROID_HOME/emulator/emulator" -list-avds | grep -q "$avd_name"; then
        log_info "Creating Android Virtual Device..."
        echo "no" | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
            -n "$avd_name" \
            -k "system-images;android-29;google_apis;x86_64" \
            --force
    fi
    
    # Start emulator
    log_info "Starting Android emulator..."
    "$ANDROID_HOME/emulator/emulator" -avd "$avd_name" -no-audio -no-window &
    
    # Wait for emulator to be ready
    log_info "Waiting for emulator to boot..."
    adb wait-for-device
    
    # Wait for system to be ready
    while [[ "$(adb shell getprop sys.boot_completed)" != "1" ]]; do
        sleep 5
    done
    
    log_success "Android emulator ready"
}

# Setup iOS simulator
setup_ios_simulator() {
    log_info "Setting up iOS simulator..."
    
    # List available simulators
    local sim_id=$(xcrun simctl list devices available | grep "iPhone 14" | head -1 | grep -o "[A-F0-9-]\{36\}")
    
    if [[ -z "$sim_id" ]]; then
        log_info "Creating iPhone 14 simulator..."
        sim_id=$(xcrun simctl create "iPhone 14 Test" "iPhone 14" "iOS17.0")
    fi
    
    # Boot simulator
    log_info "Booting iOS simulator..."
    xcrun simctl boot "$sim_id"
    
    # Wait for simulator to be ready
    sleep 10
    
    log_success "iOS simulator ready (ID: $sim_id)"
}

# Build application
build_application() {
    log_info "Building $PLATFORM application..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build application"
        return
    fi
    
    cd "$PROJECT_ROOT/apps/flutter_demo"
    
    case "$PLATFORM" in
        "android")
            flutter build apk --debug
            log_success "Android APK built successfully"
            ;;
        "ios")
            if [[ "$DEVICE_POOL" == "emulator" || "$DEVICE_POOL" == "local" ]]; then
                flutter build ios --simulator --debug
            else
                flutter build ios --debug
            fi
            log_success "iOS app built successfully"
            ;;
    esac
    
    cd - > /dev/null
}

# Execute test suite
execute_tests() {
    log_info "Executing $TEST_SUITE tests on $PLATFORM..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute tests"
        return
    fi
    
    cd "$E2E_DIR"
    
    # Determine test files based on suite
    local test_files=()
    case "$TEST_SUITE" in
        "all")
            test_files=("scenarios/mobile_lifecycle_scenarios.dart" "network/network_state_test.dart" "convergence/mobile_convergence_test.dart")
            ;;
        "lifecycle")
            test_files=("scenarios/mobile_lifecycle_scenarios.dart")
            ;;
        "network")
            test_files=("network/network_state_test.dart")
            ;;
        "convergence")
            test_files=("convergence/mobile_convergence_test.dart")
            ;;
    esac
    
    # Execute tests
    local failed_tests=()
    for test_file in "${test_files[@]}"; do
        log_info "Running test: $test_file"
        
        local test_name=$(basename "$test_file" .dart)
        local test_log="$LOGS_DIR/${test_name}_${PLATFORM}.log"
        
        # Build test command
        local test_cmd="dart run orchestrator/mobile_e2e_orchestrator.dart"
        test_cmd+=" --platform $PLATFORM"
        test_cmd+=" --device-pool $DEVICE_POOL"
        test_cmd+=" --test-file $test_file"
        test_cmd+=" --appium-port $APPIUM_PORT"
        
        if [[ "$DEVICE_POOL" == "cloud" ]]; then
            test_cmd+=" --cloud-provider $CLOUD_PROVIDER"
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            test_cmd+=" --verbose"
        fi
        
        # Execute test
        if $test_cmd > "$test_log" 2>&1; then
            log_success "Test passed: $test_name"
        else
            log_error "Test failed: $test_name (see $test_log)"
            failed_tests+=("$test_name")
        fi
    done
    
    cd - > /dev/null
    
    # Report results
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_error "Failed tests: ${failed_tests[*]}"
        return 1
    fi
}

# Cleanup resources
cleanup() {
    log_info "Cleaning up resources..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would cleanup resources"
        return
    fi
    
    # Stop Appium server
    if [[ -f "$LOGS_DIR/appium.pid" ]]; then
        local appium_pid=$(cat "$LOGS_DIR/appium.pid")
        if kill -0 "$appium_pid" 2>/dev/null; then
            kill "$appium_pid"
            log_info "Stopped Appium server (PID: $appium_pid)"
        fi
        rm -f "$LOGS_DIR/appium.pid"
    fi
    
    # Stop MQTT broker
    docker stop test-mosquitto 2>/dev/null || true
    docker rm test-mosquitto 2>/dev/null || true
    log_info "Stopped MQTT broker"
    
    # Stop Android emulator
    if [[ "$PLATFORM" == "android" && "$DEVICE_POOL" == "emulator" ]]; then
        adb emu kill 2>/dev/null || true
        log_info "Stopped Android emulator"
    fi
    
    # Stop iOS simulator
    if [[ "$PLATFORM" == "ios" && "$DEVICE_POOL" == "emulator" ]]; then
        xcrun simctl shutdown booted 2>/dev/null || true
        log_info "Stopped iOS simulator"
    fi
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    local report_file="$REPORTS_DIR/test_report_${PLATFORM}_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Mobile E2E Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        .log-section { margin-top: 20px; }
        .log-content { background-color: #f5f5f5; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Mobile E2E Test Report</h1>
        <p><strong>Platform:</strong> $PLATFORM</p>
        <p><strong>Test Suite:</strong> $TEST_SUITE</p>
        <p><strong>Device Pool:</strong> $DEVICE_POOL</p>
        <p><strong>Generated:</strong> $(date)</p>
    </div>
    
    <div class="log-section">
        <h2>Test Execution Logs</h2>
        <div class="log-content">
EOF
    
    # Add log files to report
    for log_file in "$LOGS_DIR"/*.log; do
        if [[ -f "$log_file" ]]; then
            echo "<h3>$(basename "$log_file")</h3>" >> "$report_file"
            echo "<pre>$(cat "$log_file")</pre>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "Test report generated: $report_file"
}

# Main execution
main() {
    log_info "Starting Mobile E2E Test Runner"
    log_info "Platform: $PLATFORM, Suite: $TEST_SUITE, Device Pool: $DEVICE_POOL"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No actual execution"
    fi
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Execute pipeline
    setup_directories
    check_prerequisites
    start_mqtt_broker
    start_appium_server
    setup_device
    build_application
    execute_tests
    generate_report
    
    log_success "Mobile E2E test execution completed successfully"
}

# Parse arguments and run
parse_args "$@"
validate_args
main