# Contributing to MerkleKV Mobile

Thanks for contributing! This guide explains how to develop, test, and submit changes to the MerkleKV Mobile monorepo. The project centers on Flutter/Dart for the demo app and core packages, with MQTT-based replication and rigorous CI.

## 🚀 Latest Updates

### Enhanced Replication System (Current)
- **Event Publisher**: Production-ready replication with persistent outbox queue
- **CBOR Serialization**: Efficient binary encoding for replication events  
- **Observability**: Comprehensive metrics and monitoring capabilities
- **CI/CD**: Robust testing pipeline with MQTT broker integration

## 🎯 Project Overview

MerkleKV Mobile is an **MQTT-only** distributed key-value store with **Locked Specification v1.0**.
All contributions must adhere to the locked specification constraints to ensure compatibility and
deterministic behavior.

### Locked Spec v1.0 Constraints

**These are IMMUTABLE for v1.x releases:**

- **Transport**: MQTT-only (no HTTP, WebSocket, or other protocols)
- **MQTT Settings**: QoS=1, retain=false (never changed)
- **Topic Structure**:
  - Commands/Responses: `{prefix}/{client_id}/cmd` and `{prefix}/{client_id}/res`
  - Replication: `{prefix}/replication/events`
- **Size Limits**:
  - Key: ≤256 bytes
  - Value: ≤256 KiB
  - Command payload: ≤512 KiB
- **Timeouts**:
  - Command timeout: 10 seconds
  - Replication timeout: 20 seconds
  - Connection timeout: 30 seconds
  - Reconnect backoff: 1→32 seconds with ±20% jitter
- **Conflict Resolution**: Last-Writer-Wins (LWW) with vector timestamps
- **Operations**: Must be idempotent and deterministic

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.16.0+ (stable channel)
- Dart SDK 3.0.0+
- Android SDK (for Android builds)
- Xcode 15+ on macOS (for iOS builds)
- Docker (for running a local MQTT broker)
- Git and Conventional Commits knowledge

### Repository Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/MerkleKV-Mobile.git
cd MerkleKV-Mobile

# Install Melos and bootstrap the workspace
dart pub global activate melos
melos bootstrap

# Fetch Flutter/Dart dependencies
flutter pub get
pushd packages/merkle_kv_core && dart pub get && popd
```

## Build & Test

Policy: Do not skip tests. Validate locally before committing and opening a PR.

```bash
# Static analysis (strict)
dart analyze .
dart format --output=none --set-exit-if-changed .

# Core package tests (Dart VM)
dart test -p vm packages/merkle_kv_core

# Flutter tests for the demo app
( cd apps/flutter_demo && flutter test )

