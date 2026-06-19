# Flutter AppRead - Project Guide for AI Assistants

## Project Overview

Flutter reading app focused on local book reading and server-based book source gateway. Multi-platform support: Android, iOS, macOS, Linux, Windows, Web.

**Project Name:** 书享阅读  
**Current Version:** 1.3.0+26061101  
**Flutter SDK:** ^3.7.2  
**Primary Language:** Dart 3.7+

## Architecture

### Clean Architecture Pattern

```
lib/
├── app/           # Application shell & coordination
│   ├── composition/   # Dependency injection (Riverpod providers)
│   ├── theme/         # Theme configuration
│   ├── navigation/    # GoRouter navigation
│   ├── lifecycle/     # App lifecycle management
│   └── services/      # App-level services
├── core/          # Cross-cutting concerns
│   ├── auth/          # Authentication
│   ├── storage/       # Local storage (Drift database)
│   ├── network/       # HTTP client (Dio)
│   ├── session/       # User session management
│   ├── cache/         # Caching layer
│   └── device/        # Device information
├── data/          # Data layer
│   ├── datasources/   # Remote & local data sources
│   ├── repositories/  # Repository implementations
│   ├── models/        # Data models
│   └── adapters/      # Data adapters
├── domain/        # Business logic
│   ├── entities/      # Domain entities
│   ├── repositories/  # Repository interfaces
│   └── usecases/      # Business use cases
├── features/      # Feature modules (13 features)
│   ├── auth/          # User authentication
│   ├── reader/        # Book reading (EPUB, PDF, TXT, etc.)
│   ├── book/          # Book management
│   ├── source/        # Book source management
│   ├── home/          # Home screen
│   ├── mine/          # User profile & settings
│   ├── search/        # Book search
│   └── ...            # Other features
├── runtime/       # Runtime infrastructure
│   ├── sources/       # Book source runtime
│   ├── cache/         # Runtime caching
│   ├── http/          # HTTP runtime
│   ├── crypto/        # Cryptography
│   └── session/       # Session runtime
└── shared/        # Shared utilities & widgets
    ├── utils/         # Utility functions
    └── widgets/       # Reusable widgets
```

### State Management

**Primary:** Riverpod 2.6+  
- Use `ConsumerWidget` or `ConsumerStatefulWidget` for widgets
- Define providers in `lib/app/composition/app_providers.dart`
- Avoid `StatefulWidget` for state that should be managed globally

**Patterns:**
- `Provider` for read-only dependencies
- `StateNotifierProvider` / `NotifierProvider` for mutable state
- `FutureProvider` / `StreamProvider` for async data

### Navigation

**GoRouter 14.8+**  
- Routes defined in `lib/app/navigation/`
- Type-safe navigation using GoRouter patterns
- Deep linking support

### Database

**Drift 2.25+**  
- Local SQLite database
- Type-safe queries
- Migration support
- Tables defined in `lib/core/storage/`

### Network

**Dio 5.8+**  
- HTTP client with interceptors
- Configured in `lib/core/network/`
- Base URLs configured via build args (see Build Configuration below)

## Key Features

### Book Reading
- **Formats:** EPUB, PDF, TXT, MOBI, Markdown
- **Reader UI:** Multiple themes, fonts, page-turning animations
- **Paper curl effect:** `lib/features/reader/presentation/reader_paper_curl_paged_view.dart`

### Book Source Management
- **Private sources:** User-managed book sources
- **Server gateway:** Remote book source integration
- **Cover gallery:** `lib/features/mine/presentation/cover_gallery_page.dart`
- **Launch images:** `lib/features/mine/presentation/launch_image_gallery_page.dart`

### Multi-platform Support
- Android APK/AAB
- iOS IPA
- macOS DMG
- Linux AppImage
- Windows MSIX
- Web (optional, requires separate deployment)

## Development Standards

### Code Style
- Follow official Dart/Flutter style guide
- Run `flutter analyze` before committing
- Use `const` constructors wherever possible
- Implement proper keys for list items

### Architecture Guardrails
Enforce via automated tools (see `tool/` directory):
- `dart run tool/check_architecture_guardrails.dart` - Architecture validation
- `dart run tool/check_route_string_guard.dart` - Route validation
- `dart run tool/check_model_codegen_guard.dart` - Code generation validation
- `dart run tool/run_architecture_green_suite.dart` - Full test suite

