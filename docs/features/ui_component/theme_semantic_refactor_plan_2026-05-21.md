# 主题语义化改造计划

更新时间：2026-05-21

状态：待评审

用途：

- 把当前主题系统从“内部实现字段集合”升级为“颜色语义 + 组件语义 + 资源语义”的统一框架
- 为外观页、高级主题编辑页、运行时 `ThemeData` 应用链路提供统一改造计划
- 作为后续执行与勾选维护的唯一台账

关联代码：

- [lib/app/theme/app_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme.dart)
- [lib/app/theme/app_theme_palette.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme_palette.dart)
- [lib/app/theme/app_advanced_theme_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_advanced_theme_tokens.dart)
- [lib/domain/entities/app_advanced_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/app_advanced_theme.dart)
- [lib/features/mine/presentation/appearance_page_view.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page_view.dart)
- [lib/features/mine/presentation/advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart)

---

## 0. 维护规则

- 本文档中的任务项全部使用 Markdown 勾选框维护。
- 任务开始前保持 `[ ]`，完成并自测通过后改为 `[x]`。
- 每个阶段完成后，补充“执行记录”。
- 如果范围调整，优先修改本文件再继续开发，不允许口头变更后不回写。

---

## 1. 结论先行

当前主题系统的真实状态：

1. 颜色线已经具备较完整的底层能力。
2. 颜色配置对用户暴露的表达仍偏 token / 实现语言，没有完全按用户感知区域组织。
3. 组件线并非不存在，但主要停留在默认实现和页面局部硬编码中，还没有进入主题系统。
4. 下一阶段不建议推翻现有颜色字段，而应新增“语义映射层”和“组件 token 层”。

建议改造方向：

1. 先做颜色语义化。
2. 再做组件语义化。
3. 最后再把组件语义正式接入 `AdvancedTheme` 持久化和编辑器。

---

## 2. 改造目标

### 2.1 总体目标

- 用户在主题编辑页看到的是“页面背景、弹窗背景、卡片背景、主要文字、按钮形状”这类可理解配置项。
- 运行时仍保留当前 `ColorScheme + AdvancedTheme` 的底层能力，不做推翻式重构。
- 页面视觉从“散落的局部样式”收敛到“主题 token 驱动”。

### 2.2 非目标

- 本轮不重做 Material 3 基础配色算法。
- 本轮不引入系统动态配色（Material You）。
- 本轮不重构阅读器所有独立配色逻辑，只收口与应用主题共用的语义。

---

## 3. 当前问题

### 3.1 颜色线问题

| 问题 | 当前表现 | 影响 |
| --- | --- | --- |
| 暴露实现语言 | 编辑器内部字段更接近 `surface`、`cardColor`、`searchFieldBackgroundColor` | 用户难理解“改这个会影响哪里” |
| 用户语义不完整 | 缺少“弹窗背景”这类直观项 | 主题配置和页面感知不一致 |
| 同一语义分散到多个 token | “次级背景”可能落在 `surfaceColor`、`searchFieldBackgroundColor`、`elevatedSurfaceColor` | UI 文案和实际生效难统一 |

### 3.2 组件线问题

| 问题 | 当前表现 | 影响 |
| --- | --- | --- |
| 组件风格未主题化 | 卡片圆角、按钮形状、输入框圆角、弹层圆角大量写死 | 无法通过主题统一风格 |
| 样式分散在页面 | 多处 `BorderRadius.circular(...)`、局部阴影、局部 shape | 后续主题扩展成本高 |
| 高级主题偏颜色和资源 | 壁纸、字体、图集能力强，但组件风格弱 | 主题差异主要来自颜色，风格不够完整 |

---

## 4. 目标框架

```text
主题系统
├── 颜色语义
│   ├── 强调色
│   ├── 页面背景
│   ├── 弹窗背景
│   ├── 次级背景
│   ├── 主要文字
│   ├── 辅助文字
│   └── 边框
├── 组件语义
│   ├── 卡片
│   ├── 按钮
│   ├── 输入框 / 搜索框
│   ├── 选项卡 / 分段切换
│   ├── 开关 / 标签
│   ├── 弹窗 / 底部弹层
│   └── 导航栏
└── 资源语义
    ├── 页面背景图
    ├── 阅读页背景图
    ├── 封面图集
    ├── 启动图
    ├── 底栏图标
    ├── 界面字体
    └── 阅读字体
```

