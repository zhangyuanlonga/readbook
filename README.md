# Flutter AppRead

一个基于 Flutter 的阅读 APP 项目，目标是兼容开源阅读生态常见书源规则（以 Legado 规则体系为主），并逐步打造稳定、可维护、可扩展的阅读体验。

## 项目当前重点

- 构建书源兼容层（导入、校验、适配）。
- 打通基础阅读闭环（搜索 -> 详情 -> 目录 -> 正文）。
- 建立长期可维护的架构和工程规范。

## 文档入口

- 项目总览：`docs/project_overview.md`
- 需求文档：`docs/requirements.md`
- 架构设计：`docs/architecture.md`
- 项目规范：`docs/project_conventions.md`
- 实施步骤：`docs/implementation_steps.md`
- 文档索引：`docs/README.md`

## 快速开始

```bash
flutter pub get
flutter run
```

## 开发检查

```bash
flutter analyze
flutter test
```