### Documentation Standards
Refer to `docs/standards/` for detailed guidelines:
- `development_architecture_guardrails.md` - Architecture rules
- `project_core_principles.md` - Core development principles

### Testing
```bash
flutter test                    # Run all tests
flutter test test/features/     # Run feature tests
```

Test structure mirrors `lib/` organization:
```
test/
├── app/
├── core/
├── data/
├── domain/
├── features/
├── runtime/
├── fixtures/      # Test data
└── test_utils/    # Testing utilities
```

## Build & Release

### Local Development
```bash
flutter pub get
flutter run
```

### Multi-Platform Build

**Unified build script:** `scripts/build_unified_artifacts.sh`

```bash
# Auto-detect platforms + release mode
./scripts/build_unified_artifacts.sh

# Native platforms (Android, iOS, macOS, Linux, Windows)
./scripts/build_unified_artifacts.sh native release

# Mobile only
./scripts/build_unified_artifacts.sh mobile release

# Specific platforms
./scripts/build_unified_artifacts.sh android,ios,macos release

# Custom Android build
ANDROID_TARGET=both ANDROID_APK_PROFILE=universal ./scripts/build_unified_artifacts.sh android release
```

**Output:** `build/unified_artifacts/<timestamp>-<mode>/` with `manifest.txt`

### Platform-Specific Scripts
- `scripts/build_android_artifacts.sh` - Android APK/AAB
- `scripts/build_ios_ipa_nocodesign.sh` - iOS IPA (no code sign)
- `scripts/build_macos_artifact.sh` - macOS DMG
- `scripts/build_linux_artifact.sh` - Linux AppImage
- `scripts/build_windows_artifact.sh` - Windows MSIX

### Build Configuration

**Environment Variables:**
- `BUILD_NAME` - User-visible version (e.g., `1.3.0`)
- `BUILD_NUMBER` - Monotonic build number (e.g., `26061101`)
- `APPREAD_API_BASE_URL` - Backend API base URL
- `APPREAD_READER_GATEWAY_BASE_URL` - Book source gateway URL
- `APPREAD_APP_NAME` - App identifier (default: `selune`)
- `ARTIFACT_NAME` - Build artifact name (default: `书享阅读`)

**Example:**
```bash
BUILD_NAME=1.3.0 BUILD_NUMBER=26061101 \
APPREAD_API_BASE_URL=https://api.example.com \
./scripts/build_unified_artifacts.sh native release
```

### GitHub Actions CI/CD

**Workflow:** `.github/workflows/multiplatform-build.yml`

**Manual trigger:** Actions → Multiplatform Build → Run workflow

**Required input:**
- `full_version` - Format: `1.2.0+26061001` (display version + build number)

**Default configuration:**
- `platforms: native` (Android, iOS, macOS, Linux, Windows)
- `build_mode: release`
- `flutter_version: 3.44.1`
- `android_target: apk`
- `android_apk_profile: arm64`

**Required Secrets:**
- `ANDROID_KEY_PROPERTIES` - Android signing config
- `ANDROID_KEYSTORE_BASE64` - Android keystore (base64)
- `RELEASE_REPO_TOKEN` - GitHub token for publishing to `zyl140640/readbook-releases`

**Output:** Builds published to `zyl140640/readbook-releases` repository

### Hot Updates

**Shorebird Integration:** Configured via `shorebird.yaml`
- Hot update support for critical bug fixes
- No app store review required for code-push updates

## Icon & Branding

### Icon Generation

**Active script:** `scripts/generate_brand_icon_v3_ios_white.py`

**Assets:** `assets/branding/`
- `app_icon.png` - Main app icon
- `app_icon_foreground.png` - Adaptive icon foreground
- `selune_app_icon.png` - Full brand icon
- `selune_app_icon_dark.png` - Dark theme variant
- `selune_app_icon_light.png` - Light theme variant
- `selune_launch_scene.png` - Launch screen

**Icon Configuration:** `pubspec.yaml` (flutter_launcher_icons section)
- Separate configs exist for dark/light themes but main config in pubspec.yaml is actively used

### Logo Assets
`artifacts/` directory contains SVG and PNG logo variants for different themes.

## Common Tasks

