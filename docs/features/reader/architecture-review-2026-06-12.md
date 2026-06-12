# 阅读器架构评审报告

**评审日期**: 2026-06-12  
**评审范围**: `lib/features/reader/`  
**评审标准**: Flutter Clean Architecture + 项目规范（CLAUDE.md）

---

## 📊 总体评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **Clean Architecture 分层** | ⚠️ 4/10 | 缺少 domain/data 层 |
| **单一职责原则** | ❌ 2/10 | 存在超大 God Class |
| **代码组织** | ⚠️ 5/10 | 文件过多且职责不清 |
| **状态管理规范** | ⚠️ 4/10 | Riverpod 使用不足 |
| **可测试性** | ⚠️ 5/10 | 逻辑与 UI 耦合严重 |
| **可维护性** | ❌ 3/10 | 文件过大，修改风险高 |

**综合评分**: ⚠️ **3.8/10** (需要重构)

---

## 执行结论（裁剪版）

这份审计指出的问题大体成立，阅读器确实存在超大页面、`part` 文件耦合、设置页过重、presentation 目录过平等维护风险。但原方案写得过满，不建议按“完整 Clean Architecture 迁移 + 全面 Riverpod 改造 + 禁用 resolver/coordinator/facade”的方式一次性执行。

**建议做，但要做减法。** 当前阅读器刚修过纸页切换、章节跳转、设置弹层等敏感交互，最安全的策略是先冻结行为，再按功能边界做低风险拆分。目标不是立刻把评分刷到 8/10，而是让后续修 bug 不再每次都碰 6000 行主文件。

### 立即做

- 收敛 `reader_page.dart` 的 `part` 边界，只拆“纯 UI / 纯适配 / 纯计算”文件，避免改动阅读状态主流程。
- 拆 `reader_page_settings_sheet.dart`，因为设置页体量大且经常被改，收益最高。
- 建立阅读器关键路径 smoke test / golden-free widget test，先保护 Android/iOS 纸页、滚动、章节跳转、设置弹层行为。
- 整理 `presentation/widgets/`、`presentation/sheets/` 目录，把新代码放到清晰位置，旧代码逐步迁移。

### 暂缓做

- 暂缓把 `lib/domain/entities/reader_*` 全量搬进 `features/reader/domain/`，这会影响导入路径和跨功能引用，收益不如先拆主页面。
- 暂缓一刀切把 StatefulWidget 改成 Riverpod。动画、手势、滚动、页面控制器这类局部 UI 状态保留 StatefulWidget 更合理。
- 暂缓强行删除 resolver/coordinator/facade/presenter 命名。先要求新增代码命名清晰，旧代码在碰到对应功能时顺手合并。
- 暂缓大规模 repository/data 层迁移。阅读器的数据来源包含本地书、服务器书源、缓存、进度、主题，先画清边界再搬。

### 执行原则

- 每个阶段只改一个边界，不顺手重构无关链路。
- 每个阶段完成后必须能跑 Android 真机阅读 smoke，并补一次 iOS/桌面影响面检查。
- 禁止为了目录好看改变阅读行为；拆分后的首要验收是用户感知零变化。
- 新增文件可以先不追求 <500 行，但必须比原文件职责更单一。

---

## 🔍 主要问题

### 1. ❌ Clean Architecture 分层缺失

**问题描述**:
```
lib/features/reader/
├── application/     ✅ 存在 (112 个文件)
├── presentation/    ✅ 存在 (62 个文件)
├── domain/          ❌ 缺失
└── data/            ❌ 缺失
```

**影响**:
- Reader 相关的 domain entities 散落在 `lib/domain/entities/` 全局目录
- 缺少 repository 接口定义（应在 feature domain 层）
- 缺少 data layer 实现（datasource + repository impl）
- 违反了项目 Clean Architecture 标准

**应该是**:
```
lib/features/reader/
├── domain/
│   ├── entities/          # reader_document, reader_settings 等
│   ├── repositories/      # reader_repository.dart 接口
│   └── usecases/          # 业务用例（可选）
├── data/
│   ├── datasources/       # local/remote 数据源
│   ├── repositories/      # repository 实现
│   └── models/            # DTO 模型
├── application/           # 应用层服务
└── presentation/          # UI 层
```

### 2. ❌ God Class - reader_page.dart (6245 行)

**问题严重性**: 🔥 **CRITICAL**

**文件大小**: 214KB (6245 行)

**违反原则**:
- ✗ 单一职责原则 (SRP)
- ✗ 开闭原则 (OCP)
- ✗ 接口隔离原则 (ISP)

**part 文件滥用**:
```dart
// reader_page_widget.dart
part of 'reader_page.dart';  // ❌ 不是好的架构实践

// reader_page.dart 包含了:
// - UI 渲染逻辑
// - 状态管理
// - 业务逻辑
// - 数据加载
// - 手势处理
// - 主题切换
// - 书签管理
// - 等等...
```

