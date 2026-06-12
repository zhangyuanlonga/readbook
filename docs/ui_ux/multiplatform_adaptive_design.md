# Flutter 多端适配设计规范

**创建时间:** 2026-06-11  
**适用平台:** Android、iOS、Web、macOS、Windows、Linux  
**核心系统:** `lib/app/layout/app_layout.dart` + `lib/app/layout/app_adaptive.dart`

---

## 📱 响应式断点系统

### 断点定义（基于逻辑宽度dp）

项目使用**逻辑宽度**（dp/pt）而非物理分辨率进行适配，确保跨平台一致性。

| 断点名称 | 宽度范围 | 设备类型 | 典型设备 |
|---------|---------|---------|---------|
| **compact** | 0-389dp | 小屏手机 | iPhone SE, 6/7/8 (4.7寸) |
| **largePhone** | 390-479dp | 大屏手机 | iPhone 16, 13/14/15 (6.1寸) |
| **phoneXl** | 480-599dp | 超大手机/横屏 | iPhone 16 Pro Max (6.9寸), 横屏手机 |
| **medium** | 600-839dp | 平板竖屏/小平板 | iPad mini 竖屏, 小安卓平板 |
| **expanded** | ≥840dp | 平板横屏/桌面 | iPad 横屏, 桌面端 |

### 桌面端细分

| 级别 | 宽度范围 | 典型场景 |
|-----|---------|---------|
| **desktop** | ≥1200dp | 13寸笔记本、小显示器 |
| **wideDesktop** | ≥1600dp | 15-24寸显示器 |
| **ultraWideDesktop** | ≥1920dp | 27寸+显示器、超宽屏 |

### 代码示例

```dart
// 使用AppAdaptiveMetrics获取断点
final adaptive = AppAdaptiveMetrics.of(context);

if (adaptive.isCompactWindow) {
  // 小屏手机布局（单列）
} else if (adaptive.isMediumWindow) {
  // 平板竖屏布局（可考虑两列）
} else if (adaptive.isExpandedWindow) {
  // 平板横屏/桌面布局（多列、侧边栏）
}

// 判断是否桌面端
if (adaptive.isDesktopLikeForPlatform(
  isWeb: kIsWeb,
  platform: Theme.of(context).platform,
)) {
  // 桌面端特殊布局
}
```

---

## 🎨 平台覆盖矩阵

### Android
| 机型 | 屏幕尺寸 | 逻辑宽度 | 断点 |
|-----|---------|---------|------|
| 小屏手机 | 5.0-5.5寸 | 320-360dp | compact |
| 标准手机 | 5.5-6.5寸 | 360-420dp | largePhone |
| 大屏手机 | 6.5-7.0寸 | 420-480dp | phoneXl |
| 小平板 | 7-8寸 | 600-720dp | medium |
| 标准平板 | 9-10寸 | 720-840dp | medium |
| 大平板 | 10-13寸 | 840-1024dp+ | expanded |

### iOS
| 机型 | 屏幕尺寸 | 逻辑宽度 | 断点 |
|-----|---------|---------|------|
| iPhone SE | 4.7寸 | 375dp | compact |
| iPhone 13 mini | 5.4寸 | 375dp | compact |
| iPhone 13/14/15 | 6.1寸 | 390dp | largePhone |
| iPhone 13/14/15 Plus | 6.7寸 | 428dp | phoneXl |
| iPhone 16 Pro Max | 6.9寸 | 440dp | phoneXl |
| iPad mini | 8.3寸 | 744dp (竖) / 1024dp (横) | medium / expanded |
| iPad Air/Pro | 10-13寸 | 820dp (竖) / 1180dp+ (横) | medium / expanded |

### 桌面端（macOS / Windows / Linux）
| 显示器 | 窗口宽度 | 断点 |
|--------|---------|------|
| 13寸笔记本 | 1200-1400dp | desktop |
| 15-24寸显示器 | 1600-1920dp | wideDesktop |
| 27寸+超宽屏 | 1920dp+ | ultraWideDesktop |

### Web
支持所有断点，从手机浏览器（compact）到大屏桌面浏览器（ultraWideDesktop）。

---

