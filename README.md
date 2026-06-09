# Flutter AppRead

一个基于 Flutter 的阅读 APP 项目，当前聚焦本地图书阅读与服务器书源网关能力，并逐步打造稳定、可维护、可扩展的阅读体验。

## 项目当前重点

- 打通本地图书阅读闭环（导入 -> 解析 -> 详情 -> 阅读）。
- 接入服务器书源网关闭环（搜索 -> 详情 -> 目录 -> 正文）。
- 建立长期可维护的架构和工程规范。

## 文档入口

- 统一入口：`docs/README.md`
- 开发架构约束：`docs/development_architecture_guardrails.md`
- 产品与工程总览：`docs/product_guide.md` / `docs/engineering_guide.md`
- 历史方案归档：`docs/archive/README.md`

## 快速开始

```bash
flutter pub get
flutter run
```

## 统一打包（多平台产物集中到一个目录）

新增脚本：`scripts/build_unified_artifacts.sh`，会按平台调用现有打包脚本，并把产物汇总到同一个会话目录，避免手动到处找文件。

交互式终端下，脚本会在打包前提示确认本次版本号，并通过 `--build-name / --build-number` 覆盖 Flutter 默认版本，无需每次手改 `pubspec.yaml`。

默认（`auto`）会根据当前主机自动选择可构建平台：
- macOS: `android ios macos web`
- Linux: `android linux web`
- Windows: `android windows web`

```bash
# 默认：auto + release
# Android 默认产出适合直接发给用户安装的 arm64 APK
./scripts/build_unified_artifacts.sh

# 原生移动端 + 桌面端：Android / iOS / macOS / Linux / Windows
./scripts/build_unified_artifacts.sh native release

# 只打移动端或桌面端
./scripts/build_unified_artifacts.sh mobile release
./scripts/build_unified_artifacts.sh desktop release

# 指定平台 + 模式
./scripts/build_unified_artifacts.sh android,ios,macos release

# 只打 Android APK（按 ABI 拆分，得到多个更小的 APK）
ANDROID_APK_PROFILE=split ./scripts/build_unified_artifacts.sh android release

# 同时产出通用 APK + AAB（APK 体积会更大，但兼容机型最全）
ANDROID_TARGET=both ANDROID_APK_PROFILE=universal ./scripts/build_unified_artifacts.sh android release

# 非交互模式手动指定版本
APPREAD_API_BASE_URL=https://www.sxyd.lltask.top/api \
APPREAD_READER_GATEWAY_BASE_URL=https://rust.lltask.top/api/ \
APPREAD_APP_NAME=selune ARTIFACT_NAME=Selune \
BUILD_NAME=1.1.0 BUILD_NUMBER=26041801 \
./scripts/build_unified_artifacts.sh android,ios release
```

产物默认目录：`build/unified_artifacts/<timestamp>-<mode>/`
同目录下会生成 `manifest.txt`，方便查看每个平台对应的文件名。

GitHub Actions 也提供了手动打包入口：`Actions -> Multiplatform Build -> Run workflow`。
默认 `platforms=native` 会并行打 Android / Linux、iOS / macOS、Windows，并上传为 Actions artifacts；如需 Web 产物可改成 `platforms=all`，或手动填写 `android,ios,macos,linux,windows,web`。
Actions 打包不会弹出版本号确认。发布时优先填写 `full_version`，例如 `1.1.0+26041801`；如果不填，则使用 `build_name` / `build_number`，再不填就读取 `pubspec.yaml` 里的版本。
默认会自动生成 `build_number=YYMMDDNN`，例如 `26060901`。通常只需要填 `build_name=1.2.0`；如果同一天要打第二包，把 `build_sequence` 填成 `2` 即可得到 `26060902`。手动填写 `full_version` 或 `build_number` 时会覆盖自动构建号。
如果要在 GitHub 上打 Android release 包，需要先配置仓库 Secrets：

- `ANDROID_KEY_PROPERTIES`：内容格式参考 `android/key.properties.example`
- `ANDROID_KEYSTORE_BASE64`：`android/app/appread-release.jks` 的 base64 内容

版本规则建议：
- `BUILD_NAME` / `version_name`：给用户看的展示版本，例如 `1.1.0`
- `BUILD_NUMBER` / `version_code`：给系统比较版本大小的整数构建号，Actions 默认按 `YYMMDDNN` 生成，例如 `26060901`
- `APPREAD_API_BASE_URL`：打包时注入的后端地址，例如 `https://www.sxyd.lltask.top/api`
- `APPREAD_READER_GATEWAY_BASE_URL`：在线书源 / 服务器书源网关地址，默认 `https://rust.lltask.top/api/`
- `PDFIUM_DOWNLOAD_BASE_URL`：PDF 阅读原生库下载基地址，默认 `https://ghfast.top/https://github.com/bblanchon/pdfium-binaries/releases/download`
- `APPREAD_APP_NAME`：可选，默认 `selune`

错误监控默认只启用本地诊断日志，不会上报远端。需要接入 Sentry 时，构建或运行命令显式传入：

```bash
--dart-define=APP_ERROR_MONITORING_ENABLED=true \
--dart-define=APP_ERROR_MONITORING_DSN=<sentry-dsn> \
--dart-define=APP_ERROR_MONITORING_ENVIRONMENT=production
```

远端监控仅发送经过 `AppErrorMonitoringService` 脱敏的错误事件；token、cookie、密码、本机路径、URL query / fragment、设备指纹等敏感信息会被过滤。本地诊断导出继续可用，也复用同一套脱敏规则。

更完整的工程交付与移动端发布说明见：`docs/engineering_delivery_guide.md`

## 开发检查

```bash
flutter analyze
flutter test
dart run tool/check_model_codegen_guard.dart
dart run tool/check_route_string_guard.dart
dart run tool/run_architecture_green_suite.dart
```
