# Flutter AppRead

一个基于 Flutter 的阅读 APP 项目，目标是兼容开源阅读生态常见书源规则（以 Legado 规则体系为主），并逐步打造稳定、可维护、可扩展的阅读体验。

## 项目当前重点

- 构建书源兼容层（导入、校验、适配）。
- 打通基础阅读闭环（搜索 -> 详情 -> 目录 -> 正文）。
- 建立长期可维护的架构和工程规范。

## 文档入口

- 统一入口：`docs/README.md`
- AI 快速上下文：`docs/ai_core_context.md`
- 文档治理规则：`docs/documentation_governance.md`
- 文档整合映射：`docs/documentation_map_2026-03-07.md`
- 核心基线：`docs/project_overview.md` / `docs/requirements.md` / `docs/architecture.md` / `docs/project_conventions.md`

## 快速开始

```bash
flutter pub get
flutter run
```

## 统一打包（多平台产物集中到一个目录）

新增脚本：`scripts/build_unified_artifacts.sh`，会按平台调用现有打包脚本，并把产物汇总到同一个会话目录，避免手动到处找文件。

默认（`auto`）会根据当前主机自动选择可构建平台：
- macOS: `android ios macos`
- Linux: `android linux`
- Windows: `android windows`

```bash
# 默认：auto + release
./scripts/build_unified_artifacts.sh

# 指定平台 + 模式
./scripts/build_unified_artifacts.sh android,ios,macos release

# 只打 Android APK（按 ABI 拆分）
ANDROID_TARGET=apk SPLIT_PER_ABI=1 ./scripts/build_unified_artifacts.sh android release
```

产物默认目录：`build/unified_artifacts/<timestamp>-<mode>/`
同目录下会生成 `manifest.txt`，方便查看每个平台对应的文件名。

## 开发检查

```bash
flutter analyze
flutter test
```
