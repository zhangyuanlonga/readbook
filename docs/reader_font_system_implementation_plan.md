# 阅读字体系统实现计划（对齐开源阅读）

> 编制日期：2026-03-04  
> 适用范围：`flutter_appread` 正文阅读页（含在线阅读与本地阅读）

## 1. 背景

当前项目已经具备基础排版能力（字号、行高、段距、段首缩进、字重）与持久化能力，但与开源阅读（Legado）相比，字体系统仍有几个关键差距：

- 缺少“字体文件选择 + 自定义字体加载”闭环。
- 缺少字间距（`letterSpacing`）调节入口。
- 字重实现较简化（仅枚举档位），未形成“字体/字重/排版”统一策略。
- 在线阅读与本地阅读的样式应用路径未完全抽象为同一套字体能力层。

本计划目标是在不破坏现有阅读稳定性的前提下，分阶段实现“可导入字体、可持久化、可实时预览、可降级回退”的字体系统。

## 2. 现状基线（flutter_appread）

### 2.1 已有能力

- 配置模型已包含：`fontSize`、`lineHeight`、`paragraphSpacing`、`paragraphIndent`、`fontWeightLevel`。  
  参考：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/domain/entities/reader_settings.dart:24`
- 偏好持久化已覆盖上述字段。  
  参考：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/application/reader_preferences_service.dart:17`
- 在线阅读样式通过 `_paragraphTextStyle` 统一下发。  
  参考：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:2002`
- 本地阅读也使用 `TextStyle(fontSize/height/fontWeight)`。  
  参考：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/local_reader_page.dart:138`

### 2.2 当前缺口

