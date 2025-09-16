#!/bin/bash

# Android Mobile E2E Testing Setup Script
# This script sets up the complete Android testing environment

set -e

echo "🚀 Setting up Android Mobile E2E Testing Environment"
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed. Please install Flutter 3.16.0 or higher."
        exit 1
    fi
    
    flutter_version=$(flutter --version | head -n1 | cut -d' ' -f2)
    print_success "Flutter $flutter_version found"
    
    # Check Java
    if ! command -v java &> /dev/null; then
        print_error "Java is not installed. Please install JDK 17 or higher."
        exit 1
    fi
    
    java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
    print_success "Java $java_version found"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker for MQTT broker testing."
        exit 1
    fi
    
    print_success "Docker found"
    
    # Check Android SDK
    if [ -z "$ANDROID_HOME" ]; then
        print_error "ANDROID_HOME is not set. Please set up Android SDK."
        exit 1
    fi
    
    print_success "Android SDK found at $ANDROID_HOME"
}

# Install Flutter dependencies
install_dependencies() {
    print_status "Installing Flutter dependencies..."
    
    cd apps/flutter_demo
    
    if flutter pub get; then
        print_success "Flutter dependencies installed"
    else
        print_error "Failed to install Flutter dependencies"
        exit 1
    fi
    
    cd ../..
}

# Setup MQTT broker
setup_mqtt_broker() {
    print_status "Setting up MQTT broker..."
    
    # Stop existing broker if running
    if docker ps | grep -q test-mosquitto; then
        print_status "Stopping existing MQTT broker..."
        docker stop test-mosquitto > /dev/null 2>&1 || true
    fi
    
    # Remove existing container
    if docker ps -a | grep -q test-mosquitto; then
        print_status "Removing existing MQTT broker container..."
        docker rm test-mosquitto > /dev/null 2>&1 || true
    fi
    
    # Start new MQTT broker
    if docker run -d --name test-mosquitto -p 1883:1883 eclipse-mosquitto:1.6 > /dev/null; then
        print_success "MQTT broker started on port 1883"
    else
        print_error "Failed to start MQTT broker"
        exit 1
    fi
    
    # Wait for broker to be ready
    print_status "Waiting for MQTT broker to be ready..."
    sleep 5
    
    # Test MQTT connectivity
    if ./scripts/mqtt_health_check.sh > /dev/null 2>&1; then
        print_success "MQTT broker connectivity verified"
    else
        print_warning "MQTT broker connectivity test failed, but continuing..."
    fi
}

# Setup Android emulators
setup_android_emulators() {
    print_status "Setting up Android emulators..."
    
    # Define API levels to test
    api_levels=(21 26 30)
    
    for api in "${api_levels[@]}"; do
        print_status "Setting up Android API $api emulator..."
        
        # Check if system image exists
        if ! $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --list | grep -q "system-images;android-$api;google_apis;x86_64"; then
            print_status "Installing system image for Android API $api..."
            echo "y" | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-$api;google_apis;x86_64"
        fi
        
        # Check if AVD exists
        if ! $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager list avd | grep -q "Android_$api"; then
            print_status "Creating AVD for Android API $api..."
            echo "no" | $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd \
                -n "Android_$api" \
                -k "system-images;android-$api;google_apis;x86_64" \
                --force
        fi
        
        print_success "Android API $api emulator configured"
    done
}

# Run test verification
run_test_verification() {
    print_status "Running test verification..."
    
    cd apps/flutter_demo
    
    # Run static analysis
    print_status "Running static analysis..."
    if flutter analyze; then
        print_success "Static analysis passed"
    else
        print_warning "Static analysis has warnings (this is expected)"
    fi
    
    # Run utility tests
    print_status "Running utility tests..."
    if flutter test test/mobile_e2e/utils/; then
        print_success "Utility tests passed"
    else
        print_error "Utility tests failed"
        cd ../..
        exit 1
    fi
    
    cd ../..
}