---

## 5. 用户侧页面应该显示的内容

### 5.1 外观设置页

建议分区：

1. 模式
2. 主题色
3. 高级主题
4. 主题说明

建议显示内容：

| 分区 | 页面显示 | 说明 |
| --- | --- | --- |
| 模式 | 浅色 / 深色 / 跟随系统 | 控制全局明暗 |
| 主题色 | 预置色板 + 当前选中色 | 控制基础 `ColorScheme` |
| 高级主题 | 当前启用主题、进入管理 | 表示是否有覆盖 |
| 主题说明 | 一行优先级说明 | 降低用户困惑 |

建议说明文案：

- `高级主题会覆盖页面背景、卡片、文字和部分组件样式`
- `阅读器自定义背景优先于主题背景`
- `主题色作为基础色板，高级主题可进一步覆盖`

### 5.2 高级主题编辑页

建议分区：

1. 基础信息
2. 颜色卡片
3. 卡片组件
4. 按钮组件
5. 输入框 / 搜索框组件
6. 选项与切换组件
7. 弹层与导航组件
8. 资源
9. 实时预览

---

## 6. 颜色卡片设计

### 6.1 颜色卡片只保留的字段

| 用户语义 | 当前可映射字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 强调色 | `primaryColorValue` | 主按钮、主链接、选中态 | 决定品牌感 |
| 页面背景 | `backgroundColorValue` | 页面底色、壳层背景 | 决定整体氛围 |
| 弹窗背景 | `surfaceColorValue` | Dialog、BottomSheet、菜单、局部浮层 | 决定分层感 |
| 次级背景 | `surfaceColorValue` 的次级用途映射 | 分组容器、轻表面、弹层内次级区 | 决定细节层次 |
| 主要文字 | `textPrimaryColorValue` | 标题、正文、主标签 | 决定可读性 |
| 辅助文字 | `textSecondaryColorValue` | 描述、说明、未选中项 | 决定信息主次 |
| 边框 | `outlineColorValue` | 通用边框、输入框边框、分隔线 | 决定轮廓清晰度 |

说明：

- 颜色卡片只放“全局、跨组件共享”的颜色语义。
- `卡片背景`、`卡片边框`、`卡片文字` 不再放在颜色卡片中，统一归到“卡片组件”卡片。
- `搜索框背景`、`输入框边框风格` 不再放在颜色卡片中，统一归到“输入框 / 搜索框组件”卡片。
- `提示色`、`提示背景` 建议归到“标签 / 提示 / 选项类组件”或保留在具体组件卡片中，不再单独占据全局颜色卡片。

### 6.2 用户侧显示顺序

建议颜色卡片内 UI 顺序固定为：

1. 强调色
2. 页面背景
2. 弹窗背景
3. 次级背景
4. 主要文字
5. 辅助文字
6. 边框

### 6.3 颜色卡片说明文案

| 字段 | 建议提示文案 |
| --- | --- |
| 强调色 | `影响主按钮、选中态和核心高亮颜色` |
| 页面背景 | `影响页面主背景和整体底色` |
| 弹窗背景 | `影响弹窗、菜单、底部浮层等悬浮内容背景` |
| 次级背景 | `影响分组容器、轻表面和部分次级区域背景` |
| 主要文字 | `影响标题、正文和主要操作说明` |
| 辅助文字 | `影响描述、提示和未选中内容文字` |
| 边框 | `影响通用边框、输入框边框和分隔线` |

### 6.4 不放入颜色卡片、转交组件卡片的字段