**应该拆分为**:
```
presentation/
├── reader_page.dart              # 主页面容器 (<200 行)
├── reader_state.dart             # 页面状态定义
├── reader_controller.dart        # 页面控制器（Riverpod Notifier）
├── widgets/
│   ├── reader_content_view.dart  # 内容渲染
│   ├── reader_toolbar.dart       # 工具栏
│   ├── reader_gesture_layer.dart # 手势层
│   ├── reader_bookmark_panel.dart
│   └── reader_theme_selector.dart
└── components/                   # 更细粒度的组件
```

### 3. ⚠️ Application 层职责混乱

**问题**: 112 个文件，类型混杂，缺少清晰分类

**当前状态**:
```
application/
├── *_service.dart          # 31 个
├── *_controller.dart       # 18 个
├── *_resolver.dart         # 12 个
├── *_coordinator.dart      # 5 个
├── *_presenter.dart        # 4 个
├── *_facade.dart           # 3 个
├── *_model.dart            # 15 个
└── 其他混合职责            # 24 个
```

**问题分析**:
1. **命名不统一**: service/controller/resolver/coordinator/facade/presenter 语义重叠
2. **职责不清**: 同一功能分散在多个 service 中
3. **缺少分组**: 所有文件平铺在一个目录
4. **过度设计**: 过多的抽象层（facade, coordinator, resolver 同时存在）

**建议重组**:
```
application/
├── services/              # 核心业务服务
│   ├── reader_preferences_service.dart
│   ├── reader_content_service.dart
│   └── reader_progress_service.dart
├── controllers/           # UI 状态控制器（Riverpod Notifiers）
│   ├── reader_session_controller.dart
│   └── reader_settings_controller.dart
├── models/                # 应用层模型（非 domain）
│   ├── reader_mode_model.dart
│   └── reader_surface_metrics.dart
└── use_cases/             # 复杂业务用例（可选）
    ├── load_chapter_content.dart
    └── switch_reading_source.dart
```

### 4. ⚠️ Presentation 层组件拆分不足

**问题**: widgets/ 子目录只有 1 个文件

```bash
presentation/widgets/
└── reader_typography_slider_row.dart  # 仅此一个！
```

**但是 presentation/ 根目录有 62 个文件**，其中包含大量应该抽取的组件：
- `reader_chrome_widgets.dart` (22KB)
- `reader_overlay_widgets.dart` (14KB)
- `reader_audio_view.dart` (20KB)
- `reader_manga_view.dart` (19KB)

**建议**:
```
presentation/
├── pages/
│   ├── reader_page.dart              # 主页面
│   └── reading_records_page.dart
├── widgets/                          # 可复用组件
│   ├── reader_chrome/
│   │   ├── reader_appbar.dart
│   │   ├── reader_bottom_bar.dart
│   │   └── reader_progress_indicator.dart
│   ├── reader_content/
│   │   ├── reader_text_view.dart
│   │   ├── reader_audio_view.dart
│   │   └── reader_manga_view.dart
│   ├── reader_overlay/
│   │   ├── reader_menu_overlay.dart
│   │   └── reader_selection_overlay.dart
│   └── shared/
│       └── reader_typography_slider.dart
└── sheets/                           # Bottom Sheets
    ├── reader_settings_sheet.dart
    └── reader_catalog_sheet.dart
```

### 5. ⚠️ 状态管理不规范

**统计数据**:
- 使用 `StatefulWidget/StatelessWidget`: 20 个文件
- 使用 `ConsumerWidget/ConsumerStatefulWidget`: 2 个文件
- **Riverpod 使用率**: 9% ❌

**违反项目规范** (CLAUDE.md):
> 使用 Riverpod 进行状态管理，避免使用 StatefulWidget 管理全局状态

**问题示例**:
```dart
// ❌ 错误：大量使用 StatefulWidget
class ReaderChrome extends StatefulWidget { ... }
class ReaderAnnotation extends StatefulWidget { ... }
class ReaderImageView extends StatefulWidget { ... }

// ✅ 应该使用 ConsumerWidget + Riverpod
class ReaderChrome extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chromeState = ref.watch(readerChromeProvider);
    // ...
  }
}
```

### 6. ⚠️ 超大文件列表

| 文件 | 行数 | 大小 | 问题 |
|------|------|------|------|
| `reader_page.dart` | 6245 | 214KB | ❌ God Class |
| `reader_page_settings_sheet.dart` | 4430 | 220KB | ❌ 过大 |
| `reading_records_page.dart` | 2754 | 96KB | ⚠️ 需拆分 |
| `reader_page_runtime.dart` | 1895 | 57KB | ⚠️ 需拆分 |
| `reader_catalog_sheet.dart` | 1903 | 64KB | ⚠️ 需拆分 |

