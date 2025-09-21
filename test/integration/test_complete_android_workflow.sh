#!/bin/bash
# Test complete Android E2E workflow logic

echo "🧪 Testing complete Android E2E workflow logic..."

# Simulate the exact workflow commands
echo "📋 Running exact workflow command sequence..."

# Test 1: Package installation simulation
echo "Test 1: Package installation and verification"
echo "Running Android E2E tests for suite: integration"
echo "🚀 Installing APK on Android emulator..."
echo "Performing Streamed Install"
echo "Success"
sleep 1

# Test 2: Package verification
echo "🔍 Verifying app installation..."
echo "package:com.merklekv.flutter_demo" | grep "com.merklekv.flutter_demo" > /tmp/package_check.txt || echo "NOT_FOUND" > /tmp/package_check.txt
grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ App successfully installed: com.merklekv.flutter_demo" || { echo "❌ App installation failed"; echo "package:com.android.example" | head -20; exit 1; }

# Test 3: Combined directory navigation and test execution
echo "🧪 Starting Android E2E tests..."
cd test/e2e/tests && echo "Successfully navigated to test directory: $(pwd)" || { echo "❌ Failed to navigate to test directory"; exit 1; }

# Test 4: Dart test execution (with timeout simulation)
echo "📱 Executing Android E2E test..."
timeout 10s dart android_e2e_test.dart --suite integration || { echo "❌ Test execution failed or timed out"; exit 1; }

echo "✅ Android E2E tests completed successfully for suite: integration"

# Cleanup
rm -f /tmp/package_check.txt

echo "🎉 Complete Android E2E workflow logic test PASSED!"