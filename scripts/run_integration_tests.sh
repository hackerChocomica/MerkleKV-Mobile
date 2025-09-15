#!/bin/bash
set -e

# Integration Test Runner for MerkleKV Mobile
# Runs comprehensive integration tests with real MQTT brokers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.test.yml"
CERT_DIR="$PROJECT_ROOT/test/integration/certs"
TEST_DIR="$PROJECT_ROOT/packages/merkle_kv_core/test/integration"

# Detect Docker Compose command (v1 vs v2)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "Error: Neither 'docker-compose' nor 'docker compose' is available"
    exit 1
fi

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

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    log_success "Cleanup completed"
}

# Set up cleanup on exit
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose (v1 or v2)
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        log_error "Docker Compose is not installed or not available (tried both v1 and v2)"
        exit 1
    fi
    
    # Check Dart
    if ! command -v dart &> /dev/null; then
        log_error "Dart is not installed or not in PATH"
        exit 1
    fi
    
    # Check OpenSSL
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL is not installed or not in PATH"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Generate test certificates
generate_certificates() {
    log_info "Generating test certificates..."
    
    if [ ! -f "$PROJECT_ROOT/test/integration/generate_certs.sh" ]; then
        log_error "Certificate generation script not found"
        exit 1
    fi
    
    chmod +x "$PROJECT_ROOT/test/integration/generate_certs.sh"
    "$PROJECT_ROOT/test/integration/generate_certs.sh"
    
    if [ ! -f "$PROJECT_ROOT/test/integration/convert_certs.sh" ]; then
        log_error "Certificate conversion script not found"
        exit 1
    fi
    
    chmod +x "$PROJECT_ROOT/test/integration/convert_certs.sh"
    "$PROJECT_ROOT/test/integration/convert_certs.sh"
    
    log_success "Certificates generated successfully"
}

# Install Dart dependencies
install_dependencies() {
    log_info "Installing Dart dependencies..."
    
    cd "$PROJECT_ROOT/packages/merkle_kv_core"
    dart pub get
    
    log_success "Dependencies installed"
}

# Start test infrastructure
start_infrastructure() {
    log_info "Starting test infrastructure..."
    
    # Start brokers
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    
    # Wait for Mosquitto
    log_info "Waiting for Mosquitto to be ready..."
    timeout 60 sh -c 'until '$DOCKER_COMPOSE' -f "'"$COMPOSE_FILE"'" exec -T mosquitto-test mosquitto_sub -h localhost -t "\$SYS/broker/uptime" -C 1 >/dev/null 2>&1; do sleep 2; done' || {
        log_error "Mosquitto failed to start within timeout"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs mosquitto-test
        exit 1
    }
    log_success "Mosquitto is ready"
    
    # Wait for HiveMQ
    log_info "Waiting for HiveMQ to be ready..."
    timeout 60 sh -c 'until curl -f http://localhost:8080/api/v1/mqtt/clients >/dev/null 2>&1; do sleep 2; done' || {
        log_warning "HiveMQ health check failed (may be expected in some environments)"
    }
    
    # Wait for Toxiproxy
    log_info "Waiting for Toxiproxy to be ready..."
    timeout 30 sh -c 'until curl -f http://localhost:8474/version >/dev/null 2>&1; do sleep 1; done' || {
        log_warning "Toxiproxy not ready (network partition tests may fail)"
    }
    
    log_success "Test infrastructure started"
}

# Configure network simulation
configure_toxiproxy() {
    log_info "Configuring Toxiproxy for network simulation..."
    
    # Create proxy endpoints
    curl -X POST http://localhost:8474/proxies \
        -H "Content-Type: application/json" \
        -d '{"name": "mosquitto_proxy", "listen": "0.0.0.0:1885", "upstream": "mosquitto-test:1883"}' \
        >/dev/null 2>&1 || log_warning "Failed to create Mosquitto proxy"
        
    curl -X POST http://localhost:8474/proxies \
        -H "Content-Type: application/json" \
        -d '{"name": "hivemq_proxy", "listen": "0.0.0.0:1886", "upstream": "hivemq-test:1883"}' \
        >/dev/null 2>&1 || log_warning "Failed to create HiveMQ proxy"
        
    log_success "Network simulation configured"
}

