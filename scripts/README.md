# Build & Automation Scripts

This directory contains shell scripts for building multi-platform Flutter applications and Python scripts for icon generation.

## Build Scripts Overview

| Script | Purpose | Output |
|--------|---------|--------|
| `build_unified_artifacts.sh` | **Main entry point** - Multi-platform unified build | All platforms to single output directory |
| `build_android_artifacts.sh` | Android APK/AAB build | `build/app/outputs/` |
| `build_ios_ipa_nocodesign.sh` | iOS IPA without code signing | `build/ios/ipa/` |
| `build_macos_artifact.sh` | macOS `.app` zip artifact | `build/macos/artifacts/` |
| `build_linux_artifact.sh` | Linux bundle tar.gz artifact | `build/linux/artifacts/` |
| `build_windows_artifact.sh` | Windows runner zip artifact | `build/windows/artifacts/` |

## Prerequisites

### Required Tools
- **Flutter SDK:** ^3.7.2 (managed via Flutter version manager or manual install)
- **Dart SDK:** 3.7+ (bundled with Flutter)
- **Platform SDKs:**
  - Android: Android SDK + NDK, Java 17+
  - iOS/macOS: Xcode 15+ (macOS only)
  - Linux: GTK 3, CMake, Ninja
  - Windows: Visual Studio 2019+ with C++ tools

### Environment Variables

**Optional production URL overrides:**
- `APPREAD_API_BASE_URL` - Backend API base URL override. If omitted, the app uses the production default in code: `https://www.sxyd.lltask.top/api/`
- `APPREAD_READER_GATEWAY_BASE_URL` - Book source gateway URL override. If omitted, the app uses the production default in code: `https://rust.lltask.top/api/`

**Version control:**
- `BUILD_NAME` - User-visible version (e.g., `1.3.0`)
- `BUILD_NUMBER` - Monotonic build number (e.g., `26061101`, format: `YYMMDDNN`)

**Optional:**
- `APPREAD_APP_NAME` - App identifier (default: `selune`)
- `ARTIFACT_NAME` - Build output name (default: `Selune`)
- `PDFIUM_DOWNLOAD_BASE_URL` - PDF library download base (default: GitHub mirror)

**Android-specific:**
- `ANDROID_TARGET` - `apk`, `aab`, or `both` (default: `apk`)
- `ANDROID_APK_PROFILE` - `arm64` (default), `split`, or `universal`

**Build control:**
- `AUTO_BUILD_NUMBER` - Set to `1` to auto-generate build number from date
- `VERSION_PROMPT` - Set to `0` to skip interactive version prompt
- `ALLOW_PARTIAL` - Set to `1` to allow partial platform builds on error

---

## 1. Unified Multi-Platform Build

**Script:** `build_unified_artifacts.sh`

### Purpose
Single entry point to build all platforms and consolidate output into one timestamped directory with a manifest file.

### Usage

```bash
# Auto-detect available platforms + release mode
./scripts/build_unified_artifacts.sh

# Native platforms (mobile + desktop)
./scripts/build_unified_artifacts.sh native release

# Mobile only (Android + iOS)
./scripts/build_unified_artifacts.sh mobile release

# Desktop only (macOS + Linux + Windows)
./scripts/build_unified_artifacts.sh desktop release

# Specific platforms
./scripts/build_unified_artifacts.sh android,ios,macos release

# All platforms including Web
./scripts/build_unified_artifacts.sh all release
```

### Platform Keywords

| Keyword | Expands To |
|---------|------------|
| `auto` | Platforms available on current OS |
| `native` | `android,ios,macos,linux,windows` |
| `mobile` | `android,ios` |
| `desktop` | `macos,linux,windows` |
| `all` | `android,ios,macos,linux,windows,web` |

### Output Structure

```
build/unified_artifacts/<timestamp>-<mode>/
├── Selune-Android-arm64-v8a-1.3.0-26061101.apk
├── Selune-Android-1.3.0-26061101.aab
├── Selune-iOS-1.3.0-26061101.ipa
├── Selune-macOS-1.3.0-26061101.zip
├── Selune-Linux-1.3.0-26061101.tar.gz
├── Selune-Windows-1.3.0-26061101.zip
└── manifest.txt    # Lists all built artifacts
```

### Interactive Mode
When run in a terminal without `VERSION_PROMPT=0`, the script will:
1. Show current `pubspec.yaml` version
2. Prompt for `BUILD_NAME` (display version)
3. Prompt for `BUILD_NUMBER` (build code)
4. Override Flutter's default version with provided values

