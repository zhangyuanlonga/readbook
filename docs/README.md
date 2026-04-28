# 项目文档入口

更新时间：2026-04-28
用途：当前项目文档总入口。

当前文档按“主线文档 + 历史归档”两组维护。

## 核心文档

- `docs/product_guide.md`
  项目定位、产品需求、范围和成功标准。
- `docs/engineering_guide.md`
  技术架构、模块边界、开发规范和测试要求。
- `docs/development_architecture_guardrails.md`
  当前项目后续开发的强约束文档，明确目录、依赖、Riverpod、路由、原生边界和 code review 一票否决项。

## 专题文档

- `docs/brand_guidelines.md`
  `Selune` 品牌视觉、主题配色、官网与营销素材的统一设计规范。
- `docs/product_experience_guide.md`
  UI、自适应、阅读体验、字体和主题，包含当前断点和布局规则。
- `docs/adaptive_layout_playbook.md`
  自适应落地策略，统一官方推荐、国内常用做法和本项目后续改造口径。
- `docs/reader_multimodal_plan.md`
  阅读器多内容形态统一规划，覆盖文本、漫画与未来听书模式的壳层、状态、界面与动画分层。
- `docs/bookshelf_reader_open_latency_execution_plan.md`
  书架点击书籍加载卡顿治理执行方案，覆盖点击前阻塞链路、阅读页恢复、章节查询瘦身和专项回填口径。
- `docs/local_multi_format_reading_plan.md`
  本地多格式阅读开发方案，覆盖 `txt`、`epub`、`md`、`html`、`pdf`、`mobi`、`azw`、`azw3` 的架构原则、阶段计划与风险边界。
- `docs/cross_platform_boundary_refactor_plan.md`
  跨端与原生边界收口方案，说明哪些能力保留原生、哪些能力统一回 Flutter。
- `docs/product_features_guide.md`
  阅读记录、书签、缓存、自定义规则和本地阅读。
- `docs/engineering_delivery_guide.md`
  书源列表性能、Android 发布和移动端后端集成。
- `docs/script_sources/official-source-author-guide.md`
  唯一保留的书源编写文档，包含作者手册、规范、标准对象、`ctx` API、加解密能力和网页调试服务说明。

## 历史归档

- `docs/archive/README.md`
  统一归档入口，存放历史计划、审计、清单和阶段性执行文档。

## 使用建议

进入项目先读：

1. `docs/product_guide.md`
2. `docs/engineering_guide.md`
3. `docs/development_architecture_guardrails.md`

做具体需求时，再补对应专题文档。

## 脚本源文档

脚本源和新规则运行时的相关文档已合并为单一入口：

- `docs/script_sources/official-source-author-guide.md`

后续书源规范、运行时 API、标准对象和调试服务说明都直接维护在这一个文件中。