| 字段语义 | 当前字段 | 建议归属 |
| --- | --- | --- |
| 卡片背景 | `cardColorValue` | 卡片组件 |
| 卡片文字 | `cardTextColorValue` | 卡片组件 |
| 卡片边框 | `cardBorderColorValue` | 卡片组件 |
| 搜索框背景 | `searchFieldBackgroundColorValue` | 输入框 / 搜索框组件 |
| 抬升表面 | `elevatedSurfaceColorValue` | 弹层或次级组件容器 |
| 次强调色 | `secondaryColorValue` | 按钮组件或标签 / 选项类组件 |
| 提示强调色 | `noticeAccentColorValue` | 标签 / 提示 / 选项类组件 |
| 提示背景 | `noticeSurfaceColorValue` | 标签 / 提示 / 选项类组件 |
| 图标背景 | `iconBackgroundColorValue` | 卡片组件或导航组件 |
| 阴影色 | `shadowColorValue` | 组件风格内部实现，不直接暴露为颜色卡片项 |

---

## 7. 组件语义设计

### 7.1 建议主题化的组件族

| 组件族 | 说明 | 优先级 |
| --- | --- | --- |
| 卡片 | 项目中最常见，最值得统一 | P0 |
| 搜索框 / 输入框 | 各页面反复出现 | P0 |
| 按钮 | 全局感知最明显 | P0 |
| 弹窗 / BottomSheet | 分层感强，差异明显 | P0 |
| 底栏 / 导航栏 | 壳层风格统一关键 | P1 |
| 选项卡 / 分段切换 | 高频切换组件 | P1 |
| 开关 / 标签 | 设置页和筛选页高频 | P1 |
| 场景卡片 | 书架卡、搜索结果卡、统计卡 | P2 |

### 7.2 组件卡片建议展示结构

#### 7.2.1 卡片组件

| 用户字段 | 建议字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 卡片背景 | `cardColorValue` | 书架卡、搜索卡、设置卡、信息卡 | 决定内容块聚焦感 |
| 卡片文字 | `cardTextColorValue` | 卡片内部文字 | 决定卡片内容可读性 |
| 卡片边框 | `cardBorderColorValue` | 卡片边框 | 决定轮廓感 |
| 卡片圆角 | `cardRadius` | 所有业务卡片 | 利落或柔和 |
| 卡片阴影 | `cardElevationLevel` | 所有业务卡片 | 扁平或立体 |

#### 7.2.2 按钮组件

| 用户字段 | 建议字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 按钮形状 | `buttonShapeStyle` | Filled、Outlined、Tonal 按钮 | 工具化或内容化 |
| 按钮圆角 | `buttonRadius` | 所有主要按钮 | 风格统一 |
| 按钮高度 | `buttonHeight` | 所有主要按钮 | 紧凑或宽松 |
| 次强调色 | `secondaryColorValue` | 次级按钮、辅助强调区 | 丰富层次 |

#### 7.2.3 输入框 / 搜索框组件

| 用户字段 | 建议字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 搜索框背景 | `searchFieldBackgroundColorValue` | 搜索框、筛选条、输入区 | 轻量或明确 |
| 输入框圆角 | `inputRadius` | 搜索框、输入框、筛选框 | 统一风格 |
| 输入框边框风格 | `inputBorderStyle` | 输入类组件 | 清晰度变化 |

#### 7.2.4 选项与切换组件

| 用户字段 | 建议字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 选项卡样式 | `tabStyle` | Tab、Segment、切换器 | 导航感强弱变化 |
| 开关样式 | `switchTrackStyle`、`switchThumbStyle` | Switch | 设置页统一性增强 |
| 提示强调色 | `noticeAccentColorValue` | 标签、徽标、状态提示 | 强化反馈信息 |
| 提示背景 | `noticeSurfaceColorValue` | 标签、提醒块、提示容器 | 完整成块 |

#### 7.2.5 弹层与导航组件

| 用户字段 | 建议字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 抬升表面 | `elevatedSurfaceColorValue` | 弹层内部高一层容器 | 分层更清楚 |
| 弹层圆角 | `sheetRadius` | Dialog、BottomSheet、菜单 | 更柔和或更利落 |
| 弹层阴影 | `sheetElevationLevel` | Dialog、BottomSheet、菜单 | 悬浮感变化 |
| 图标背景 | `iconBackgroundColorValue` | 导航入口、图标胶囊底色 | 导航一致性增强 |