# Integration/E2E helpers
./scripts/mqtt_health_check.sh
./scripts/run_integration_tests.sh
./scripts/run_e2e_tests.sh --platform android --suite all
```

Notes:
- Sensitive data must not be logged; use masked configuration printing.
- Integration tests require an MQTT broker; CI spins up Mosquitto.

### Formatting Requirement

All Dart code must be formatted using the official Dart formatter.  
Run the following before pushing:

```bash
dart format .
dart format --output=none --set-exit-if-changed .
```

PRs with unformatted code will be rejected by CI.

## 📋 Contribution Process

### 1. Issue First Approach

**All contributions must start with an issue or RFC:**

- **Bug fixes**: Create a bug report issue
- **New features**: Create a feature request or RFC
- **Breaking changes**: Always require an RFC
- **Spec changes**: Forbidden for v1.x (create RFC for v2.0)

### 2. Branching Strategy

- **Main branch**: `main` (protected, requires PR)
- **Feature branches**: `feature/issue-number-short-description`
- **Bug fixes**: `fix/issue-number-short-description`
- **Documentation**: `docs/issue-number-short-description`

### 3. Commit Messages

We use **Conventional Commits** specification:

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**

- `feat`: New feature (MINOR version)
- `fix`: Bug fix (PATCH version)
- `docs`: Documentation only
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring without feature/fix
- `perf`: Performance improvements
- `test`: Adding/modifying tests
- `chore`: Build process, dependencies, etc.

**Examples:**

```bash
feat(mqtt): add connection retry with exponential backoff
fix(replication): ensure vector timestamp consistency
docs(api): update command timeout specifications
test(core): add idempotency validation tests
```

### 4. Pull Request Process

1. **Create PR from your branch to `main`**
2. **Fill out the PR template completely**
3. **Ensure all checks pass**:
   - Tests pass
   - Linting passes
   - Spec compliance validated
   - Documentation updated
4. **Request review from appropriate CODEOWNERS**
5. **Address feedback promptly**
6. **Squash and merge** when approved

## ✅ Code Standards

### Specification Compliance

**All code must comply with Locked Spec v1.0:**

- [ ] Uses only MQTT transport (no fallbacks)
- [ ] Sets QoS=1, retain=false for all MQTT operations
- [ ] Validates key size ≤256 bytes
- [ ] Validates value size ≤256 KiB
- [ ] Validates command payload ≤512 KiB
- [ ] Implements proper timeout handling (10/20/30s)
- [ ] Uses exponential backoff with jitter for reconnection
- [ ] Ensures operation idempotency
- [ ] Implements deterministic behavior
- [ ] Uses LWW conflict resolution with vector timestamps

### Code Quality

- Dart/Flutter: idiomatic, strongly typed code
- Testing: aim for 80%+ coverage for core logic
- Linting/formatting: dart analyze + dart format enforced in CI
- Documentation: update README/docs for user-facing changes
- Error handling: cover edge cases and failure modes

### Architecture Principles

- **Idempotency**: All operations must be safely repeatable
- **Determinism**: Same input always produces same output
- **Offline-First**: Graceful degradation without connectivity
- **Mobile-Optimized**: Efficient battery and bandwidth usage
- **MQTT-Native**: Leverage MQTT patterns, don't fight them

## 🧪 Testing Requirements

### Test Categories

1. **Unit Tests**: Individual component testing
2. **Integration Tests**: MQTT broker interaction
3. **Spec Compliance Tests**: Validate Locked Spec adherence
4. **Property Tests**: Idempotency and determinism validation
5. **Mobile Tests**: Battery, memory, network efficiency

CBOR serialization includes golden vector tests to enforce deterministic output across devices.

### Required Test Scenarios

**For every feature:**

- [ ] Happy path functionality
- [ ] Error conditions and edge cases
- [ ] Network disconnection/reconnection
- [ ] Concurrent operation handling
- [ ] Spec constraint validation (size limits, timeouts)
- [ ] Idempotency verification
- [ ] Mobile performance impact

**For MQTT operations:**

- [ ] QoS=1 delivery confirmation
- [ ] retain=false verification
- [ ] Topic structure compliance
- [ ] Payload size validation
- [ ] Timeout behavior testing

### Test Commands (Quick Reference)

```bash
dart analyze .
dart test -p vm packages/merkle_kv_core
( cd apps/flutter_demo && flutter test )
./scripts/run_integration_tests.sh
./scripts/run_e2e_tests.sh --platform android --suite all
```

## 📚 Documentation Requirements

### Code Documentation

- **Public APIs**: Complete JSDoc with examples
- **Complex Logic**: Inline comments explaining the "why"
- **Spec References**: Link to relevant spec sections
- **Examples**: Working code samples for new features

### Documentation Updates

**Required for every PR:**

- [ ] Update API documentation for new/changed interfaces
- [ ] Add/update examples for new features
- [ ] Update README.md if user-facing changes
- [ ] Update CHANGELOG.md following Keep a Changelog format
- [ ] Update migration guides for breaking changes (v2.0+)

## 🔒 Security Considerations

### Security Requirements

- **TLS ≥1.2**: All MQTT connections must use TLS 1.2+
- **ACL Validation**: Proper access control for all operations
- **Input Validation**: Sanitize all user inputs
- **No Secrets in Code**: Use environment variables
- **Dependency Security**: Regular security audits

### Security Review Process

- **Security-sensitive changes** require security team review
- **Use SECURITY.md** for reporting vulnerabilities
- **Follow responsible disclosure** practices

## 🚫 What We Don't Accept

### Spec Violations

- Changes to MQTT QoS or retain settings
- Alternative transport protocols (HTTP, WebSocket, etc.)
- Modifications to topic structure
- Changes to size limits or timeout values
- Non-idempotent operations
- Non-deterministic behavior

### Code Quality Issues

- Code without tests
- Breaking changes without RFC
- Undocumented public APIs
- Performance regressions
- Security vulnerabilities
- Dependencies with known vulnerabilities

## 📞 Getting Help

### Communication Channels

- **Issues**: GitHub Issues for bugs and feature requests
- **Discussions**: GitHub Discussions for questions and ideas
- **RFCs**: Formal proposals for significant changes
- **Security**: SECURITY.md for vulnerability reports

### Code Review Process

- **Maintainers**: Core team members with merge rights
- **CODEOWNERS**: Automatic assignment by file path
- **Review Requirements**:
  - 1+ maintainer approval for bug fixes
  - 2+ maintainer approvals for features
  - Security team approval for security changes

### Response Times

- **Initial Response**: Within 2 business days
- **Review Turnaround**: Within 5 business days
- **Security Issues**: Within 24 hours

## 🏆 Recognition

Contributors are recognized in:

- **CHANGELOG.md**: Feature and fix credits
- **Release Notes**: Major contribution highlights
- **Contributors Graph**: GitHub contribution tracking
- **Hall of Fame**: Outstanding contributors section

## 📄 License

By contributing to MerkleKV Mobile, you agree that your contributions will be licensed under the project's license terms.

### Running Integration Tests

- **Start broker (Docker)**:
  ```bash
  docker run -d --rm --name mosquitto -p 1883:1883 eclipse-mosquitto:2
  # For Mosquitto v2, if connections are refused, run with a config that enables:
  #   listener 1883 0.0.0.0
  #   allow_anonymous true
  ```

- **Environment (defaults)**:
  ```bash
  export MQTT_HOST=127.0.0.1
  export MQTT_PORT=1883
  ```

- **Execute**:
  ```bash
  dart test -t integration --timeout=90s
  ```

- **Enforce broker requirement (CI/strict runs)**:
  ```bash
  IT_REQUIRE_BROKER=1 dart test -t integration --timeout=90s
  ```

- **Dev default gracefully skips when no broker is available** (`IT_REQUIRE_BROKER=0`).

---

**Questions?** Open a GitHub Discussion or check our documentation at [docs/](./docs/).

**Ready to contribute?** Start by browsing good first issues.
