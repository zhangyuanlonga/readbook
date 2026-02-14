# 手机端（Android/iOS）自适应：稳定保守方案

目标：只保证 Android / iOS 手机端在不同尺寸、刘海/手势条、系统字体缩放下稳定可用；不做平板/桌面专用布局（macOS/Windows 允许窗口拉伸，自然容错）。

本方案关键词：少断点、少分支、靠约束与滚动兜底、统一 spacing token、优先避免溢出/遮挡。

## 1. 适配范围（只管手机）

- 只针对“竖屏手机”为主（主流阅读场景）。
- 横屏：不做重排，只保证不溢出（可滚动/自动换行）。
- 不做 NavigationRail / 双栏等平板布局。

## 2. 最小测试矩阵（3 机型 + 2 字体档）

建议每次 UI 相关改动都至少手工验证一遍：

- 小屏：Android 360x640（或 iPhone SE 2/3）
- 主流：Android 411x891（或 iPhone 14/15）
- 大屏：Android 480x960（或 iPhone Pro Max 430x932）

字体缩放：

- textScale=1.0（默认）
- textScale=1.3（大字模式）

验收底线：

- 无 RenderFlex overflow
- 关键按钮可点（最小触控区接近 48x48）
- 文字不被 SafeArea/手势条/键盘遮挡

## 3. 统一的“手机断点”策略（保守：两档就够）

不引入复杂 MD3 三段断点，手机端只保留两档：

- phoneSmall：width < 360
- phoneNormal：width >= 360

只在 spacing/密度上做差异，不改结构。

推荐规则：

- 页面横向 padding：
  - phoneSmall：12
  - phoneNormal：16
- 卡片内 padding：
  - phoneSmall：12
  - phoneNormal：14
- 列表 item 间距：
  - phoneSmall：8
  - phoneNormal：10

说明：

- 这个策略稳定的原因是：只改“留白”，不改布局结构，不容易引入新 bug。

## 4. 核心工程做法（少改就能稳）

### 4.1 布局永远优先用“约束 + 滚动”兜底

- 列表/长内容：优先 `ListView` / `CustomScrollView`，而不是 `Column` 直接堆满。
- 页面主轴：尽量 `Expanded(child: ...)`，避免 `SizedBox(height: xxx)` 包内容。
- 对“可能变高”的区域（简介、错误信息、书名作者）：
  - `maxLines` + `TextOverflow.ellipsis`
  - 或允许换行，但外层必须能滚动

### 4.2 SafeArea 是手机端第一优先级

- 顶部：刘海/状态栏必避让。
- 底部：手势条必避让。
- BottomSheet/弹层输入：必须避让键盘 `viewInsets.bottom`。

通用写法（BottomSheet 里）：

```dart
return SafeArea(
  child: Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ...,
  ),
);
```

### 4.2A MediaQuery（媒体查询）：可行且靠谱，但要用对

MediaQuery 不是过时方案，恰恰是 Flutter 在 2026 年依然最稳定的"设备信息来源"：全面屏、刘海、Dynamic Island、手势条、不同系统字体缩放，本质都体现在 MediaQuery 的 size/padding/viewInsets/textScaler 里。

我们建议这样融合进当前"保守手机适配"方案：

- 用途边界：
  - 用 `size` 决定 spacing（small/normal）与少量密度调整。
  - 用 `viewPadding/viewInsets` 处理安全区与键盘遮挡。
  - 用 `textScaler`（或 `textScaleFactor`）确保大字模式不溢出。
  - 不用 `devicePixelRatio` 做布局决策（布局只看逻辑像素）。

- 推荐 API（更现代、也更利于测试/可读性）：
  - `MediaQuery.sizeOf(context)`
  - `MediaQuery.viewPaddingOf(context)`（刘海/手势条）
  - `MediaQuery.viewInsetsOf(context)`（键盘）
  - `MediaQuery.textScalerOf(context)`（代替直接读 textScaleFactor）

- 代码使用方式（避免在各处散落 if/else）：
  - 只在"spacing token"层读取一次 MediaQuery，并返回 EdgeInsets/尺寸常量
  - 页面布局依然以 `LayoutBuilder`/`Expanded` 为主，MediaQuery 只负责"环境参数"

示例（建议未来在代码里封装成 AppLayout/AppSpacing）：

```dart
class AppLayout {
  static bool isPhoneSmall(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 360;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final isSmall = isPhoneSmall(context);
    return EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16);
  }

  static double keyboardInset(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom;
  }
}
```

这套用法在 iPhone 新机型（比如更窄/更高、更大 SafeArea）和安卓全面屏上仍然可靠：因为我们不依赖"机型枚举"，只依赖运行时真实的尺寸与安全区。


### 4.3 大屏手机上的“阅读行宽”约束（防止一行太长）

阅读/简介这类长文本，建议加一个 `maxWidth` 上限，让大屏手机不会一行太长导致阅读疲劳。

- 推荐上限：`maxWidth = 520`（手机端足够）

做法：用 `Align + ConstrainedBox` 包裹正文/简介区。

### 4.4 网格（书架）列数：保守固定 2 列

手机端最稳的策略：

- 书架网格永远 2 列
- 不因大屏手机变 3 列（会导致封面/标题变小、信息密度变化引出新问题）

大屏手机的改进只做：

- 卡片缩小 padding
- 封面保持固定 `AspectRatio`

### 4.5 触控区最小尺寸

- IconButton 建议使用 `visualDensity: VisualDensity.compact` 时，外层仍保证 tap area 不小于 40~48。
- 列表的“更多(三点)”建议用 `InkResponse`/`IconButton`，不要用纯 `GestureDetector` + 小图标。

## 5. 页面级别的“保守适配清单”（按你项目核心页面）

### 5.1 书架页

- 网格卡：只显示封面/书名/作者；标题 `maxLines: 2`。
- 列表卡：左封面固定宽度，右侧信息区 `Expanded`，防溢出。

### 5.2 搜索页

- 搜索框区域：保证在 textScale=1.3 不挤压到换行爆布局。
- 结果卡：封面固定比例 + 右侧信息区 `Expanded`，简介 `maxLines: 2~3`。

### 5.3 详情页

- 顶部信息区：封面固定尺寸/比例；书名作者可换行但不溢出。
- 简介：默认折叠（比如 6 行），展开后整体滚动。

### 5.4 阅读页

- 常驻章节栏：必须在 SafeArea 内，不遮挡正文。
- 工具栏/目录弹层：键盘弹出时不遮挡输入框；列表必须可滚动。

### 5.5 书源页

- 列表项尽量“单行/两行”，避免竖向撑太高。
- 操作入口收敛到三点菜单（避免小屏塞不下）。

## 6. 推荐落地方式（少量公共封装，不引入重框架）

建议只做一个很轻的工具类，统一手机 spacing：

- `AppSpacing.pagePadding(context)` -> EdgeInsets
- `AppSpacing.cardPadding(context)`
- `AppLayout.isPhoneSmall(context)`

原则：

- 只提供 spacing/token，不提供复杂布局组件
- 避免把项目变成“响应式框架工程”，后续维护成本低

## 7. 什么时候需要再升级（不在当前保守范围内）

以下情况才考虑引入更复杂断点/平板布局：

- 你确定要覆盖 iPad/Android 平板用户
- 你希望桌面端做双栏（书架+详情并排）

在那之前，本方案足够稳定。