### 7.3 组件共用 token

| 组件语义 | 建议字段 | 影响范围 | 视觉效果 |
| --- | --- | --- | --- |
| 全局圆角 | `cornerRadiusSm/Md/Lg/Pill` | 卡片、输入框、弹窗、标签、按钮 | 决定整体是利落还是柔和 |
| 通用阴影 | `shadowColorValue`、`elevationLevel` | 卡片、弹层、浮层 | 决定层次深浅 |

---

## 8. 资源语义设计

| 资源项 | 当前能力 | 说明 |
| --- | --- | --- |
| 页面背景图 | 已有 | 页面整体氛围增强 |
| 阅读页背景图 | 已有 | 阅读沉浸感增强 |
| 封面图集 | 已有 | 无真实封面时统一视觉 |
| 启动图 | 已有 | 启动阶段品牌感统一 |
| 底栏图标 | 已有 | 导航图标风格统一 |
| 界面字体 | 已有 | 改变应用整体气质 |
| 阅读字体 | 已有 | 改变正文阅读体验 |

---

## 9. 预览设计

高级主题编辑页建议新增以下预览模块：

| 预览模块 | 预览内容 | 主要验证 |
| --- | --- | --- |
| 页面预览 | 顶栏 + 页面背景 + 两张卡片 | 页面背景、卡片背景、主次文字 |
| 搜索预览 | 搜索框 + 标签 + 输入框 | 次级背景、输入框风格 |
| 按钮预览 | 主按钮、次按钮、文本按钮 | 强调色、按钮形状 |
| 弹窗预览 | 小 Dialog + BottomSheet 片段 | 弹窗背景、圆角、阴影 |
| 切换预览 | Tab、Segment、Switch | 选项类组件风格 |
| 阅读器预览 | 阅读背景、标题、正文、工具条 | 阅读氛围和文字对比 |

---

## 10. 分阶段执行计划

## 10.1 Phase A：共识与范围冻结

目标：

- 冻结颜色语义、组件语义、资源语义三层框架
- 明确第一批要做的高频组件族

任务：

- [x] 确认本文档作为主题改造唯一台账
- [x] 确认颜色卡片首版固定为 7 项：强调色、页面背景、弹窗背景、次级背景、主要文字、辅助文字、边框
- [x] 确认组件语义首批范围：卡片、按钮、输入框、弹层、导航栏、选项卡、开关
- [x] 确认本轮不纳入 Material You 动态配色
- [x] 确认本轮不重构阅读器独立主题体系

完成标准：

- 团队对“先颜色语义化，再组件语义化”的顺序达成一致

执行记录：

- 2026-05-21：已冻结“颜色语义 + 组件语义 + 资源语义”三层框架，本文档作为唯一台账。
- 2026-05-21：已确认颜色卡片首版仅保留 7 项全局语义颜色，其余颜色字段下沉到对应组件卡片。
- 2026-05-21：已确认先做颜色语义化 UI，再推进组件 token 收口与接入。

## 10.2 Phase B：颜色语义化 UI 改造

目标：

- 用户看到的是“页面背景 / 弹窗背景 / 卡片背景”而不是内部 token 名

任务：

- [x] 梳理 `AdvancedThemeEditorPage` 当前颜色字段与 UI 文案映射
- [x] 新增用户语义层字段分组和排序
- [x] 隐藏或下沉 `surface` 等实现术语，不直接暴露给用户
- [x] 新增每个颜色项的“影响范围”说明文案
- [x] 新增颜色分组预览区
- [x] 校验浅色 / 深色页签下颜色说明一致

完成标准：

- 高级主题编辑页颜色分区全部按用户语义展示

执行记录：

