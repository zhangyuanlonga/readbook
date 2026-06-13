# UI/UX 设计规范

UI/UX 设计体系文档，定义视觉规范、交互标准和审查流程。

## 🎯 最终目标

### UI/UX标准化目标

**执行这些规范后，页面将达到：**

1. **视觉统一** ✅
   - 圆角一致（卡片20dp、按钮14dp）
   - 间距规范（基于AppAdaptiveMetrics自适应）
   - 颜色主题统一（AppThemeColors）
   - 字体大小合理（不会过大或过小）

2. **多端完整展示** ⭐ **核心目标**
   - **小屏手机**（iPhone SE/小安卓）：内容不省略、不变形
   - **大屏手机**（iPhone 15/Plus）：布局合理、不浪费空间
   - **平板竖屏**（iPad mini）：适配2-3列布局
   - **平板横屏**（iPad Air）：显示侧边栏、多列内容
   - **桌面端**（Mac/Windows）：充分利用大屏、内容不过宽

3. **不同机型适配** ✅
   - **iPhone SE（4.7寸）**：内容完整显示，不截断
   - **iPhone 15（6.1寸）**：标准体验
   - **iPhone 15 Pro Max（6.9寸）**：内容不超大、布局优化
   - **安卓小屏**（5-5.5寸）：触摸目标足够大（44x44dp）
   - **安卓平板**（7-13寸）：自动切换多列布局

4. **避免常见问题** ❌
   - ❌ 内容被截断、省略
   - ❌ 文字过小或过大
   - ❌ 按钮太小点不到
   - ❌ 平板上单列布局太窄
   - ❌ 桌面端文字行过长
   - ❌ 横屏时布局变形

---

## 📚 核心文档

### 设计规范

- **[多端适配设计规范](multiplatform_adaptive_design.md)** ⭐ **Flutter必读** - 响应式断点、平台适配
  - 5个响应式断点（compact → expanded）
  - Android/iOS/Web/桌面端适配策略
  - 10+个自适应组件使用指南
  - 适配检查清单

- **[设计系统（实际代码）](ui_ux_design_system_actual.md)** - 基于实际代码的设计规范
  - 圆角规范（卡片20dp、按钮14dp等）
  - 间距规范（基于AppAdaptiveMetrics）
  - 颜色系统（Material 3 ColorScheme + 高级主题 palette）
  - 组件样式规范

- **[UI 治理基线与标准收敛](ui_governance_baseline_and_standards.md)** - Phase 0/1 产物
  - Token、Theme、Adaptive 组件来源表
  - 合法例外和试点范围
  - 新增 UI Review checklist

- **[交互与动效指南](ui_ux_interaction_and_animation_guide.md)** - 交互规范和动画标准
  - 操作反馈规范（点击、悬停、手势）
  - 动画时长和缓动曲线
  - 页面转场效果
  - 响应式布局断点

### 审查与优化
- **[审查标准与优化方向](ui_ux_review_standards_and_optimization.md)** - 可执行的审查清单
  - 5大维度审查：视觉一致性、交互体验、动画流畅度、响应式、文案规范
  - 优化优先级（P0/P1/P2）
  - 每个页面的审查清单

### 实施计划

- **[UI 治理阶段任务清单](ui_governance_phased_task_checklist.md)** - 可打勾的阶段任务
  - 收敛现有 Token 和 Adaptive 体系
  - 拆分 Phase 0-5 阶段任务
  - 提供试点迁移、自动化检查、模块推广 checklist

- **[执行路线图](EXECUTION_ROADMAP.md)** ⭐ **决策必读** - 任务优先级和执行建议
  - 快速决策检查清单
  - 最小可行方案（1周）vs 理想方案（3-4周）
  - 按资源情况选择执行策略

- **实施计划详细版** - 已归档到 `archive/2026-06-11-ui_ux_implementation_plan_archived.md`

## 🔗 相关文档

### 功能特性
- **高级主题功能优化** → [docs/features/reader/advanced_theme_experience_optimization.md](../features/reader/advanced_theme_experience_optimization.md)
  - 核心付费功能的体验优化方案

### 历史文档
- **UI/UX专家审查报告（2026-06-11）** → [docs/archive/2026-06-11-ui_ux_expert_review.md](../archive/2026-06-11-ui_ux_expert_review.md)
  - Flutter专家对设计规范的审查反馈

## 🎯 快速参考

### 多端适配（Flutter项目必读）

**响应式断点：**
- compact: <390dp（小屏手机 iPhone SE）
- largePhone: 390-479dp（大屏手机 iPhone 13/14/15）
- phoneXl: 480-599dp（超大手机 Pro Max）
- medium: 600-839dp（平板竖屏）
- expanded: ≥840dp（平板横屏/桌面端）

**平台覆盖：**
- Android：5-7寸手机、7-13寸平板
- iOS：iPhone（compact-phoneXl）、iPad（medium-expanded）
- 桌面端：macOS/Windows/Linux（expanded+）
- Web：全响应式支持

**自适应组件：**
- 已实现10+个adaptive_组件（`lib/app/widgets/`）
- 使用AppAdaptiveMetrics统一适配

**详细说明：** [多端适配设计规范](multiplatform_adaptive_design.md)

---

### 设计变量速查

**圆角：**
- 卡片：20dp
- 按钮：14dp（rounded）/ stadium（胶囊形）
- 输入框：14dp
- 弹窗：16dp
- 底部弹层：顶部20dp

**间距：**
- 参考 `lib/app/layout/app_adaptive.dart`
- 手机端：16dp（标准间距）
- 平板/桌面：根据屏幕宽度自适应

**动画时长：**
- 快速：120ms
- 标准：180ms
- 慢速：260ms
- 页面：300ms
- 缓动曲线：`AppMotion.standard` / `Curves.easeOutCubic`

### 组件库

**已实现：**
- AdaptiveCard - 统一自适应卡片样式
- AppButton - 语义按钮薄封装
- AppTextField - 普通表单输入薄封装
- AppEmptyStateCard - 空状态卡
- AppStatusStateCard - 错误/警告/状态卡
- 参考 `lib/app/widgets/`

**待实现：**
- AppLoadingIndicator - 加载指示器
- OperationSurfaceFrame - 标题/内容/操作区框架
- AppErrorState - 如需要，可基于 `AppStatusStateCard` 再做语义别名
- （详见实施计划）

## 📝 使用指南

### 新增页面开发
1. 参考 [多端适配规范](multiplatform_adaptive_design.md) 选择正确的断点策略
2. 参考 [设计系统](ui_ux_design_system_actual.md) 使用正确的圆角、间距
3. 参考 [交互指南](ui_ux_interaction_and_animation_guide.md) 实现操作反馈
4. 完成后使用 [审查清单](ui_ux_review_standards_and_optimization.md) 自查
5. 在至少5个断点上测试（compact / largePhone / phoneXl / medium / expanded）

### UI/UX审查
1. 打开 [审查标准](ui_ux_review_standards_and_optimization.md)
2. 按5大维度逐项检查
3. 记录问题并标注优先级（P0/P1/P2）

### 设计规范更新
1. 修改 [设计系统](ui_ux_design_system_actual.md) 文档
2. 同步更新代码中的实现（Design Tokens）
3. 通知团队设计规范变更

---

**维护者：** 产品团队 + UI设计师  
**最后更新：** 2026-06-11