**标准**: 单个文件应 < 500 行（复杂页面可放宽到 800 行）

---

## 🎯 重构建议

### Priority 1: 紧急重构 🔥

#### 1.1 拆分 reader_page.dart

**目标**: 6245 行 → 多个 < 500 行的文件

**步骤**:
1. 提取状态管理到 Riverpod Notifier
2. 拆分 UI 组件到独立 widget 文件
3. 移除 `part of` 模式，使用正常的 import
4. 提取业务逻辑到 application 层 service

**示例重构**:
```dart
// ✅ reader_page.dart (简化后 ~150 行)
class ReaderPage extends ConsumerWidget {
  const ReaderPage({required this.bookId, required this.chapterId});
  
  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerState = ref.watch(readerControllerProvider(bookId));
    
    return Scaffold(
      body: ReaderContentView(state: readerState),
      appBar: ReaderAppBar(state: readerState),
      bottomNavigationBar: ReaderBottomBar(state: readerState),
    );
  }
}

// ✅ reader_controller.dart (~200 行)
@riverpod
class ReaderController extends _$ReaderController {
  @override
  ReaderState build(String bookId) {
    // 初始化逻辑
  }
  
  Future<void> loadChapter(String chapterId) async { ... }
  void toggleSettings() { ... }
  // ...
}

// ✅ widgets/reader_content_view.dart (~300 行)
class ReaderContentView extends ConsumerWidget {
  const ReaderContentView({required this.state});
  final ReaderState state;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.mode) {
      ReaderMode.text => ReaderTextView(content: state.content),
      ReaderMode.audio => ReaderAudioView(content: state.content),
      ReaderMode.manga => ReaderMangaView(content: state.content),
    };
  }
}
```

#### 1.2 建立 Clean Architecture 分层

**步骤**:
1. 创建 `lib/features/reader/domain/` 层
2. 将 `lib/domain/entities/reader_*.dart` 移入 feature domain
3. 定义 repository 接口
4. 创建 `lib/features/reader/data/` 层实现 repository

### Priority 2: 重要改进 ⚠️

#### 2.1 重组 Application 层

**目标**: 统一命名规范，清晰职责划分

**规则**:
- **Service**: 无状态业务逻辑（纯函数/单例）
- **Controller**: Riverpod Notifier，管理页面/功能状态
- **Model**: 数据模型（freezed + json_serializable）
- **Use Case**: 复杂跨服务的业务流程（可选）

**禁止使用**:
- ❌ Resolver（职责不清）
- ❌ Coordinator（与 Controller 重复）
- ❌ Facade（过度抽象）
- ❌ Presenter（违反 Clean Architecture）

#### 2.2 规范 Widget 层级

```
presentation/
├── pages/           # 完整页面（route 入口）
├── widgets/         # 可复用组件（中等粒度）
├── components/      # 原子组件（小粒度）
└── sheets/          # Bottom Sheets / Dialogs
```

#### 2.3 全面采用 Riverpod

**迁移计划**:
1. 识别所有使用 `setState` 的 StatefulWidget
2. 评估是否为局部 UI 状态（如动画）
3. 如果涉及业务状态，迁移到 Riverpod Provider
4. 局部 UI 状态可保留 StatefulWidget

### Priority 3: 长期优化 ✅

#### 3.1 完善测试

```
test/features/reader/
├── domain/
│   └── entities/
├── data/
│   └── repositories/
├── application/
│   ├── services/
│   └── controllers/
└── presentation/
    └── widgets/
```

#### 3.2 性能优化

- 使用 `const` 构造函数
- 实现 `==` 和 `hashCode` 避免不必要的重建
- 使用 Riverpod 的 `select` 精确订阅
- 大列表使用 `ListView.builder`

---

## 阶段任务（可勾选版）

### 阶段 0：冻结行为与风险基线（0.5-1 天）

- [ ] 记录当前阅读器关键路径：本地书进入、在线书进入、上一章/下一章、纸页、仿真、滚动、设置弹层、目录弹层、书源切换。
- [ ] 整理一份最小手工验收清单，明确 Android 真机必测，iOS/桌面按影响面补测。
- [ ] 为 `reader_page.dart` 当前 `part` 文件画出职责表，标记哪些能先独立、哪些不能碰。
- [ ] 建立重构分支规则：每个 PR/提交只拆一个功能边界，禁止混入视觉和业务行为调整。

### 阶段 1：设置页先拆，收益最大（1-2 天）