# Create test script
create_test_script() {
    print_status "Creating test runner script..."
    
    cat > run_android_e2e_tests.sh << 'EOF'
#!/bin/bash

# Android E2E Test Runner Script

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run specific test suite
run_test_suite() {
    local test_file=$1
    local test_name=$2
    
    print_status "Running $test_name..."
    
    cd apps/flutter_demo
    
    if flutter test "$test_file" --reporter json > "test_results_$(basename $test_file .dart).json"; then
        print_success "$test_name completed"
    else
        print_error "$test_name failed"
        return 1
    fi
    
    cd ../..
}

# Main test execution
main() {
    print_status "Starting Android Mobile E2E Tests"
    
    # Check MQTT broker
    if ! docker ps | grep -q test-mosquitto; then
        print_error "MQTT broker is not running. Please run setup script first."
        exit 1
    fi
    
    # Test suites
    declare -A test_suites=(
        ["test/mobile_e2e/android/android_lifecycle_test.dart"]="Android Lifecycle Tests"
        ["test/mobile_e2e/android/android_network_state_test.dart"]="Android Network State Tests"
        ["test/mobile_e2e/android/android_convergence_test.dart"]="Android Convergence Tests"
        ["test/mobile_e2e/android/android_platform_specific_test.dart"]="Android Platform-Specific Tests"
        ["test/mobile_e2e/android/android_multi_device_test.dart"]="Android Multi-Device Tests"
        ["test/mobile_e2e/android/android_security_test.dart"]="Android Security Tests"
    )
    
    # Run all test suites
    failed_tests=()
    
    for test_file in "${!test_suites[@]}"; do
        if ! run_test_suite "$test_file" "${test_suites[$test_file]}"; then
            failed_tests+=("${test_suites[$test_file]}")
        fi
    done
    
    # Report results
    echo ""
    print_status "Test Results Summary"
    echo "===================="
    
    if [ ${#failed_tests[@]} -eq 0 ]; then
        print_success "All test suites passed!"
    else
        print_error "Failed test suites:"
        for failed_test in "${failed_tests[@]}"; do
            echo "  - $failed_test"
        done
        exit 1
    fi
}

# Command line options
case "${1:-all}" in
    "lifecycle")
        run_test_suite "test/mobile_e2e/android/android_lifecycle_test.dart" "Android Lifecycle Tests"
        ;;
    "network")
        run_test_suite "test/mobile_e2e/android/android_network_state_test.dart" "Android Network State Tests"
        ;;
    "convergence")
        run_test_suite "test/mobile_e2e/android/android_convergence_test.dart" "Android Convergence Tests"
        ;;
    "platform")
        run_test_suite "test/mobile_e2e/android/android_platform_specific_test.dart" "Android Platform-Specific Tests"
        ;;
    "multidevice")
        run_test_suite "test/mobile_e2e/android/android_multi_device_test.dart" "Android Multi-Device Tests"
        ;;
    "security")
        run_test_suite "test/mobile_e2e/android/android_security_test.dart" "Android Security Tests"
        ;;
    "all")
        main
        ;;
    *)
        echo "Usage: $0 [lifecycle|network|convergence|platform|multidevice|security|all]"
        exit 1
        ;;
esac
EOF

    chmod +x run_android_e2e_tests.sh
    print_success "Test runner script created: run_android_e2e_tests.sh"
}

# Main setup function
main() {
    echo ""
    print_status "Starting Android Mobile E2E Testing Setup"
    echo ""
    
    check_prerequisites
    echo ""
    
    install_dependencies
    echo ""
    
    setup_mqtt_broker
    echo ""
    
    setup_android_emulators
    echo ""
    
    run_test_verification
    echo ""
    
    create_test_script
    echo ""
    
    print_success "Android Mobile E2E Testing Environment Setup Complete!"
    echo ""
    echo "Next steps:"
    echo "1. Run all tests: ./run_android_e2e_tests.sh"
    echo "2. Run specific test suite: ./run_android_e2e_tests.sh lifecycle"
    echo "3. Check documentation: docs/android-mobile-e2e-testing.md"
    echo ""
    echo "Available test suites:"
    echo "  - lifecycle: Android lifecycle testing"
    echo "  - network: Network state testing"
    echo "  - convergence: Convergence validation"
    echo "  - platform: Platform-specific testing"
    echo "  - multidevice: Multi-device synchronization"
    echo "  - security: Security and privacy testing"
    echo ""
}

# Run main function
main "$@"