# 高级主题与组件库改造基线

日期: 2026-06-20
分支: `codex/color-system-phase0-3`
用途: 作为阶段 0-3 改造的审计基线，后续用来区分历史债务、允许豁免和新增问题。

## 1. 审计命令

```bash
dart run tool/check_theme_coverage_audit.dart
dart run tool/check_ui_component_governance.dart
dart run tool/run_phase6_guardrail_audit.dart
```

本次 `check_ui_component_governance` 在本机执行时被 `.dart_tool/lib/libpdfium.dylib` codesign 严格校验阻断，未产出新结果；暂沿用上一轮 review 中记录的治理计数作为参考基线。

## 2. Theme Coverage 基线

| 指标 | 数量 |
|---|---:|
| 扫描文件 | 175 |
| 高风险文件 | 8 |
| `border-radius` | 586 |
| `local-alpha` | 585 |
| `box-decoration` | 405 |
| `hardcoded-color` | 145 |
| `material-color` | 111 |
| `shape-property` | 84 |
| `rounded-shape` | 38 |
| `box-shadow` | 32 |

阶段 0-3 执行后复测:

| 指标 | 执行后数量 |
|---|---:|
| 扫描文件 | 177 |
| 高风险文件 | 7 |
| `local-alpha` | 583 |
| `border-radius` | 581 |
| `box-decoration` | 405 |
| `material-color` | 101 |
| `hardcoded-color` | 99 |
| `shape-property` | 77 |
| `rounded-shape` | 34 |
| `box-shadow` | 33 |

变化: `component_demo_page.dart` 已从高风险列表移出；`hardcoded-color` 从 145 降到 99，主要来自 Lumina 样板改为复用官方 preset。

高风险文件:

| 文件 | score | 初步处理策略 |
|---|---:|---|
| `lib/features/mine/presentation/component_demo_page.dart` | 263 | 内部 QA 页；Lumina 基线改为复用官方 preset |
| `lib/app/widgets/text_cover_placeholder.dart` | 190 | 封面生成色板，进入豁免候选 |
| `lib/features/mine/presentation/mine_page_view.dart` | 109 | 后续迁移到 `AppSurface/AppSection` |
| `lib/features/bookshelf/presentation/bookshelf_page.dart` | 78 | 只迁移外围状态和表面，不动核心数据流 |
| `lib/features/reader/presentation/reader_page.dart` | 76 | 保留阅读器专用视觉，优先迁移 chrome/状态 |
| `lib/features/bookshelf/presentation/widgets/bookshelf_taxonomy_picker_surface.dart` | 67 | 迁移到统一 picker/sheet surface |
| `lib/features/reader/presentation/widgets/chrome/reader_overlay_bars.dart` | 67 | 后续引入 reader chrome tokens 或 overlay tokens |
| `lib/features/mine/presentation/advanced_theme_list_page.dart` | 65 | 先迁移导入/导出/状态反馈 |

## 3. UI Governance 参考基线

| 类型 | 数量 |
|---|---:|
| 总 findings | 1144 |
| `hardcoded-style` | 923 |
| `loading-state` | 57 |
| `platform-branch` | 51 |
| `list-children` | 46 |
| `scaffold` | 40 |
| `list-performance` | 8 |
| `missing-doc` | 8 |
| `capability-wrapper` | 5 |
| `layout-builder` | 5 |
| `modal-surface` | 1 |

## 4. Phase 6 Guardrail 基线

| 项目 | 结果 |
|---|---|
| core -> features import | 0 |
| 文件体积 warning | `shell_scaffold.dart`、`book_detail_page.dart`、`bookshelf_page_flow.dart`、`advanced_theme_service.dart`、`advanced_theme_editor_page.dart`、`advanced_theme_list_page.dart`、`reading_records_page.dart` |
| 文件体积 explained | `app_database.dart`、`bookshelf_page.dart`、`reader_page.dart` |
| `catch (_)` | 275 |
| empty catch | 67 |
| return false only | 16 |

## 5. 分类规则

必须迁移:

- 页面卡片、资源 tile、设置分组里的本地 `BoxDecoration`、圆角、边框、阴影。
- 页面级裸 `CircularProgressIndicator`。
- 会员锁定、离线、错误、筛选空态的局部拼装。
- 新增页面里的本地 `Container + BoxDecoration` 组合。

允许豁免:

- `TextCoverPlaceholder` 的生成封面色板。
- 全屏图片预览遮罩。
- Reader 翻页渲染所需透明色。
- 官方主题 preset 内的固定色值。

需要产品确认:

- 阅读器 chrome 是否完全跟随高级主题。
- 应用背景是否允许未来增加独立全局覆盖。
- 主题资源删除后是否主动提示用户修复引用。

## 6. 验收口径

- 后续新增组件优先进入 `lib/app/widgets/foundation/` 或已有 app widgets 层。
- 阶段性迁移不追求历史 finding 清零，先保证新增代码不扩大同类债务。
- 启动图和底栏图集只通过高级主题绑定生效，旧 active/default 配置只作为兼容数据读取，不再作为生效来源。
