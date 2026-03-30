# 脚本源文档索引

更新时间：2026-03-30

这组文档已从 `flutter_testjs` 迁入当前仓库，用于说明脚本源 / 新规则运行时在 `flutterreadbook` 中的规范、能力边界和迁移方案。

说明：

- 文档主体内容保留了原始设计思路
- 部分“当前项目 / 对方项目”的表述仍然是迁移视角
- 在当前仓库语境下，可以将“当前项目”理解为脚本源运行时内核，将“对方项目”理解为 `flutterreadbook` 的产品层和既有业务壳

这套文档当前建议按这条路径阅读：先分清新旧 JS 规则，再会写书源，再了解规范，最后确认实现边界。

## 主线文档

1. [JS 规则速查](./js-rules-quick-reference.md)
   先把旧 `js:` / `<js>` 和新脚本源 JS 的关系、边界、模板入口看明白。
2. [官方书源编写手册](./official-source-author-guide.md)
   书源作者的主入口。包含模板、流程、标准对象、方法职责和完整 `ctx.*` API。
3. [书源规范 v1](./source-spec-v1.md)
   规范性文档。只定义书源文件结构、标准对象和兼容约定。
4. [宿主运行时 API](./runtime-ctx-api.md)
   边界说明文档。只说明当前运行时到底开放了什么，以及哪些能力不要误解。

## 辅助文档

- [第二阶段：Browser / Cookie / Cache 设计说明](./stage-two-browser-sources.md)
  只在你需要理解浏览器能力的设计取舍时阅读，不是入门必读。
- [规则内核嵌入方案](./runtime-core-embedding-plan.md)
  迁移主文档之一。用于说明脚本源运行时如何嵌入当前仓库。
- [规则内核代码模块拆分清单](./runtime-core-module-split-plan.md)
  迁移主文档之一。用于说明当前代码中哪些模块适合直接抽成可嵌入内核。
- [统一书源调度方案](./unified-source-dispatch-plan.md)
  用于说明旧规则源与脚本源并存时，为什么需要统一调度抽象，以及推荐如何落地。
- [去 Legado 迁移审计与实施清单](./legado-removal-migration-audit.md)
  用于梳理去 Legado 的缺口、影响面、分阶段迁移顺序和验收项。
- [总体架构](./architecture.md)
  只在需要了解整体系统背景时阅读。
- [开发计划](./development-plan.md)
  面向实现规划，不是作者使用手册。

## 归档文档

- [登录态计划](./login-plan.md)
  这是历史方向记录，不代表当前主线设计，不建议作为现行规范参考。

## 模板

- [标准完整模板](../templates/source_template_v1.js)
  当前沿用 `flutter_testjs` 主线模板整理出的官方示例。
- [最小骨架模板](../templates/source_template_minimal_v1.js)
  当前仓库补充的本地简化示例，不是主线官方模板。
- [HTML 站点模板](../templates/source_template_html_v1.js)
  当前仓库补充的本地 HTML 示例，不是主线官方模板。
- [JSON API 模板](../templates/source_template_api_v1.js)
  当前仓库补充的本地 API 示例，不是主线官方模板。

一句话分工：

- 速查文档负责“先分清新旧规则和模板入口”
- 主手册负责“怎么写”
- 规范文档负责“什么算合规”
- 运行时文档负责“当前实现到哪里”

## 交接说明

如果后续继续推进脚本源 / 新规则运行时在当前仓库中的接入，建议优先持续维护这两份文档：

1. [规则内核嵌入方案](./runtime-core-embedding-plan.md)
2. [规则内核代码模块拆分清单](./runtime-core-module-split-plan.md)

建议：

- 第一份负责方向、边界、角色和原则
- 第二份负责代码模块、迁移范围和接入顺序
- 交接相关新增内容优先只补到这两份文档，避免再次分散
