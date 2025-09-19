#!/bin/bash

# Flutter build script that ensures correct working directory
# This fixes the CI/CD issue where 'cd' and 'flutter build' are separate commands

set -e  # Exit on any error

echo "🏗️  MerkleKV Flutter Build Script"
echo "==============================="

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLUTTER_APP_DIR="$PROJECT_ROOT/apps/flutter_demo"

echo "📁 Project root: $PROJECT_ROOT"
echo "📱 Flutter app: $FLUTTER_APP_DIR"

# Verify Flutter app directory exists
if [ ! -d "$FLUTTER_APP_DIR" ]; then
    echo "❌ Flutter app directory not found: $FLUTTER_APP_DIR"
    exit 1
fi

# Verify main.dart exists
if [ ! -f "$FLUTTER_APP_DIR/lib/main.dart" ]; then
    echo "❌ main.dart not found in: $FLUTTER_APP_DIR/lib/"
    exit 1
fi

echo "✅ Files verified. Starting build..."

# Change to Flutter app directory and build
cd "$FLUTTER_APP_DIR"

echo "📍 Current directory: $(pwd)"
echo "📋 Available targets:"
ls -la lib/main*.dart

echo ""
echo "🚀 Building Flutter APK (debug)..."
flutter build apk --debug

echo ""
echo "✅ Build completed successfully!"

# Show APK info
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-debug.apk | cut -f1)
    echo "📦 APK created: $APK_SIZE"
    echo "📍 Location: $FLUTTER_APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
else
    echo "⚠️  APK file not found after build"
fi