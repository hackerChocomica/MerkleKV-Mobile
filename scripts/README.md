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