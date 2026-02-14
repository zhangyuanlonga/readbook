# 多端自适应（Responsive/Adaptive）推进计划

目标：在 Android / iOS（主流手机尺寸 + 刘海/手势条）以及桌面端（macOS/Windows 可变窗口）下，保证 UI 不溢出、不遮挡、信息密度合适、交互可达。

说明：这里的“自适应”分两类：

- Responsive（响应式）：同一套布局随宽高变化调整（例如网格列数、Padding、字体层级）。
- Adaptive（适配式）：不同平台/尺寸使用不同组件形态（例如手机 BottomSheet，平板/桌面用 SideSheet/对话框）。

## 设计与工程原则（先立规矩，后补洞）

- 禁用“硬编码尺寸”作为主布局手段：尽量用 `Expanded/Flexible/Spacer` + `LayoutBuilder` + `constraints`。
- 触控最小尺寸：交互点尽量 >= 48x48（Material 建议）。
- 文字不依赖固定高度：避免 `SizedBox(height: xx)` 包住 `Text` 导致溢出；必要时用 `maxLines + overflow`。
- SafeArea 优先：顶部刘海、底部手势条、键盘弹出都要“自动避让”。
- 图片固定比例：封面类统一 `AspectRatio`，避免随尺寸拉伸导致卡片高度爆炸。
- 信息密度随宽度变化：小屏减少次要信息，大屏增加信息与并排布局。
- 全局排版 token 化：Spacing/圆角/卡片边距集中管理，避免每个页面各写一套。

## 断点（Breakpoints）建议（MD3 思路）

建议采用 3 段宽度断点（也可后续迭代）：

- compact：< 600（绝大多数手机竖屏）
- medium：600 - 840（大屏手机横屏 / 小平板竖屏）
- expanded：>= 840（平板横屏 / 桌面窗口）

工程上建议使用 `MediaQuery.sizeOf(context).width` 或 `LayoutBuilder` 的 `constraints.maxWidth` 判断。

## P0（必须做：防溢出/不遮挡/不崩）

- [ ] RA01：建立“自适应验收清单”与最小测试矩阵
  - 手机小屏：iPhone SE / Android 360x640
  - 主流手机：iPhone 14/15 / Android 412x915
  - 大屏：iPhone Pro Max / Android 480+
  - 平板：iPad 768x1024 / Android Tablet
  - 桌面：macOS/Windows 可变窗口（宽 800~1400，高 600~1000）

- [ ] RA02：为全局 Padding/间距建立统一 token（避免页面各自发散）
  - 例如：页面边距、卡片内边距、列表间距、分区间距

- [ ] RA03：逐页排查并修复 RenderFlex overflow / 点击区域过小
  - 重点：书架网格、搜索结果卡、详情页信息区、阅读页底部浮层/目录弹层
  - 验收：在 compact 下不溢出；在 textScaleFactor=1.3 下仍可用

- [ ] RA04：为“列表/网格”建立响应式列数与卡片密度策略
  - 书架：compact=2 列、medium=3 列、expanded=4~6 列（随窗口调整）
  - 书源列表：compact 单列；expanded 可双列（右侧显示更多信息/操作）

- [ ] RA05：统一 SafeArea/键盘避让策略
  - BottomSheet/弹层：使用 `SafeArea` + `Padding(viewInsets)`，避免键盘盖住输入框
  - 阅读页：常驻章节栏/底部浮层与正文可视区严格分离（不遮字）

## P1（收益大：平板/桌面体验明显提升）

- [ ] RA06：引入“自适应布局骨架”
  - compact：底部导航（书架/我的）+ 全屏页面
  - expanded：左侧 NavigationRail / Sidebar，右侧内容区（可并排：书架列表 + 详情）

- [ ] RA07：详情页在 expanded 下做“双栏”
  - 左：封面+基本信息+操作
  - 右：简介/最新章节/目录（目录可独立滚动）

- [ ] RA08：弹层形态自适应
  - compact：`showModalBottomSheet`
  - expanded：`showDialog` / SideSheet（避免桌面端底部弹层太“手机化”）

- [ ] RA09：输入体验优化
  - 搜索框、书源粘贴导入：桌面支持快捷键/回车提交；移动端键盘完成键提交

## P2（可选：质量门禁与长期维护）

- [ ] RA10：关键页面 Golden 测试（至少 3 个断点）
  - 书架页（列表/网格）、搜索页（结果/异常）、详情页、阅读页（工具栏/目录）

- [ ] RA11：无障碍与字体缩放适配
  - 最小：不因系统字体放大导致关键按钮不可用/被遮挡

- [ ] RA12：性能与重绘治理
  - 大屏显示更多内容时，列表滚动仍保持流畅；必要时加 `RepaintBoundary` 或减少阴影层级

## 执行顺序建议（不做没必要的优化）

1. 先做 RA01/RA03/RA05：它们直接解决“错乱/遮挡/溢出”的可用性问题。
2. 再做 RA04：让书架/列表在不同尺寸下“看着合理”。
3. 如果你确定要兼容平板/桌面用户，再做 RA06~RA09。
4. Golden/无障碍/性能（RA10~RA12）作为发布前质量门禁。