### Adding a New Feature
1. Create feature module under `lib/features/<feature_name>/`
2. Follow clean architecture layers: `data/`, `domain/`, `presentation/`
3. Register routes in `lib/app/navigation/`
4. Add providers to `lib/app/composition/app_providers.dart`
5. Write tests in `test/features/<feature_name>/`
6. Document in `docs/features/`

### Adding a New Dependency
1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. If code generation needed: `dart run build_runner build --delete-conflicting-outputs`

### Database Schema Changes
1. Update Drift table definitions in `lib/core/storage/`
2. Generate migration: `dart run drift_dev schema generate lib/core/storage/drift/app_database.dart schemas/`
3. Increment schema version in database class
4. Write migration logic in `onUpgrade`

### Code Generation
```bash
# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Generate routes (if using code generation for routing)
dart run tool/generate_routing.dart
```

## Documentation

### Main Entry Point
`docs/README.md` - Comprehensive documentation index

### Key Documents
- `docs/development_architecture_guardrails.md` - Architecture rules
- `docs/project_core_principles.md` - Development principles
- `docs/governance/` - Storage, API, architecture governance
- `docs/features/` - Feature-specific documentation
- `docs/ui_ux/` - Design system and UI implementation
- `docs/operations/` - Deployment and release guides
- `docs/archive/` - Historical milestones and completed work

### Architecture Governance
- Storage decisions: `docs/governance/`
- API patterns: `docs/governance/`
- State management: Reference Riverpod patterns in codebase

## Error Monitoring

**Sentry Integration:** Opt-in via build args

```bash
flutter run \
  --dart-define=APP_ERROR_MONITORING_ENABLED=true \
  --dart-define=APP_ERROR_MONITORING_DSN=<sentry-dsn> \
  --dart-define=APP_ERROR_MONITORING_ENVIRONMENT=production
```

**Privacy:** Sensitive data (tokens, passwords, paths, URLs) automatically filtered via `AppErrorMonitoringService`

## Third-Party Dependencies

### UI Components
- `flutter_animate: ^4.5.0` - Animations
- `shimmer: ^3.0.0` - Loading skeletons
- `flutter_slidable: ^3.0.1` - Swipeable list items
- `badges: ^3.1.2` - Badge widgets
- `flutter_staggered_grid_view: ^0.7.0` - Staggered grids
- `flutter_sticky_header: ^0.6.5` - Sticky headers

### Data & Parsing
- `html: ^0.15.5` - HTML parsing
- `xml: ^6.5.0` - XML parsing
- `markdown: ^7.3.1` - Markdown rendering
- `pdf_text_extract: ^0.0.1` - PDF text extraction
- `dart_mobi: ^1.0.2` - MOBI format support

### Custom Plugins (Local)
- `pdfium_dart` - PDF rendering (third_party/plugins/)
- `flutter_charset_detector_android` - Character encoding detection
- `flutter_charset_detector_web` - Web charset detection stub

## Project Status

**Active Development Areas:**
- Reader improvements (paper curl animation, themes)
- Book source management (private sources, gallery UI)
- User profile and settings (mine feature)
- Multi-platform optimization

**Recent Activity (from git status):**
- App provider refactoring
- Gallery services optimization
- Private book source service improvements
- Reader UI enhancements

## Best Practices

### DO
- Use `const` constructors everywhere possible
- Implement proper widget keys for lists
- Use Riverpod for state management (not `StatefulWidget` for global state)
- Follow clean architecture (data → domain → presentation)
- Write tests for new features
- Run architecture validation tools before committing
- Profile with Flutter DevTools to fix performance issues
- Use proper error handling with try-catch
- Document complex business logic

### DON'T
- Build widgets inside `build()` method
- Mutate state directly (always create new instances)
- Skip `const` on static widgets
- Block UI thread (use `compute()` for heavy work)
- Ignore platform-specific behavior
- Skip tests for critical features
- Commit without running `flutter analyze`
- Use `setState` for app-wide state

## Contact & Resources

- **GitHub Repository:** Private repository
- **Public Releases:** `zyl140640/readbook-releases`
- **Documentation:** See `docs/` directory
- **Architecture Questions:** Refer to `docs/standards/` and `docs/governance/`

---

**Last Updated:** 2026-06-11  
**Maintained by:** Project team

For more detailed information, always check the `docs/` directory and run architecture validation tools before making significant changes.
