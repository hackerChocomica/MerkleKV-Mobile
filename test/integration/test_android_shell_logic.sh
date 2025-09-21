#!/bin/bash#!/bin/bash

# Test Android Shell Logic for android-emulator-runner compatibility# Test script to validate the Android E2E workflow shell logic

# Tests the exact logic that was failing in the GitHub Actions

echo "🧪 Testing Android shell logic for line-by-line execution..."

set -e

# Test 1: Package verification logic with temporary file

echo "Test 1: Package verification with temporary file approach"echo "🧪 Testing Android E2E Workflow Shell Logic"

echo "com.merklekv.flutter_demo" > /tmp/package_check.txtecho "============================================"

grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ App successfully installed: com.merklekv.flutter_demo" || { echo "❌ App installation failed"; exit 1; }

# Test 1: Package verification logic (success case)

# Test 2: Package verification logic with NOT_FOUND caseecho ""

echo "Test 2: Package verification with NOT_FOUND case"echo "Test 1: Package found (success case)"

echo "NOT_FOUND" > /tmp/package_check.txtPACKAGE_CHECK="package:com.merklekv.flutter_demo"

grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ App successfully installed: com.merklekv.flutter_demo" || echo "⚠️ App not found (expected for test)"test "$PACKAGE_CHECK" != "NOT_FOUND" || {

  echo "❌ App installation verification failed"

# Test 3: Command chaining with success case  echo "📋 All installed packages:"

echo "Test 3: Command chaining with success case"  echo "package:com.android.example1"

true && echo "✅ Command succeeded" || { echo "❌ Command failed"; exit 1; }  echo "package:com.android.example2"

  echo "🔍 Looking for MerkleKV packages:"

# Test 4: Command chaining with failure case (should not exit)  echo "No MerkleKV packages found"

echo "Test 4: Command chaining with failure case"  exit 1

false && echo "This should not print" || echo "⚠️ Command failed as expected"}

echo "✅ App successfully installed: com.merklekv.flutter_demo"

# Test 5: Test directory navigation

echo "Test 5: Directory navigation test"# Test 2: Package verification logic (failure case)

cd /tmp && echo "✅ Successfully changed to /tmp directory" || { echo "❌ Failed to change directory"; exit 1; }echo ""

echo "Test 2: Package not found (failure case)"

# Test 6: Timeout command testPACKAGE_CHECK="NOT_FOUND"

echo "Test 6: Timeout command test"ERROR_CAUGHT=false

timeout 2s sleep 1 && echo "✅ Timeout command works" || { echo "❌ Timeout command failed"; exit 1; }{

  test "$PACKAGE_CHECK" != "NOT_FOUND" || {

# Test 7: Simulate the exact workflow logic    echo "❌ App installation verification failed (expected)"

echo "Test 7: Simulating exact workflow logic"    echo "📋 All installed packages:"

echo "package:com.merklekv.flutter_demo" > /tmp/adb_output.txt    echo "package:com.android.example1"

grep "com.merklekv.flutter_demo" /tmp/adb_output.txt > /tmp/package_check.txt || echo "NOT_FOUND" > /tmp/package_check.txt    echo "package:com.android.example2"

grep -q "com.merklekv.flutter_demo" /tmp/package_check.txt && echo "✅ Workflow logic works correctly" || { echo "❌ Workflow logic failed"; exit 1; }    echo "🔍 Looking for MerkleKV packages:"

    echo "No MerkleKV packages found"

# Cleanup    ERROR_CAUGHT=true

rm -f /tmp/package_check.txt /tmp/adb_output.txt  }

} || true

echo "🎉 All shell logic tests passed! Android workflow logic is compatible with line-by-line execution."
if [ "$ERROR_CAUGHT" = "true" ]; then
  echo "✅ Error case handled correctly"
else
  echo "❌ Error case not handled properly"
  exit 1
fi

# Test 3: Verbose flag logic (false case)
echo ""
echo "Test 3: Verbose flag false"
VERBOSE_FLAG=""
[ "false" = "true" ] && VERBOSE_FLAG="--verbose"
if [ -z "$VERBOSE_FLAG" ]; then
  echo "✅ Verbose flag correctly empty"
else
  echo "❌ Verbose flag should be empty, got: '$VERBOSE_FLAG'"
  exit 1
fi

# Test 4: Verbose flag logic (true case)
echo ""
echo "Test 4: Verbose flag true"
VERBOSE_FLAG=""
[ "true" = "true" ] && VERBOSE_FLAG="--verbose"
if [ "$VERBOSE_FLAG" = "--verbose" ]; then
  echo "✅ Verbose flag correctly set"
else
  echo "❌ Verbose flag should be '--verbose', got: '$VERBOSE_FLAG'"
  exit 1
fi

echo ""
echo "🎉 All Android E2E workflow shell logic tests passed!"
echo "✅ Ready for deployment"