# Run specific test suite
run_test_suite() {
    local test_suite="$1"
    local test_file="$TEST_DIR/${test_suite}_test.dart"
    
    if [ ! -f "$test_file" ]; then
        log_error "Test file not found: $test_file"
        return 1
    fi
    
    log_info "Running test suite: $test_suite"
    
    cd "$PROJECT_ROOT/packages/merkle_kv_core"
    
    if dart test "$test_file" --timeout=300s --concurrency=1; then
        log_success "Test suite '$test_suite' passed"
        return 0
    else
        log_error "Test suite '$test_suite' failed"
        return 1
    fi
}

# Run all integration tests
run_all_tests() {
    local failed_tests=()
    local test_suites=(
        "end_to_end_operations"
        "payload_limits"
        "security"
        "convergence"
        "multi_client"
    )
    
    log_info "Running all integration test suites..."
    
    for test_suite in "${test_suites[@]}"; do
        if ! run_test_suite "$test_suite"; then
            failed_tests+=("$test_suite")
        fi
        echo "" # Add spacing between test suites
    done
    
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All integration tests passed!"
        return 0
    else
        log_error "Failed test suites: ${failed_tests[*]}"
        return 1
    fi
}

# Show broker status
show_broker_status() {
    log_info "Broker status:"
    
    # Mosquitto status
    if $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T mosquitto-test mosquitto_pub -h localhost -t "test/status" -m "check" >/dev/null 2>&1; then
        log_success "Mosquitto: Running"
    else
        log_error "Mosquitto: Not responding"
    fi
    
    # HiveMQ status
    if curl -f http://localhost:8080/api/v1/mqtt/clients >/dev/null 2>&1; then
        log_success "HiveMQ: Running"
    else
        log_warning "HiveMQ: Not responding (may be expected)"
    fi
    
    # Toxiproxy status
    if curl -f http://localhost:8474/version >/dev/null 2>&1; then
        log_success "Toxiproxy: Running"
    else
        log_warning "Toxiproxy: Not responding"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTION]

Integration Test Runner for MerkleKV Mobile

OPTIONS:
    -h, --help                  Show this help message
    -s, --suite SUITE           Run specific test suite
    -a, --all                   Run all integration tests (default)
    -c, --check                 Check prerequisites only
    -t, --status               Show broker status
    -v, --verbose              Enable verbose output
    --setup-only              Set up infrastructure only (don't run tests)
    --cleanup-only            Clean up infrastructure only

TEST SUITES:
    end_to_end_operations      Basic GET/SET/DEL operations
    payload_limits             256KiB values and 512KiB bulk operations
    security                   TLS/ACL security enforcement
    convergence               Anti-entropy convergence validation
    multi_client              Multi-client concurrent operations

EXAMPLES:
    $0                         Run all integration tests
    $0 -s security            Run only security tests
    $0 -c                     Check prerequisites
    $0 --setup-only           Set up test environment only
    $0 --status               Show broker status

EOF
}

# Main function
main() {
    local test_suite=""
    local run_all=true
    local check_only=false
    local setup_only=false
    local cleanup_only=false
    local show_status=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--suite)
                test_suite="$2"
                run_all=false
                shift 2
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            -c|--check)
                check_only=true
                shift
                ;;
            -t|--status)
                show_status=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                set -x
                shift
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            --cleanup-only)
                cleanup_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle special modes
    if [ "$cleanup_only" = true ]; then
        cleanup
        exit 0
    fi
    
    if [ "$check_only" = true ]; then
        check_prerequisites
        exit 0
    fi
    
    if [ "$show_status" = true ]; then
        show_broker_status
        exit 0
    fi
    
    # Main execution flow
    check_prerequisites
    generate_certificates
    install_dependencies
    start_infrastructure
    configure_toxiproxy
    
    if [ "$setup_only" = true ]; then
        log_success "Test infrastructure set up successfully"
        echo ""
        log_info "Infrastructure is running. To run tests manually:"
        echo "  cd packages/merkle_kv_core"
        echo "  dart test test/integration/<test_suite>_test.dart"
        echo ""
        log_info "To clean up, run: $0 --cleanup-only"
        
        # Don't run cleanup trap
        trap - EXIT
        exit 0
    fi
    
    # Run tests
    if [ "$run_all" = true ]; then
        if run_all_tests; then
            exit 0
        else
            exit 1
        fi
    elif [ -n "$test_suite" ]; then
        if run_test_suite "$test_suite"; then
            exit 0
        else
            exit 1
        fi
    else
        log_error "No test suite specified"
        show_usage
        exit 1
    fi
}

# Run main function with all arguments
main "$@"