# UI/UX 全面审计与改进方案

创建时间：2026-06-10  
审计角度：产品经理 + UI 设计师  
**用途：指导后续 UI/UX 设计，建立统一体验标准**

## 📊 执行摘要

### 当前问题
- ❌ UI 风格不统一，改了好几版
- ❌ 缺少统一的交互规范  
- ❌ 缺少页面过渡动画
- ❌ 缺少 UI 特效和微交互
- ❌ 想到什么做什么，没有整体规划

### 改进目标
- ✅ 建立统一的 UI 设计系统
- ✅ 制定交互规范和动效规范
- ✅ 提升用户体验一致性
- ✅ 打造 Selune 品牌差异化体验

---

## 一、当前状态审计

### 1. 品牌定位 ✅ 基础良好

**已有：**
- 品牌名称：Selune（月光）
- 品牌气质：轻、静、柔、精
- 品牌关键词：Moonlit, Quiet luxury, Soft premium
- 默认主题：霁雪白（清爽浅色）

**评价：** 品牌定位清晰，但实际执行中一致性不够

### 2. 视觉风格 ⚠️ 不统一

**已有规范：**
- 圆角：16dp（卡片）、14dp（输入框）
- 颜色：Material 3 ColorScheme
- 间距：AppAdaptiveMetrics

**问题：**
- UI 风格不统一，卡片/按钮样式有多种变体
- 缺少视觉层次规范（何时用卡片、何时用分隔线）
- 强调色使用规则不明确

### 3. 交互模式 ⚠️ 规范缺失

**已有：**
- 底部导航（移动端）、侧边栏（桌面端）
- 下拉刷新、长按菜单、滑动删除

**问题：**
- 长按菜单 vs 更多按钮，选择标准不清晰
- 对话框 vs 底部弹层，使用混乱
- 点击反馈、加载状态不统一
- 桌面端键盘快捷键、右键菜单缺失

### 4. 动画效果 ❌ 严重不足

**已有：** 171处动画（Hero、AnimatedContainer等）

**问题：**
- 动画使用不系统，有的页面有，有的没有
- 动画时长、曲线不统一
- 缺少微交互动画
- 没有品牌特色动画（都是 Material 默认）
- 缺少"月光感"的视觉隐喻

---

## 二、核心问题分析

### 根本原因

#### 问题1：缺少设计系统 ⚠️

**表现：** UI 组件随意组合，新功能"随便找个类似的抄"  
**原因：** 没有设计系统文档、组件库规范、Design Token 体系  
**影响：** 开发效率低、用户体验不一致、维护成本高

#### 问题2：缺少交互规范 ⚠️

**表现：** 同样操作，不同页面交互不同  
**原因：** 没有交互规范文档、组件使用指南  
**影响：** 学习成本高、操作效率低、容易误操作

#### 问题3：缺少动效规范 ❌

**表现：** 动画时长从100ms到500ms都有，曲线随意选择  
**原因：** 没有动效规范、开发者不知道何时用动画  
**影响：** 体验不流畅、缺少品牌记忆点、显得不专业

### 竞品对比启发

**微信读书：** 交互一致性好、微交互细腻、品牌识别度高  
**多看阅读：** 功能完善但 UI 老旧、动画生硬

**启发：** 交互一致性 > 功能堆砌，动画是必需品，不是奢侈品

---

## 三、设计体系建设方案

### 3.1 建立 Design Token 体系

#### Spacing Token（间距）

```dart
class AppSpacing {
  // 基础间距
  static const double xs = 4.0;   // 超小间距
  static const double sm = 8.0;   // 小间距
  static const double md = 12.0;  // 中等间距
  static const double lg = 16.0;  // 大间距
  static const double xl = 24.0;  // 超大间距
  static const double xxl = 32.0; // 特大间距
  
  // 语义化间距
  static const double cardPadding = 12.0;
  static const double pagePadding = 16.0;
  static const double sectionGap = 16.0;
  static const double itemGap = 8.0;
}
```

#### Radius Token（圆角）

```dart
class AppRadius {
  static const double none = 0.0;
  static const double sm = 8.0;    // 小组件
  static const double md = 12.0;   // 中等组件
  static const double lg = 16.0;   // 卡片
  static const double xl = 20.0;   // 大卡片
  static const double full = 999.0; // 胶囊
}
```

#### Elevation Token（层级）

```dart
class AppElevation {
  static const double level0 = 0.0;  // 平面
  static const double level1 = 1.0;  // 轻微悬浮
  static const double level2 = 2.0;  // 卡片
  static const double level3 = 4.0;  // 对话框
  static const double level4 = 8.0;  // 导航抽屉
}
```

### 3.2 统一组件样式

#### 卡片组件规范

**基础卡片：**
- 圆角：16dp
- 内边距：12dp
- 背景：surfaceContainerLow.withAlpha(0.82)
- 边框：outlineVariant.withAlpha(0.32)
- 最小高度：根据内容，重要卡片≥72dp

**使用场景：**
- 列表项（书源、书籍、记录）
- 设置项组
- 信息展示块

#### 按钮组件规范

**主要按钮（FilledButton）：**
- 高度：40dp（移动端）、36dp（桌面端）
- 圆角：14dp
- 最小宽度：88dp
- 使用场景：主要操作（确定、提交、登录）

**次要按钮（OutlinedButton）：**
- 高度：40dp（移动端）、36dp（桌面端）
- 圆角：14dp
- 边框：1px
- 使用场景：次要操作（取消、返回）

**文本按钮（TextButton）：**
- 高度：40dp（移动端）、36dp（桌面端）
- 无边框
- 使用场景：弱操作（跳过、了解更多）

#### 输入框规范

**标准输入框：**
- 高度：48dp（移动端）、40dp（桌面端）
- 圆角：14dp
- 边框：outlineVariant.withAlpha(0.28)
- 聚焦边框：primary.withAlpha(0.7)

### 3.3 视觉层次规范

#### 信息层级

**第1层：页面主体内容**
- 背景：surface 或 background
- 文字：onSurface
- 用途：主要内容展示区

**第2层：卡片/容器**
- 背景：surfaceContainerLow
- 描边：outlineVariant
- 用途：内容分组

**第3层：强调/悬浮**
- 背景：surfaceContainerHigh
- 阴影：elevation 2-4
- 用途：对话框、悬浮按钮

#### 颜色使用规则

**主色（Primary）：**
- 主要操作按钮
- 重要图标
- 选中状态
- **不要：** 大面积使用、当作背景色

**强调色（Accent/Secondary）：**
- 次要按钮
- 辅助图标
- 状态提示

**语义色：**
- 成功：success（绿色系）
- 警告：warning（橙色系）
- 错误：error（红色系）
- 信息：info（蓝色系）

---