### Non-Interactive Mode
```bash
BUILD_NAME=1.3.0 BUILD_NUMBER=26061101 \
APPREAD_API_BASE_URL=https://api.example.com \
APPREAD_READER_GATEWAY_BASE_URL=https://gateway.example.com/api/ \
VERSION_PROMPT=0 \
./scripts/build_unified_artifacts.sh android,ios release
```

---

## 2. Platform-Specific Scripts

### Android Build

**Script:** `build_android_artifacts.sh`

```bash
# Build arm64 APK (default, recommended for distribution)
./scripts/build_android_artifacts.sh

# Build AAB (Google Play)
ANDROID_TARGET=aab ./scripts/build_android_artifacts.sh

# Build both APK and AAB
ANDROID_TARGET=both ./scripts/build_android_artifacts.sh

# Split APKs by ABI (multiple smaller APKs)
ANDROID_APK_PROFILE=split ./scripts/build_android_artifacts.sh

# Universal APK (larger but compatible with all devices)
ANDROID_APK_PROFILE=universal ./scripts/build_android_artifacts.sh
```

**Output:** `build/app/outputs/flutter-apk/` or `build/app/outputs/bundle/release/`

**Signing:** Requires `android/key.properties` and `android/app/appread-release.jks` for release builds.

### iOS Build

**Script:** `build_ios_ipa_nocodesign.sh`

```bash
./scripts/build_ios_ipa_nocodesign.sh
```

**Output:** `build/ios/ipa/<timestamp>-<mode>/Selune-iOS-<version>.ipa`

**Note:** This builds an IPA without code signing. For App Store distribution, use Xcode or proper signing configuration.

**Requirements:** macOS with Xcode 15+

### macOS Build

**Script:** `build_macos_artifact.sh`

```bash
./scripts/build_macos_artifact.sh
```

**Output:** `build/macos/artifacts/<timestamp>-<mode>/Selune-macOS-<version>.zip`

**Requirements:** macOS with Xcode 15+

### Linux Build

**Script:** `build_linux_artifact.sh`

```bash
./scripts/build_linux_artifact.sh
```

**Output:** `build/linux/artifacts/<timestamp>-<mode>/Selune-Linux-<version>.tar.gz`

**Requirements:**
- Linux with GTK 3 development libraries
- CMake, Ninja, clang
- Install dependencies:
  ```bash
  sudo apt-get install -y \
    clang cmake libgtk-3-dev libcurl4-openssl-dev \
    liblzma-dev libsqlite3-dev ninja-build pkg-config
  ```

### Windows Build

**Script:** `build_windows_artifact.sh`

```bash
./scripts/build_windows_artifact.sh
```

**Output:** `build/windows/artifacts/<timestamp>-<mode>/Selune-Windows-<version>.zip`

**Requirements:** Windows with Visual Studio 2019+ (C++ development tools)

---

## 3. Icon Generation Scripts

### Active Script

**Script:** `generate_brand_icon_v3_ios_white.py`

**Purpose:** Generate app icons with iOS-style white base theme

```bash
python3 scripts/generate_brand_icon_v3_ios_white.py
```

**Requirements:** Python 3.7+, Pillow (PIL)
```bash
pip3 install Pillow
```

**Output:** `assets/branding/`
- `app_icon.png` - Main app icon (1024x1024)
- `app_icon_foreground.png` - Adaptive icon foreground layer

**Design:** Clean iOS-style open book icon with source node indicators, gradient background.

### Legacy Script

**Script:** `generate_brand_icon_v2.py` *(Deprecated)*

V2 uses darker gradient background. V3 is currently active and produces the icons referenced in `pubspec.yaml`.

---

## 4. Architecture Validation Scripts

### Check Architecture Guardrails

**Script:** `check_architecture_guardrails.sh`

```bash
./scripts/check_architecture_guardrails.sh
```

**Purpose:** Validate code follows architectural constraints

**Checks:**
- Layer boundaries (data → domain → presentation)
- Import restrictions
- File organization rules

### Run Architecture Green Suite

**Script:** `run_architecture_green_suite.sh`

```bash
./scripts/run_architecture_green_suite.sh
```

**Purpose:** Run full architecture validation suite including:
- Route validation
- Model code generation validation
- Architecture guardrail checks
- Theme system validation
- Storage layer validation

---

## 5. Apple Platform Preparation

**Script:** `prepare_apple_podspec_overrides.sh`

```bash
./scripts/prepare_apple_podspec_overrides.sh
```

**Purpose:** Configure CocoaPods overrides for iOS/macOS builds

**When to use:** Before building iOS or macOS if you encounter CocoaPods dependency issues.

---

## Build Workflow

### Local Development Build

```bash
# 1. Get dependencies
flutter pub get

# 2. Run in debug mode
flutter run

# 3. Build release for testing
./scripts/build_unified_artifacts.sh
```

