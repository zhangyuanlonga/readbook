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
默认 `platforms=all` 会并行打 Android / Linux / Web、iOS / macOS、Windows，并上传为 Actions artifacts。
如果要在 GitHub 上打 Android release 包，需要先配置仓库 Secrets：

- `ANDROID_KEY_PROPERTIES`：内容格式参考 `android/key.properties.example`
- `ANDROID_KEYSTORE_BASE64`：`android/app/appread-release.jks` 的 base64 内容

版本规则建议：
- `BUILD_NAME` / `version_name`：给用户看的展示版本，例如 `1.1.0`
- `BUILD_NUMBER` / `version_code`：给系统比较版本大小的整数构建号，例如 `26041801`
- `APPREAD_API_BASE_URL`：打包时注入的后端地址，例如 `https://www.sxyd.lltask.top/api`
- `APPREAD_READER_GATEWAY_BASE_URL`：在线书源 / 服务器书源网关地址，默认 `https://rust.lltask.top/api/`
- `APPREAD_APP_NAME`：可选，默认 `selune`

更完整的工程交付与移动端发布说明见：`docs/engineering_delivery_guide.md`

## 开发检查

```bash
flutter analyze
flutter test
```
