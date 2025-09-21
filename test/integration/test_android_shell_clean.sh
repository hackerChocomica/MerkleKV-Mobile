#!/bin/bash
# Test Android Shell Logic for android-emulator-runner compatibility

echo "🧪 Testing Android shell logic for line-by-line execution..."

# Test 1: Package verification logic with temporary file
echo "Test 1: Package verification with temporary file approach"
echo "com.merklekv.flutter_demo" > /tmp/package_check.txt
grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ App successfully installed: com.merklekv.flutter_demo" || { echo "❌ App installation failed"; exit 1; }

# Test 2: Package verification logic with NOT_FOUND case
echo "Test 2: Package verification with NOT_FOUND case"
echo "NOT_FOUND" > /tmp/package_check.txt
grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ App successfully installed: com.merklekv.flutter_demo" || echo "⚠️ App not found (expected for test)"

# Test 3: Command chaining with success case
echo "Test 3: Command chaining with success case"
true && echo "✅ Command succeeded" || { echo "❌ Command failed"; exit 1; }

# Test 4: Command chaining with failure case (should not exit)
echo "Test 4: Command chaining with failure case"
false && echo "This should not print" || echo "⚠️ Command failed as expected"

# Test 5: Test directory navigation
echo "Test 5: Directory navigation test"
cd /tmp && echo "✅ Successfully changed to /tmp directory" || { echo "❌ Failed to change directory"; exit 1; }

# Test 6: Timeout command test
echo "Test 6: Timeout command test"
timeout 2s sleep 1 && echo "✅ Timeout command works" || { echo "❌ Timeout command failed"; exit 1; }

# Test 7: Simulate the exact workflow logic
echo "Test 7: Simulating exact workflow logic"
echo "package:com.merklekv.flutter_demo" > /tmp/adb_output.txt
grep "com.merklekv.flutter_demo" /tmp/adb_output.txt > /tmp/package_check.txt || echo "NOT_FOUND" > /tmp/package_check.txt
grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ Workflow logic works correctly" || { echo "❌ Workflow logic failed"; exit 1; }

# Cleanup
rm -f /tmp/package_check.txt /tmp/adb_output.txt

echo "🎉 All shell logic tests passed! Android workflow logic is compatible with line-by-line execution."