## 🧩 自适应组件库

项目已实现10+个自适应组件，自动根据屏幕尺寸调整布局。

### 核心自适应组件

| 组件 | 文件路径 | 功能 |
|-----|---------|------|
| **adaptive_page_scaffold** | `lib/app/widgets/` | 页面脚手架（自动切换单列/双列布局） |
| **adaptive_split_body** | `lib/app/widgets/` | 分栏布局（平板/桌面显示侧边栏） |
| **adaptive_card** | `lib/app/widgets/` | 自适应卡片（宽度、间距自适应） |
| **adaptive_list_tile** | `lib/app/widgets/` | 列表项（高度、密度自适应） |
| **adaptive_bottom_sheet** | `lib/app/widgets/` | 底部弹层（平板/桌面显示为对话框） |
| **adaptive_filter_bar** | `lib/app/widgets/` | 筛选栏（自适应布局） |
| **adaptive_fullscreen_preview** | `lib/app/widgets/` | 全屏预览 |
| **adaptive_overflow_toolbar** | `lib/app/widgets/` | 溢出工具栏 |
| **adaptive_setting_tile** | `lib/app/widgets/` | 设置项 |

### 使用指南

**优先使用自适应组件**，而不是手动判断屏幕尺寸：

```dart
// ❌ 不推荐：手动判断屏幕宽度
if (MediaQuery.of(context).size.width > 600) {
  return TwoColumnLayout();
} else {
  return SingleColumnLayout();
}

// ✅ 推荐：使用自适应组件
return AdaptiveSplitBody(
  primary: MainContent(),
  secondary: SidePanel(),
  // 自动根据断点切换单列/双列
);
```

---

## 📐 自适应设计原则

### 1. 内容优先

不同屏幕尺寸下优先展示的内容：

- **小屏 (compact)**: 核心内容，操作按钮
- **中屏 (medium)**: 核心内容 + 次要信息
- **大屏 (expanded)**: 核心内容 + 次要信息 + 辅助功能

### 2. 布局策略

| 屏幕类型 | 布局方式 | 示例 |
|---------|---------|------|
| **手机** | 单列垂直滚动 | 书架：1-2列网格 |
| **平板竖屏** | 单列或两列 | 书架：3-4列网格 |
| **平板横屏/桌面** | 多列 + 侧边栏 | 书架：4-6列网格 + 筛选侧边栏 |

### 3. 触摸目标最小尺寸

遵循Material Design和Human Interface Guidelines：

- **移动端**: 44x44 dp (iOS) / 48x48 dp (Android)
- **桌面端**: 可适当缩小，但不低于32x32 dp

### 4. 内容最大宽度

为提升大屏可读性，内容区域设置最大宽度：

```dart
// 定义在 lib/app/layout/app_layout.dart
bookshelfContentMaxWidth: 1320dp
bookDetailContentMaxWidth: 1120dp
searchContentMaxWidth: 920dp
settingsContentMaxWidth: 760dp
```

在桌面端超宽屏幕上，内容居中显示，避免文本行过长影响阅读。

---

## 🎯 适配检查清单

为每个页面/功能检查以下断点：

### 必查断点（P0）

- [ ] **compact (375dp)** - iPhone SE / iPhone 13 mini
- [ ] **largePhone (390dp)** - iPhone 13/14/15
- [ ] **phoneXl (428dp)** - iPhone Plus / Pro Max
- [ ] **medium (768dp)** - iPad mini 竖屏
- [ ] **expanded (1024dp)** - iPad 横屏

### 推荐检查（P1）

- [ ] **compact横屏 (667x375)** - 小屏手机横屏
- [ ] **largePhone横屏 (844x390)** - 大屏手机横屏
- [ ] **desktop (1280dp)** - 13寸笔记本
- [ ] **wideDesktop (1920dp)** - 27寸显示器

### 检查项

每个断点需要验证：

1. **布局正确性**
   - 内容不溢出屏幕
   - 元素间距合理
   - 网格列数适配（书架等）

2. **可操作性**
   - 按钮可点击（触摸目标足够大）
   - 表单输入可操作
   - 导航流畅