- 2026-05-21：`AdvancedThemeEditorPage` 已从“基础主题层 + 高级微调”重组为“颜色卡片 + 各组件卡片 + 强度层”。
- 2026-05-21：颜色卡片已固定为 7 项：强调色、页面背景、弹窗背景、次级背景、主要文字、辅助文字、边框。
- 2026-05-21：卡片背景、卡片文字、卡片边框、搜索框背景、提示强调、提示底色等字段已从全局颜色区下沉到对应组件卡片。
- 2026-05-21：编辑页已新增共享语义色块预览区，直接展示当前浅色 / 深色页签下 7 个全局语义颜色的实际效果。
- 2026-05-21：浅色 / 深色模式说明文案已收口到 `theme_semantic_spec.dart`，不再在页面中各自维护两套描述。

## 10.3 Phase C：颜色映射与作用域补齐

目标：

- 用户改一个颜色项时，受影响区域和说明文案保持一致

任务：

- [x] 确认“弹窗背景”映射范围：Dialog、BottomSheet、菜单、局部浮层
- [x] 确认“次级背景”映射范围：筛选条、次级容器，并作为搜索框组件底色的默认回退参考
- [x] 为颜色语义补统一映射层，不直接在页面中重复拼接
- [x] 补齐外观页和编辑页摘要色块展示
- [x] 校验书架、搜索、Mine、首页、反馈页的实际作用范围

完成标准：

- 配置项名称、说明文案和实际生效范围一致

执行记录：

- 2026-05-21：已新增 `theme_semantic_spec.dart` 作为统一语义映射层，集中维护字段分组、说明文案、作用域标签和摘要色块定义，编辑页与外观页共用。
- 2026-05-21：`AppTheme` 已把“弹窗背景”接入 `DialogTheme`、`BottomSheetTheme`、`PopupMenuTheme`，`AdaptiveActionSurface` 桌面弹层容器也已改为读取同一主题背景。
- 2026-05-21：`外观` 页已新增浅色 / 深色两组语义摘要色块，`高级主题编辑页` 已新增当前模式语义预览区。
- 2026-05-21：已确认“次级背景”首版用于筛选条、分组容器和轻表面；搜索框 / 输入区继续由“搜索框背景”组件项承接，未配置时由当前语义色自动回退。
- 2026-05-21：已通过页面颜色使用点与运行时主题接线校验书架、搜索、Mine、首页、反馈页的作用范围，其中搜索框走 `searchFieldBackgroundColor`，筛选条 / 次级容器走 `elevatedSurfaceColor`，弹层统一走 `surfaceColor`。

## 10.4 Phase D：组件盘点与 token 收口

目标：

- 先不开放给用户，先把高频组件样式从页面硬编码中抽出来

任务：

- [x] 盘点卡片族：`Card`、`AdaptiveCard`、业务卡片
- [x] 盘点输入族：搜索框、输入框、筛选框
- [x] 盘点按钮族：Filled、Outlined、Tonal、Text
- [x] 盘点弹层族：Dialog、BottomSheet、任务弹层、资源选择器
- [x] 盘点选择族：Tab、Segment、Chip、Switch
- [x] 统计页面内散落的 `BorderRadius.circular(...)`、`shape:`、局部阴影
- [x] 提炼第一版组件 token 集合

完成标准：

- 形成一份“组件族 -> token -> 影响范围”的统一清单

执行记录：

- 2026-05-21：完成第一轮组件盘点，代码检索计数如下：`Card(` 40 处、`AdaptiveCard` 3 处、输入相关（`TextField` / `TextFormField` / `AdaptiveSearchBar`）47 处、按钮相关（`FilledButton` / `OutlinedButton` / `TextButton`）207 处、弹层相关（`showAdaptiveActionSurface` / `showModalBottomSheet` / `showDialog` / `PopupMenuButton`）85 处、选择组件（`TabBar` / `SegmentedButton` / `Chip` / `Switch`）134 处。
- 2026-05-21：完成硬编码样式扫描：`BorderRadius.circular(...)` 438 处、`shape:` 65 处、`BoxShadow(...)` 22 处；高密页面主要集中在高级主题编辑页、阅读目录/记录页、书架页、Mine 外观相关页。
- 2026-05-21：已提炼第一版组件 token 集合并落地文件 [app_component_theme_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_component_theme_tokens.dart)，包含 6 组：`card`、`button`、`input`、`overlay`、`navigation`、`selection`。
- 2026-05-21：第一版 token 与影响范围清单：`card`(圆角/边框宽度/阴影)、`button`(形状/圆角/高度/描边)、`input`(圆角/边框宽度/聚焦描边)、`overlay`(弹层圆角/边框/阴影)、`navigation`(标准底栏与 Dock 高度/圆角/边框/阴影/模糊)、`selection`(Tab/Segment/Chip/Switch 样式参数)。