- [ ] 将 `reader_page_settings_sheet.dart` 按区域拆成 `appearance`、`layout`、`page_turning`、`advanced` 等 sheet section widget。
- [ ] 保持所有设置项 provider / service 调用不变，只移动 UI 结构，不改业务语义。
- [ ] 抽出通用设置行、滑块行、开关行，复用已有 `ReaderTypographySliderRow` 风格。
- [ ] 验收：应用外观、字体、背景、翻页动画、纸页设置、底部弹层高度在 Android 真机表现不变。

### 阶段 2：主阅读页拆“纯展示层”（2-3 天）

- [ ] 从 `reader_page.dart` / `part` 中优先拆出无副作用 widget：顶部信息、底部信息、页码角标、加载/错误态、背景层。
- [ ] 将 `reader_chrome_widgets.dart`、`reader_overlay_widgets.dart` 归档到 `presentation/widgets/chrome/` 与 `presentation/widgets/overlay/`。
- [ ] 保留 `_ReaderPageState` 的核心状态和导航方法，暂不迁 Riverpod。
- [ ] 验收：纸页、仿真、覆盖动画、点击翻页、上下章节点、菜单显隐无行为变化。

### 阶段 3：翻页与视口边界收口（2-4 天）

- [ ] 把分页动画相关入口统一到 `presentation/paged_animation/`，明确纸页、仿真、平移、覆盖、滚动各自的 renderer 边界。
- [ ] 将 `reader_paper_curl_paged_view.dart` 只保留组件内部局部状态，不让它直接依赖主页面业务状态。
- [ ] 抽出阅读视口输入模型，例如 page index、chapter id、blocks、theme、animation type。
- [ ] 补一组 Android 真机回归：纸页不闪字、仿真不误切、快速连续翻页不串页、上下章边界不失效。

### 阶段 4：状态边界渐进迁移（3-5 天）

- [ ] 只迁移“跨组件共享且非动画”的状态到 controller/provider，例如目录显隐、设置面板显隐、书源切换状态、内容加载状态。
- [ ] 保留动画控制器、滚动控制器、手势临时状态在 StatefulWidget 内。
- [ ] 新增状态对象时使用不可变模型，避免多个 widget 直接修改同一份可变字段。
- [ ] 验收：热重载、进入退出阅读器、切章节、切书源、后台回来恢复阅读位置正常。

### 阶段 5：数据与 domain 边界只做新功能准入（后续迭代）

- [ ] 新增阅读器数据能力时，先定义 reader feature 内的接口，不再把新 reader entity 放到全局目录。
- [ ] 盘点 `lib/domain/entities/reader_*` 的跨模块引用，确认没有外部强依赖后再分批迁移。
- [ ] 暂不强迁现有 repository/data 层；等本地书、在线书、缓存、进度四条链路边界稳定后再做。
- [ ] 验收：迁移只改 import 和落点，不改序列化字段、不改数据库表、不改接口 payload。

### 阶段 6：清理命名与测试补齐（长期维护）

- [ ] 新增代码统一命名：页面状态用 controller，纯业务用 service，展示转换用 presenter/mapper 二选一。
- [ ] 旧 resolver/coordinator/facade 不单独开大清理任务，只在对应功能被修改时合并或改名。
- [ ] 为阅读器补最小单元测试：分页输入、章节边界、设置持久化、书源切换错误态。
- [ ] 更新本文件已完成勾选项，并记录每阶段实际验证平台。

---

## 🔗 参考资料

- [项目规范 - CLAUDE.md](../../CLAUDE.md)
- [架构规范 - development_architecture_guardrails.md](../../standards/development_architecture_guardrails.md)
- [Flutter Clean Architecture](https://github.com/ResoCoder/flutter-clean-architecture-tdd)
- [Riverpod 最佳实践](https://riverpod.dev/docs/essentials/combining_requests)

---

## 总结

阅读器功能当前存在明确的维护风险，主要体现在：

1. **God Class 反模式**: `reader_page.dart` 6245 行不可维护
2. **设置页过重**: `reader_page_settings_sheet.dart` 4430 行，后续 UI 调整风险高
3. **分层边界不清**: reader 的 domain/data 边界需要逐步收敛，但不适合一次性迁移
4. **状态边界混杂**: 业务状态、动画状态、手势状态混在主页面里，需要渐进拆分
5. **组件目录不清晰**: `presentation/` 根目录过平，widgets/sheets/chrome/overlay 等边界需要补齐

**建议启动渐进式治理**，优先执行阶段 0-3：冻结行为、拆设置页、拆纯展示层、收口翻页与视口边界。阶段 4-6 放到后续迭代，不建议在当前发版前做全量状态迁移或 domain/data 大搬家。

完成阶段 0-3 后，预期收益不是“架构评分立刻变高”，而是阅读器后续修 bug 的影响面明显变小，尤其是 Android 翻页、设置弹层、章节切换这些高频问题会更容易定位。
