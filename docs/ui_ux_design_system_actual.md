# UI/UX 设计体系总结（基于实际代码）

创建时间：2026-06-10  
基于：实际主题代码审计  
用途：记录当前真实的设计规范，指导后续开发

---

## 一、当前设计规范（实际代码）

### 1.1 圆角规范

**实际使用值：**
```dart
// 来自 app_component_theme_tokens.dart
卡片：20dp
按钮：14dp（rounded）/ stadium（胶囊形）
输入框：14dp
弹窗/对话框：16dp
底部弹层：顶部 20dp
```

**使用建议：**
- 卡片类：20dp（大圆角，柔和）
- 按钮/输入框：14dp（中等圆角）
- 弹窗：16dp
- 小组件：12dp

---

### 1.2 间距规范

**需要补充 Design Token，当前散落各处**

**建议统一为：**
```dart
class AppSpacing {
  static const double xs = 4.0;   // 最小间距
  static const double sm = 8.0;   // 小间距
  static const double md = 12.0;  // 中等间距
  static const double lg = 16.0;  // 大间距
  static const double xl = 24.0;  // 超大间距
  static const double xxl = 32.0; // 特大间距
}
```

---

### 1.3 颜色规范

**当前架构：**
- 使用 Material 3 ColorScheme
- 支持高级主题自定义颜色
- 已有完善的颜色 token 系统

**主要颜色：**
```dart
primary: 主色调
onPrimary: 主色上的文字
surface: 页面背景
onSurface: 表面上的文字
surfaceContainerLow: 卡片背景
outlineVariant: 边框/分隔线
```

---

### 1.4 阴影规范

**实际使用：**
```dart
// 卡片阴影
elevation: 0  // 不使用 Material elevation
shadowBlur: 16
shadowOffsetY: 6
shadowAlpha: 根据主题动态调整

// 弹窗阴影
elevation: 根据主题动态调整
```

**说明：** 当前使用自定义阴影而不是 Material 默认 elevation

---

## 二、组件规范（实际代码）

### 2.1 卡片（Card）

**实际样式：**
```dart
圆角：20dp
边框：1px（outlineVariant）
阴影：shadowBlur 16, offsetY 6
背景：cardColor / surfaceContainerLow
```

**使用场景：**
- 列表项（书籍卡片、书源卡片）
- 信息展示块
- 设置项组

---

### 2.2 按钮（Button）

**实际样式：**
```dart
// 主要按钮（FilledButton）
形状：stadium（胶囊）或 rounded（圆角14dp）
高度：根据平台动态（移动端略高）
水平内边距：根据主题动态

// 次要按钮（OutlinedButton）
边框：1-1.5px
其他同主要按钮

// 文本按钮（TextButton）
无边框，只有文字和点击效果
```

---

### 2.3 输入框（TextField）

**实际样式：**
```dart
圆角：14dp
边框：outlineVariant（默认）
聚焦边框：primary（加粗）
背景：可选填充色
```

---

### 2.4 弹窗/对话框

**实际样式：**
```dart
// 对话框
圆角：16dp
边框：1px
背景：modalSurfaceColor
阴影：根据主题动态

// 底部弹层
顶部圆角：20dp
边框：1px（顶部和两侧）
背景：modalSurfaceColor
```

---

## 三、动画规范（需要补充）

### 3.1 时长标准（建议）

```dart
class AppDuration {
  static const instant = Duration(milliseconds: 100);   // 微交互
  static const fast = Duration(milliseconds: 200);      // 快速
  static const normal = Duration(milliseconds: 300);    // 标准
  static const medium = Duration(milliseconds: 400);    // 中速
}
```

**当前状态：** 动画时长散落各处，需要统一

---

### 3.2 曲线标准（建议）

```dart
class AppCurves {
  static const easeIn = Curves.easeIn;
  static const easeOut = Curves.easeOut;
  static const easeInOut = Curves.easeInOut;
  static const emphasized = Cubic(0.4, 0.0, 0.2, 1.0);
}
```

**当前状态：** 未统一，各处自行选择曲线

---

## 四、高级主题能力（已实现）

### 4.1 可定制项

**已支持：**
- 全局圆角缩放（globalRadiusScale: 0.5-2.0）
- 阴影强度（shadowStrength: 0.0-1.0）
- 卡片样式（soft/outlined/elevated）
- 按钮样式（stadium/rounded/sharp）
- 输入框样式（soft/outlined/underlined）
- 导航样式（soft/floating/compact）
- 开关样式（soft/contrast）
- 自定义壁纸

**架构：**
- 完善的主题 token 系统
- 支持深浅模式
- 支持导入导出

---

## 五、需要改进的地方

### 5.1 缺少统一的 Design Token

**问题：**
- 间距值散落各处（8、12、16、24 等）
- 动画时长不统一
- 没有中心化的 token 文件

**建议：**
- 创建 `lib/app/design_tokens/app_spacing.dart`
- 创建 `lib/app/design_tokens/app_duration.dart`
- 创建 `lib/app/design_tokens/app_curves.dart`

---

### 5.2 动画使用不系统

**问题：**
- 有 171 处动画，但使用不一致
- 有的页面有动画，有的没有
- 时长和曲线随意

**建议：**
- 制定动画使用规范
- 统一页面过渡动画
- 添加微交互动画

---

### 5.3 空状态/错误状态不统一

**问题：**
- 不同页面空状态样式不同
- 错误提示方式不一致

**建议：**
- 创建统一的 `AppEmptyState` 组件
- 创建统一的 `AppErrorState` 组件
- 统一 SnackBar 样式

---

## 六、实施建议

### 优先级 P0（立即补充）

1. **创建 Design Token 文件**
   - `app_spacing.dart`
   - `app_duration.dart`
   - `app_curves.dart`

2. **创建统一组件**
   - `AppEmptyState` - 空状态
   - `AppErrorState` - 错误状态
   - `AppLoadingIndicator` - 加载指示器

3. **统一高频页面**
   - 书架页
   - 搜索页
   - 阅读器
   - 我的页面

---

### 优先级 P1（逐步优化）

4. **补充动画**
   - 页面过渡动画
   - 列表项动画
   - 微交互动画

5. **高级主题优化**
   - 入口优化
   - 编辑体验优化
   - 主题市场

---

## 七、设计原则（基于实际）

### 当前风格特点

1. **Material 3 为基础**
   - 使用 Material 3 设计语言
   - ColorScheme 驱动
   - 支持自定义扩展

2. **较大的圆角**
   - 卡片 20dp
   - 整体偏柔和风格

3. **轻阴影**
   - elevation 通常为 0
   - 使用自定义 shadow
   - 不强调立体感

4. **可定制性强**
   - 高级主题功能完善
   - 用户可深度定制

---

## 八、与之前文档的差异

**删除内容：**
- ❌ "月光感" 品牌描述（与实际不符）
- ❌ "Selune" 品牌动画（未实现）
- ❌ 品牌色定义（实际用 Material 3）

**保留内容：**
- ✅ Design Token 概念（需补充）
- ✅ 组件规范（基于实际值）
- ✅ 高级主题优化方案
- ✅ 实施计划

---

## 相关文档

- [交互规范与动效指南](ui_ux_interaction_and_animation_guide.md)
- [高级主题体验优化方案](advanced_theme_experience_optimization.md)
- [实施计划](ui_ux_implementation_plan.md)

---

**维护说明：**
- 本文档基于实际代码审计
- 不包含未实现的品牌概念
- 以实用为主，指导开发

**最后更新：** 2026-06-10