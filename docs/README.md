# 项目文档入口

更新时间：2026-04-02
用途：当前项目文档总入口。

当前文档按“主项目文档 + 脚本源运行时文档”两组维护。

## 核心文档

- `docs/product_guide.md`
  项目定位、产品需求、范围和成功标准。
- `docs/engineering_guide.md`
  技术架构、模块边界、开发规范和测试要求。

## 专题文档

- `docs/product_experience_guide.md`
  UI、自适应、阅读体验、字体和主题，包含当前断点和布局规则。
- `docs/reader_refactor_task_plan.md`
  阅读器结构改造计划，包含统一文本内核、分页/滚动委托、设置分层和验收清单。
- `docs/reader_multimodal_plan.md`
  阅读器多内容形态统一规划，覆盖文本、漫画与未来听书模式的壳层、状态、界面与动画分层。
- `docs/product_features_guide.md`
  阅读记录、书签、缓存、自定义规则和本地阅读。
- `docs/engineering_delivery_guide.md`
  书源列表性能、Android 发布和移动端后端集成。
- `docs/script_sources/README.md`
  脚本源运行时文档入口，包含作者手册、规范、运行时 API、架构和模板。
- `docs/script_sources/search-runtime-redesign.md`
  搜索、换源和自动换源的脚本源运行时重构方案。
- `docs/script_sources/source-health-system-plan.md`
  源健康系统规划，覆盖搜索、换源、书源列表、源检测和停用策略。

## 使用建议

进入项目先读：

1. `docs/product_guide.md`
2. `docs/engineering_guide.md`

做具体需求时，再补对应专题文档。

## 脚本源文档

脚本源和新规则运行时的相关文档已整体迁入：

- `docs/script_sources/README.md`

建议阅读顺序：

1. `docs/script_sources/official-source-author-guide.md`
2. `docs/script_sources/source-spec-v1.md`
3. `docs/script_sources/runtime-ctx-api.md`
4. `docs/script_sources/architecture.md`