## 10.5 Phase E：组件语义化接入运行时 Theme

目标：

- 让组件风格由 token 驱动，而不是页面局部写死

任务：

- [x] 为卡片引入统一圆角、边框、阴影 token
- [x] 为按钮引入统一形状、圆角、高度 token
- [x] 为输入框引入统一圆角和边框 token
- [x] 为弹窗 / BottomSheet 引入统一圆角和阴影 token
- [x] 为导航栏引入统一容器和边框风格 token
- [x] 为 Tab / Segment / Switch 引入统一样式 token
- [x] 将全局 `ThemeData` 与局部高频组件接入 token

完成标准：

- 第一批高频组件不再依赖散落硬编码样式

执行记录：

- 2026-05-21：`AppTheme` 已接入组件 token：`CardTheme`、`Filled/Outlined/TextButtonTheme`、`InputDecorationTheme`、`DialogTheme`、`BottomSheetTheme`、`PopupMenuTheme`、`NavigationBarTheme`、`TabBarTheme`、`SegmentedButtonTheme`、`ChipTheme`、`SwitchTheme`。
- 2026-05-21：局部高频组件已接入 token：标准底栏容器（`ShellScaffold`）、`CupertinoDockNavigationBar`（容器/搜索按钮/项圆角与阴影）、`AdaptiveFilterBar`（Chip 圆角与描边）、`AdaptiveDialogSurface`（弹层圆角与描边）。
- 2026-05-21：`ThemeData` 与局部组件已实现同一 token 源读取，底层通过 `ThemeExtension<AppComponentThemeTokens>` 提供，避免相同样式参数在页面散落重复定义。

## 10.6 Phase F：AdvancedTheme 模型扩展

目标：

- 让高级主题正式持有组件语义配置

任务：

- [x] 扩展 `AppAdvancedTheme` / `AppAdvancedThemeModeConfig` 的组件字段
- [x] 设计兼容默认值和旧主题回退逻辑
- [x] 更新持久化读写与导入导出结构
- [x] 更新主题摘要结构和预览结构
- [x] 补 migration / backward compatibility 测试

完成标准：

- 新旧主题都能正常读取，旧主题不丢失表现

执行记录：

- 2026-05-21：`AppAdvancedThemeModeConfig` 已持有 `componentStyle`，并覆盖 `globalRadiusScale`、`shadowStrength`、`cardStyle`、`buttonStyle`、`inputStyle`、`overlayStyle`、`navigationStyle`、`switchStyle`。
- 2026-05-21：组件风格字段已纳入主题持久化结构（`toJson` / `fromJson`）并通过默认值回退兼容旧主题（无 `componentStyle` 时自动回退默认风格）。
- 2026-05-21：主题摘要结构 `AdvancedThemeModeSummary` 已补齐 `componentStyle`，列表预览与编辑预览共用该结构透传组件风格。
- 2026-05-21：新增兼容测试覆盖旧结构回退与新字段读写：`test/domain/entities/app_advanced_theme_reader_wallpaper_test.dart`、`test/features/mine/application/advanced_theme_summary_test.dart`。

## 10.7 Phase G：高级主题编辑页补齐组件区和预览区

目标：

- 用户能直接配置组件风格，并实时看到效果

任务：

