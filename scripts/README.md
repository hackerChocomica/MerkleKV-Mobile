# MerkleKV Mobile Build Scripts

This directory contains build scripts to ensure reliable CI/CD pipeline execution.

## Scripts

### `build-flutter.sh`

**Purpose**: Reliable Flutter APK build script that handles working directory correctly.

**Problem it solves**: 
The CI/CD pipeline was failing with "Target file lib/main.dart not found" because the `cd` and `flutter build` commands were executed as separate shell processes, causing the working directory to reset.

**Usage**:
```bash
# From project root
./scripts/build-flutter.sh

# Or from any directory
/path/to/MerkleKV-Mobile/scripts/build-flutter.sh
```

**Features**:
- ✅ Automatically detects project structure
- ✅ Verifies Flutter app directory and main.dart existence  
- ✅ Changes to correct working directory before build
- ✅ Shows detailed progress and file listings
- ✅ Reports APK size and location
- ✅ Proper error handling with exit codes

**CI/CD Integration**:
Replace individual commands:
```bash
# ❌ This fails in CI/CD:
cd apps/flutter_demo
flutter build apk --debug

# ✅ Use this instead:
./scripts/build-flutter.sh
```

### `build_ios_release.sh`

Purpose: Build a complete iOS IPA for distribution on macOS. Wraps flutter build ios, manages versioning, installs CocoaPods, and zips the Runner.app into an IPA with a build info summary.

Usage:
```bash
# From project root (macOS only)
./scripts/build_ios_release.sh -v 1.2.0 -b 42 -e production

# Defaults if no flags provided
./scripts/build_ios_release.sh
```

Key features:
- ✅ Updates pubspec version to <version>+<build>
- ✅ Cleans, fetches deps, runs pod install
- ✅ Builds --release --no-codesign for device (arm64)
- ✅ Produces releases/MerkleKV-Mobile-v<version>-<build>.ipa
- ✅ Generates releases/build-info-v<version>-<build>.txt

Requirements:
- macOS with Xcode 15+
- Flutter 3.16.0+
- CocoaPods installed

## Requirements

- Flutter SDK 3.16.0+
- Android SDK and toolchain
- Bash shell environment

## Error Handling

The script will exit with error code 1 if:
- Flutter app directory not found
- main.dart file missing
- Flutter build fails

## Output

```
🏗️  MerkleKV Flutter Build Script
===============================
📁 Project root: /path/to/MerkleKV-Mobile
📱 Flutter app: /path/to/MerkleKV-Mobile/apps/flutter_demo
✅ Files verified. Starting build...
📍 Current directory: /path/to/MerkleKV-Mobile/apps/flutter_demo
📋 Available targets:
-rw-r--r-- 1 user user 1120 main.dart
-rw-r--r-- 1 user user 3490 main_beta.dart
-rw-r--r-- 1 user user 3448 main_beta_simple.dart

🚀 Building Flutter APK (debug)...
✓ Built build/app/outputs/flutter-apk/app-debug.apk

✅ Build completed successfully!
📦 APK created: 87M
📍 Location: /path/to/MerkleKV-Mobile/apps/flutter_demo/build/app/outputs/flutter-apk/app-debug.apk
```