3. **可读性**
   - 文字大小合适（不要过小）
   - 行长适中（不要过长）
   - 对比度足够

4. **性能**
   - 列表滚动流畅（60fps）
   - 动画不卡顿

---

## 🛠️ 调试工具

### 1. 查看当前断点信息

```dart
// 在调试时打印当前适配信息
final adaptive = AppAdaptiveMetrics.of(context);
debugPrint('Window Class: ${adaptive.windowClass}');
debugPrint('Width: ${adaptive.width}dp');
debugPrint('Density: ${adaptive.density}');
```

### 2. Flutter DevTools 响应式预览

- 打开 Flutter DevTools
- 使用 Device Preview 功能测试不同设备
- 自定义尺寸测试边界情况

### 3. 常用测试尺寸

**手机：**
```
375x667  - iPhone SE / 8
390x844  - iPhone 13/14/15
428x926  - iPhone 14 Plus / 15 Pro Max
360x800  - Android标准手机
```

**平板：**
```
768x1024 - iPad mini 竖屏
1024x768 - iPad mini 横屏
820x1180 - iPad Air 竖屏
1180x820 - iPad Air 横屏
```

**桌面：**
```
1280x720  - 小笔记本
1920x1080 - 标准显示器
2560x1440 - 2K显示器
```

---

## 📚 参考代码

### 核心文件

1. **布局系统** - `lib/app/layout/app_layout.dart`
   - 断点定义
   - 响应式配置
   - 内容最大宽度

2. **自适应指标** - `lib/app/layout/app_adaptive.dart`
   - AppAdaptiveMetrics（自适应指标系统）
   - AppWindowClass（窗口类别枚举）
   - AppDensity（密度枚举）

3. **间距系统** - `lib/app/layout/app_spacing.dart`
   - 自适应间距定义

4. **尺寸Token** - `lib/app/layout/app_size_tokens.dart`
   - 组件尺寸定义

### 自适应组件示例

```dart
// 使用 adaptive_split_body 实现响应式分栏
AdaptiveSplitBody(
  breakpoint: 840, // medium → expanded 切换点
  primary: BookList(), // 主内容
  secondary: FilterPanel(), // 侧边栏（小屏隐藏）
)

// 使用 adaptive_bottom_sheet 实现响应式弹层
showAdaptiveBottomSheet(
  context: context,
  builder: (context) => FilterOptions(),
  // 小屏：底部弹层
  // 大屏：居中对话框
)
```

---

## 🎨 实战案例

### 案例1：书架页面适配

**需求：** 不同屏幕显示不同列数

**实现：**
```dart
final adaptive = AppAdaptiveMetrics.of(context);
final crossAxisCount = adaptive.width >= 1400 ? 6
    : adaptive.width >= 1100 ? 5
    : adaptive.width >= 800 ? 4
    : adaptive.width >= 320 ? 3
    : 2;

GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    childAspectRatio: 0.7,
  ),
  // ...
)
```

### 案例2：设置页面适配

**需求：** 桌面端显示侧边栏导航

**实现：**
```dart
AdaptiveSplitBody(
  breakpoint: 840,
  primary: SettingContent(),
  secondary: SettingNavigation(),
  // 小屏：单页导航
  // 大屏：侧边栏 + 内容区
)
```

---

## ✅ 总结

### 必做事项

1. ✅ 使用项目已有的断点系统（不要自定义）
2. ✅ 优先使用自适应组件（`adaptive_*.dart`）
3. ✅ 测试至少5个核心断点（compact / largePhone / phoneXl / medium / expanded）
4. ✅ 设置内容最大宽度（避免桌面端文本过长）
5. ✅ 遵循最小触摸目标尺寸（44x44 / 48x48 dp）

### 禁止事项

1. ❌ 不要使用物理分辨率判断（用逻辑宽度dp）
2. ❌ 不要硬编码屏幕宽度阈值（用AppAdaptiveMetrics）
3. ❌ 不要忽略平板适配（中国市场安卓平板用户量大）
4. ❌ 不要在小屏设置过小的触摸目标（影响操作）

---

**维护者：** UI/UX团队  
**最后更新：** 2026-06-11  
**配套文档：** [UI/UX设计规范](README.md)
