# Android Release Guide for MerkleKV Mobile

This guide walks you through building and distributing production-ready Android releases (APK/AAB) for the Flutter demo app.

## 🚀 Quick Start

### Automated (CI/CD)
- Use the GitHub Actions workflow "Android E2E" or "Android Testing" for validation.
- For publishing, integrate Play Console upload in a protected release workflow (see Next Steps).

### Manual Local Build
```bash
# From repo root
./scripts/build-flutter.sh

# Release APK:
(cd apps/flutter_demo && flutter build apk --release)

# App Bundle (AAB) for Play Console:
(cd apps/flutter_demo && flutter build appbundle --release)
```

Artifacts:
- Debug APK: apps/flutter_demo/build/app/outputs/flutter-apk/app-debug.apk
- Release APK: apps/flutter_demo/build/app/outputs/flutter-apk/app-release.apk
- AAB: apps/flutter_demo/build/app/outputs/bundle/release/app-release.aab

## 🔐 App Signing

Android releases must be signed with a keystore.

### 1) Generate a Keystore
```bash
keytool -genkey -v -keystore merklekv-release.keystore -alias merklekv \
  -keyalg RSA -keysize 2048 -validity 10000
```

### 2) Store Credentials Securely
Create `apps/flutter_demo/android/key.properties` (do not commit):
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=merklekv
storeFile=/absolute/path/to/merklekv-release.keystore
```

### 3) Configure Gradle Signing
In `apps/flutter_demo/android/app/build.gradle` ensure:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
  // ...
  signingConfigs {
    release {
      if (keystoreProperties['storeFile']) {
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
      }
    }
  }
  buildTypes {
    release {
      signingConfig signingConfigs.release
      minifyEnabled true
      shrinkResources true
      proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
  }
}
```

## 🧪 Pre-release Checklist
- All CI workflows green (E2E, integration, network, lifecycle)
- Appium-driven scenarios pass locally for Android
- MQTT broker connectivity verified (`./scripts/mqtt_health_check.sh`)
- Version bumped in `apps/flutter_demo/pubspec.yaml` (e.g., `1.0.0+42`)

## 📦 Build Commands

```bash
# Clean & fetch deps
( cd apps/flutter_demo && flutter clean && flutter pub get )

# Build signed release APK (requires key.properties)
( cd apps/flutter_demo && flutter build apk --release )

# Build AAB for Play Console
( cd apps/flutter_demo && flutter build appbundle --release )
```

## 🚢 Publish to Google Play

1) Create an app in Play Console and set up internal testing track.
2) Upload `app-release.aab` to the track.
3) Fill in release notes and roll out.
4) Add testers, wait for review.

Tips:
- Keep package name stable: `com.merkle_kv.flutter_demo`
- Use semantic versions synced with pubspec
- Use Play signing if preferred; otherwise, manage your own keystore securely.

## 🧰 Troubleshooting
- Missing Android SDK: run `sdkmanager --licenses` and install platforms;platform-34, build-tools.
- NDK/Gradle errors: delete `~/.gradle/caches` and try again.
- Keystore not found: verify absolute path in key.properties.

## 🔗 References
- Flutter Android deployment: https://docs.flutter.dev/deployment/android
- Play Console: https://play.google.com/console
- CI workflows: `.github/workflows/android-testing.yml`, `.github/workflows/android-e2e.yml`