- `ReaderSettings` 无字体族/字体来源字段（系统字体、内置字体、自定义字体）。
- `ReaderSettings` 无 `letterSpacing` 字段。
- 阅读设置面板目前仅有字号 + 字重按钮，缺少字体选择与字间距滑杆。  
  参考：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:5646`

## 3. 对齐目标（参考开源阅读）

结合 Legado 的实现，建议优先对齐以下四点：

1. **字体来源可配置**：支持系统默认 + 用户导入（ttf/otf）。
2. **排版参数成组生效**：字号、字重、字间距、行高、段距修改后即时作用于正文。
3. **持久化与恢复**：重启后保留选择，字体失效时自动降级。
4. **刷新机制清晰**：设置变更后触发“样式刷新 + 排版重算”（而不是只改 UI 不重排）。

## 4. 技术方案（Flutter 侧）

### 4.1 配置模型扩展

在 `ReaderSettings` 新增字段（建议）：

- `double letterSpacing`（默认 `0.0`）
- `ReaderFontSource fontSource`（`system` / `builtin` / `custom`）
- `String? fontFamilyKey`（如 `system_sans`、`system_serif`、`custom_xxx`）
- `String? customFontPath`（仅本地可读路径；Web 可忽略）

并同步更新：

- `copyWith`
- `toJson` / `fromJson`
- `ReaderPreferencesService.loadSettings` / `saveSettings`

### 4.2 字体注册与加载

新增 `ReaderFontRegistryService`（建议路径：`lib/features/reader/application/reader_font_registry_service.dart`），职责：

- 导入字体文件（通过 `file_selector`）。
- 复制到应用私有目录（建议：`<app-doc>/reader_fonts/`）。
- 生成稳定 `fontFamilyKey` 并写入元数据（JSON）。
- 使用 `FontLoader` 动态注册字体（启动恢复时重新注册）。
- 对失效路径做降级回退（自动切回系统字体）。

### 4.3 渲染接入点

统一从一个入口生成正文样式（建议新增 `ReaderTypographyResolver`）：

- 输入：`ReaderSettings`
- 输出：`TextStyle`（含 `fontFamily`、`fontSize`、`fontWeight`、`height`、`letterSpacing`）

接入位置：

- `reader_page.dart` 的 `_paragraphTextStyle`
- `local_reader_page.dart` 的 `SelectableText.style`

### 4.4 设置 UI 方案

在现有“阅读设置”面板新增：

- 字体选择入口（底部弹层）：系统字体 / 已导入字体 / 导入按钮。
- 字间距滑杆（建议范围：`-0.05 ~ 0.25`）。
- 行高、段距可保留当前能力但统一放入“排版”分组，形成清晰结构。

交互要求：

- 实时预览（`setModalState`）
- 点击“应用”后统一 `saveSettings`
- 导入失败时 toast + 回退，不阻断阅读流程

## 5. 分阶段落地计划

### 5.0 UI 改版专项（按本次需求）

本专项用于落实以下 UI 调整目标：

- 将“自动读”能力并入**右侧阅读设置**面板，不再作为独立残留入口。
- 原“自动读”入口位置改为“**界面**”。
- 将字体与排版相关能力统一归到“界面”分组（避免入口分散）。

建议右侧阅读设置分组结构：

- 界面（字体、字号、字重、字间距、行高、段距、背景主题）
- 翻页（翻页模式、动画、步进）
- 自动读（开关、速度）
- 其他（亮度、辅助项）

### 5.0.1 执行勾选清单（实施时维护）

> 说明：执行阶段请将对应项从 `[ ]` 改为 `[x]`，并在 PR 描述同步勾选。

- [x] UI-01 将“自动读”入口从原位置迁移到右侧阅读设置内。
- [x] UI-02 原入口位置改为“界面”入口（文案与交互一致）。
- [x] UI-03 在“界面”分组聚合字体相关项（字体/字号/字重/字间距/行高/段距）。
- [x] UI-04 在“自动读”分组提供自动读开关与速度调节。
- [ ] UI-05 调整设置分组顺序与视觉层级，保证单手操作优先级。
- [x] UI-06 更新设置面板文案，确保“界面/自动读”职责边界清晰。
- [ ] UI-07 回归验证：在线阅读、分页阅读、滚动阅读三种模式交互正常。
- [ ] UI-08 回归验证：设置持久化与重启恢复正常。

### 5.0.2 验收标准（UI 专项）

- 用户可在右侧阅读设置中完整完成自动读开关与速度调节。
- 用户可在“界面”分组中集中完成字体与排版调节。
- 阅读页上不再出现“自动读”与“界面”职责混杂的重复入口。
- 配置变更后即时预览，点击应用后持久化，重启后恢复。

## Phase 0：方案与基线（0.5 天）

- 明确字段命名与默认值。
- 定义字体目录与元数据格式。
- 补充 ADR（可选）记录“为什么用 FontLoader + 私有目录”。

**验收**：评审通过，字段和目录方案冻结。

## Phase 1：模型与持久化（0.5~1 天）

- 修改 `ReaderSettings` 与 `ReaderPreferencesService`。
- 增加/更新单测：序列化、老数据兼容、默认值回退。

**验收**：`reader_preferences_service_test.dart` 通过，老配置可无损升级。

## Phase 2：字体注册服务（1~1.5 天）

- 新增 `ReaderFontRegistryService`。
- 实现导入、拷贝、注册、恢复、删除、异常回退。
- 建立字体元数据缓存（避免每次全量扫描）。

**验收**：可导入 ttf/otf，重启后仍可生效；文件丢失能自动降级。

## Phase 3：阅读设置 UI 接入（1 天）

- `reader_page.dart` 设置面板加入字体选择 + 字间距。
- 统一“草稿预览 -> 应用保存”流程。
- 与现有字号/字重交互并存，不破坏漫画模式设置减法逻辑。

**验收**：用户在阅读页 2 次点击内可完成字体切换并即时看到效果。

## Phase 4：渲染链路统一（0.5~1 天）

- 在线阅读/本地阅读统一使用 typography resolver。
- 分页相关算法保持不变，仅替换样式来源，确保行为稳定。

**验收**：在线与本地两种阅读页样式一致，章节切换无异常闪烁。

## Phase 5：质量与发布（0.5 天）

- 增加手工回归清单与核心自动化测试。
- 完成发布说明（新增能力、兼容说明、已知限制）。

**验收**：回归通过，准备合并主干。

## 6. 测试清单

### 6.1 自动化

- `ReaderSettings` JSON round-trip（含新字段）。
- `ReaderPreferencesService` 新字段持久化。
- 字体失效场景下 resolver 的降级行为。

### 6.2 手工回归

- 导入字体 -> 应用 -> 退出重进 -> 样式保持。
- 删除字体文件 -> 重进阅读页 -> 自动回退系统字体。
- 大章节翻页性能对比（导入字体前后）。
- 在线阅读与本地阅读样式一致性。

## 7. 风险与应对

- **风险 1：动态字体加载平台差异**  
  应对：先保证 Android/iOS，Web/桌面走系统字体降级。
- **风险 2：自定义字体导致布局抖动**  
  应对：字体切换后统一触发重排，避免局部刷新。
- **风险 3：字体文件不可读/被删除**  
  应对：启动时校验路径，异常即回退并清理无效配置。

## 8. 首批改动文件建议

- `lib/domain/entities/reader_settings.dart`
- `lib/features/reader/application/reader_preferences_service.dart`
- `lib/features/reader/application/reader_font_registry_service.dart`（新）
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/local_reader_page.dart`
- `test/features/reader/application/reader_preferences_service_test.dart`
- `test/features/reader/application/reader_font_registry_service_test.dart`（新）

## 9. 里程碑建议

- M1（本周）：完成 Phase 0~2（能力就绪，暂不开放 UI）
- M2（下周）：完成 Phase 3~4（UI 可用，在线/本地统一）
- M3（下周末）：完成 Phase 5 并上线

---

如果进入实施阶段，建议先从 **Phase 1（模型与持久化）** 开始，我可以直接按这份计划拆第一批 PR 任务清单（含具体改动点与测试项）。