### Production Release Build

```bash
# 1. Update version in pubspec.yaml (optional, can override via env vars)
# version: 1.3.0+26061101

# 2. Set environment variables
export APPREAD_API_BASE_URL=https://api.example.com
export APPREAD_READER_GATEWAY_BASE_URL=https://gateway.example.com/api/
export BUILD_NAME=1.3.0
export BUILD_NUMBER=26061101

# 3. Build all native platforms
./scripts/build_unified_artifacts.sh native release

# 4. Verify output
ls -lh build/unified_artifacts/<timestamp>-release/
cat build/unified_artifacts/<timestamp>-release/manifest.txt
```

### CI/CD Build (GitHub Actions)

See `.github/workflows/multiplatform-build.yml`

**Trigger:** Actions → Multiplatform Build → Run workflow

**Scope:** GitHub release builds package native installable clients only: Android, iOS, macOS, Linux, and Windows. Web is intentionally excluded from GitHub release builds; build it locally with the unified script when the Web server needs an update.

**Input:**
- `full_version`: `1.3.0+26061101` (required)

**Workflow defaults in `.github/workflows/multiplatform-build.yml`:**
- `BUILD_PLATFORMS`: `native`
- `BUILD_MODE`: `release`
- `FLUTTER_VERSION`: `3.44.1`
- `ANDROID_TARGET`: `apk`
- `ANDROID_APK_PROFILE`: `arm64`

**Secrets Required:**
- `ANDROID_KEY_PROPERTIES`
- `ANDROID_KEYSTORE_BASE64`
- `RELEASE_REPO_TOKEN`

---

## Build Times (Approximate)

| Platform | Build Time | Machine |
|----------|------------|---------|
| Android APK | 3-5 min | GitHub Actions (Ubuntu) |
| Android AAB | 3-5 min | GitHub Actions (Ubuntu) |
| iOS IPA | 8-12 min | GitHub Actions (macOS-15) |
| macOS zip | 5-8 min | GitHub Actions (macOS-15) |
| Linux tar.gz | 4-6 min | GitHub Actions (Ubuntu) |
| Windows zip | 4-6 min | GitHub Actions (Windows) |

**Total parallel build time (GitHub Actions):** ~12-15 min across 4 runners

---

## Troubleshooting

### Android Build Fails
- **Missing keystore:** Ensure `android/key.properties` and `android/app/appread-release.jks` exist
- **SDK not found:** Set `ANDROID_SDK_ROOT` or `ANDROID_HOME`
- **Java version:** Ensure Java 17+ is installed (`java -version`)

### iOS/macOS Build Fails
- **Xcode not found:** Install Xcode 15+ from App Store
- **CocoaPods issues:** Run `./scripts/prepare_apple_podspec_overrides.sh`
- **Provisioning profile:** For App Store builds, configure signing in Xcode

### Linux Build Fails
- **Missing dependencies:** Install GTK 3 dev libraries (see Linux Build section)
- **Archive creation:** Ensure `tar` is available

### Windows Build Fails
- **Visual Studio not found:** Install Visual Studio 2019+ with C++ development tools
- **Zip packaging:** Ensure Python 3 or the Windows `py -3` launcher is available

### Version Prompt Hangs in CI
- Set `VERSION_PROMPT=0` to disable interactive prompts
- Always provide `BUILD_NAME` and `BUILD_NUMBER` in CI environments

---

## Best Practices

### Before Building
1. Run `flutter clean` to clear previous builds
2. Update dependencies: `flutter pub get`
3. Validate code: `flutter analyze`
4. Run tests: `flutter test`
5. Validate architecture: `./scripts/run_architecture_green_suite.sh`

### Version Numbering
- **BUILD_NAME:** Semantic versioning (e.g., `1.3.0`)
- **BUILD_NUMBER:** `YYMMDDNN` format (e.g., `26061101` = June 11, 2026, build 01)
- Always increment `BUILD_NUMBER` for new releases (required for upgrade detection)

### Distribution
- **Android:** arm64 APK for direct distribution, AAB for Google Play
- **iOS:** IPA requires proper code signing for TestFlight/App Store
- **macOS:** zipped `.app`; notarization is still required for Gatekeeper-friendly distribution
- **Linux:** tar.gz bundle for direct distribution
- **Windows:** zipped runner folder for direct distribution

### Testing Builds
- Test on physical devices when possible
- Verify all configured environment variables (API URLs, app name)
- Check manifest.txt for expected artifacts
- Test upgrade flow from previous version

---

**Last Updated:** 2026-06-11  
**Maintained by:** Project team

For architecture decisions and governance, see `docs/governance/`.
For build and release workflows, see `docs/operations/`.