- [x] 新增“组件风格”分区
- [x] 新增“全局圆角”“卡片风格”“按钮风格”“输入框风格”“弹层风格”“导航栏风格”“切换风格”配置项
- [x] 新增实时预览模块：页面、搜索、按钮、弹窗、切换、阅读器
- [x] 校验浅色 / 深色模式下预览一致
- [x] 校验长文案和大字号下编辑页不溢出

完成标准：

- 编辑页能完整表达“颜色 + 组件 + 资源”三条线

执行记录：

- 2026-05-21：高级主题编辑页已落地“组件风格”分区，并支持 7 项组件风格配置（含全局圆角与阴影强度）。
- 2026-05-21：编辑页预览区已补齐 6 个实时模块标签与示例：页面、搜索、按钮、弹窗、切换、阅读器。
- 2026-05-21：组件风格按浅/深共享同一份 `componentStyle` 同步写入，保证两模式结构一致。
- 2026-05-21：新增大字号 smoke 场景（`textScaler=1.6`）验证编辑页关键模块可见且无溢出异常。

## 10.8 Phase H：验证、回归与发布

目标：

- 确保主题改造不破坏现有主题和页面视觉

任务：

- [x] 补颜色映射层单元测试
- [x] 补组件 token 应用测试
- [x] 补高级主题编辑页 smoke test
- [x] 补典型页面截图或人工回归清单
- [x] 回归页面：首页、书架、搜索、Mine、反馈、阅读器设置页、高级主题页
- [x] 更新相关设计/治理文档引用

完成标准：

- 主题改造可稳定上线，旧主题不回退、不损坏

执行记录：

- 2026-05-21：新增颜色映射层测试 `test/features/mine/application/theme_semantic_spec_test.dart`，覆盖字段顺序、作用域文案、语义色映射。
- 2026-05-21：新增组件 token 应用测试 `test/app/theme/app_component_theme_tokens_test.dart`，覆盖默认 token 与组件风格映射。
- 2026-05-21：扩展高级主题编辑页 smoke 测试 `test/features/mine/presentation/advanced_theme_pages_smoke_test.dart`，覆盖组件区、预览模块与大字号场景。
- 2026-05-21：人工回归清单（首页、书架、搜索、Mine、反馈、阅读器设置页、高级主题页）已按本轮语义映射与组件 token 接线点逐项复核，无阻塞问题。
- 2026-05-21：本计划文档已同步回写 F/G/H 阶段完成状态，作为最新治理引用。

---

## 11. 首版建议优先级

| 优先级 | 内容 | 原因 |
| --- | --- | --- |
| P0 | 颜色语义化 UI | 低风险，收益立刻可见 |
| P0 | 组件族盘点和 token 收口 | 为后续主题化打基础 |
| P1 | 卡片 / 按钮 / 输入框 / 弹层主题化 | 高频组件，影响面最广 |
| P1 | 高级主题模型扩展 | 正式接入组件语义 |
| P2 | 导航栏 / Tab / Switch / Chip | 第二批统一 |
| P2 | 更多业务场景卡片 | 放在基础组件稳定后做 |

---

## 12. 当前阶段建议

当前最推荐的执行顺序：

1. 先完成 `Phase A`
2. 再推进 `Phase B + Phase C`
3. 然后执行 `Phase D + Phase E`
4. 在组件 token 稳定后推进 `Phase F + Phase G`

原因：

- 先改颜色语义 UI，不会打断现有底层实现
- 先盘点组件并收 token，能避免后续把错误的局部样式固化进高级主题
- 最后再开放组件项给用户，成本最低

---

## 13. 待确认问题

- [x] “弹窗背景”首版映射到 Dialog / BottomSheet / 菜单 / 局部操作面板，统一承接悬浮层背景
- [x] “次级背景”首版保留一个用户项，用于筛选条 / 分组容器 / 轻表面；输入区背景继续由“搜索框背景”组件项单独控制
- [x] 首版组件线已包含 Switch / Tab，并同步覆盖 Segment / Chip 样式 token
- [x] 组件 token 首版按全局共享（跨浅色/深色结构一致，颜色层由既有 light/dark 主题分支承接）
- [x] 高级主题首版是否开放阴影强度，还是先只开放圆角和形状
