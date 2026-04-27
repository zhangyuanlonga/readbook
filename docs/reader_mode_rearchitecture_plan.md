# Reader 模式重构改造方案

更新时间：2026-04-27  
适用范围：阅读器模式模型、设置模型、正文布局、分页动画、设置界面与兼容迁移。

---

## 0. 目标

把当前阅读器从“按小说/漫画/滚动/分页硬拆多套逻辑”收口成：

- **统一阅读器壳**
- **统一正文布局模型**
- **统一分页动画模型**
- **内容能力分支**

并且全过程遵守 [development_architecture_guardrails.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/development_architecture_guardrails.md)：

- `presentation` 只负责渲染、交互分发、订阅状态
- 模式判定、布局能力、动画选择、内容能力统一进入 `features/reader/application/`
- 原生只保留平台桥接，如亮度、音量键
- 新模型先接管主链，旧字段仅做迁移输入

---

## 1. 最终判断

### 1.1 当前偏差

当前阅读器偏差主要有 4 个：

- `scroll` 被塞进了“翻页方式”语义，导致布局模式与输入方式混在一起
- 小说/漫画过早分叉，壳层、设置层、交互层大量重复
- `仿真翻页` 只是局部效果，不是统一分页模型下的正式能力
- 设置模型里新旧字段并存，主路径虽然开始切换，但还没完全接管

### 1.2 最终模型结论

不再单独抽“触发方式”层。

原因：

- `scroll` 本质是**布局模式**
- `paged` 默认就应该支持：
  - 点击翻页
  - 手势滑动翻页
- 音量键与自动阅读属于附加能力，不应进入顶层阅读模式模型

最终只保留 3 层模型：

1. 内容类型
- `text`
- `image`

2. 布局模式
- `paged`
- `scroll`

3. 分页动画
只在 `text + paged` 下有效：
- `simulation`
- `cover`
- `slide`
- `fade`
- `none`

补充说明：

- `volumeKeyEnabled` 保留为附加设置项
- `autoReadEnabled` 保留为附加功能项
- 两者都不进入阅读模式抽象

---

## 2. 统一设计原则

### 2.1 阅读器壳统一

小说和漫画共用：

- `ReaderShell`
- `surface metrics`
- 顶部/底部 chrome
- 系统 UI
- overlay 控制
- 章节切换
- 进度保存
- 音量键
- 自动阅读总控

只在正文 body 的能力处分支：

- `text`
- `image`

### 2.2 正文布局统一

正文版式统一由 application 层产出：

- 正文边距
- 章节头布局
- footer/header reserve
- paged / scroll 可视区域

页面不再自己拼这些值。

### 2.3 动画系统统一

`仿真翻页` 属于 `text + paged` 下的正式动画能力，不再作为页面局部特效存在。

---

## 3. 阶段任务

按下面顺序推进，并直接作为项目执行清单使用：

- [x] 阶段 1：阅读模式模型重构
- [x] 阶段 2：统一设置模型
- [x] 阶段 3：统一正文布局
- [ ] 阶段 4：重做分页动画系统
- [x] 阶段 5：设置界面重组
- [x] 阶段 6：兼容清理

---

## 阶段 1：阅读模式模型重构

目标：把 `scroll` 从“翻页方式”语义中剥离，建立统一阅读模式模型。

执行清单：

- [x] 新增 `lib/features/reader/application/reader_mode_model.dart`
- [x] 新增 `lib/features/reader/application/reader_mode_resolver.dart`
- [x] 拆清当前 `ReaderPageTurnMode`、`_currentViewportKind`、`contentMode` 的职责边界
- [x] 明确统一模型中的 `contentKind`
- [x] 明确统一模型中的 `layoutMode`
- [x] 明确统一模型中的 `pageAnimationStyle`
- [x] 让 `paged` 默认支持点击翻页与滑动翻页
- [x] 让 `scroll` 仅表示滚动阅读布局
- [x] 页面层移除“小说分页/漫画连续”等自行拼装判断

阶段完成定义：

- [x] 页面不再自己拼“小说分页/漫画连续”判断
- [x] `ReaderPageTurnMode` 不再承担布局模式职责
- [x] 阶段 1 单测完成：模式推导单测

---

## 阶段 2：统一设置模型

目标：让设置真正按新语义工作，旧字段只做迁移输入。

执行清单：

- [x] 收口 `ReaderSettings` 主字段，只保留文本排版字段
- [x] 收口 `ReaderSettings` 主字段，只保留正文 padding 字段
- [x] 收口 `ReaderSettings` 主字段，只保留章节头字段
- [x] 收口 `ReaderSettings` 主字段，只保留分页动画字段
- [x] 收口 `ReaderSettings` 主字段，只保留漫画能力字段
- [x] 以 `bodyMarginTop/Bottom/Left/Right` 作为主用正文边距字段
- [x] 以 `showChapterHeader` 作为主用章节头开关字段
- [x] 以 `chapterHeaderHorizontalOffset` 作为主用章节头横向偏移字段
- [x] 以 `chapterHeaderVerticalOffset` 作为主用章节头纵向偏移字段
- [x] 以 `pageAnimationStyle` 作为主用分页动画字段
- [x] 将 `bodyMarginMode`、`bodyMarginPreset` 降级为兼容迁移输入
- [x] 将 `chapterHeaderMode`、`chapterHeaderTopSpacing`、`chapterHeaderBottomSpacing` 降级为兼容迁移输入
- [x] 将 `pinnedChapterHeaderOffsetX/Y` 降级为兼容迁移输入
- [x] 调整 `ReaderPreferencesService`，实现“新字段优先、旧字段兜底迁移”
- [x] 同步更新 `settings summary`
- [x] 同步更新 `presenter`
- [x] 同步更新相关测试

阶段完成定义：

- [x] 主设置、主渲染、prefs 主读取只认新字段
- [x] 旧字段只在迁移逻辑中出现
- [x] 阶段 2 单测完成：settings/prefs 迁移单测

---

## 阶段 3：统一正文布局

目标：小说/漫画共用壳层和 `surface metrics`，只在内容能力处分支。

执行清单：

- [x] 统一 `ReaderSurfaceMetrics`
- [x] 统一 `ReaderLayoutResolver`
- [x] 统一 `ReaderShell`
- [x] 统一顶部/底部 chrome
- [x] 让 `text` 与 `image` 共用布局容器
- [x] 让 `text` 与 `image` 共用 safe area 处理
- [x] 让 `text` 与 `image` 共用章节切换链路
- [x] 让 `text` 与 `image` 共用进度保存链路
- [x] 仅在正文 body 的 viewport builder 处分支 `text`
- [x] 仅在正文 body 的 viewport builder 处分支 `image`

建议落点：

- `lib/features/reader/application/reader_layout_resolver.dart`
- `lib/features/reader/application/reader_surface_metrics.dart`
- `lib/features/reader/presentation/reader_viewport_builder.dart`
- `lib/features/reader/presentation/reader_presentation_resolver.dart`

阶段完成定义：

- [x] 壳层不再按小说/漫画复制逻辑
- [x] 正文边距、章节头、页脚信息统一由同一套 `surface metrics` 控制
- [x] 阶段 3 回归完成：surface metrics 与章节头显示回归

---

## 阶段 4：重做分页动画系统

目标：把 `仿真翻页` 变成正式的 `text + paged` 动画能力。

执行清单：

- [x] 统一 `PagedTransitionController`
- [x] 统一 `TextReaderRenderer`
- [x] 让 `simulation` 成为正式动画样式
- [x] 重做 curl/simulation 手势链中的角点逻辑
- [x] 重做 curl/simulation 手势链中的触点纵向因子逻辑
- [x] 重做 curl/simulation 手势链中的折页曲线逻辑
- [x] 重做 curl/simulation 手势链中的前后页阴影逻辑
- [x] 重做 curl/simulation 手势链中的回弹/提交阈值逻辑
- [x] 让 `cover`、`slide`、`fade`、`none` 与 `simulation` 同层管理

建议落点：

- `lib/features/reader/application/paged_transition_controller.dart`
- `lib/features/reader/application/text_reader_renderer.dart`
- `lib/features/reader/presentation/paged_animation/*`

阶段完成定义：

- [x] 动画选择对用户只暴露一个统一分页动画系统
- [x] `仿真` 不再是名字映射，而是正式实现
- [ ] 阶段 4 手测完成：分页动画手测

---

## 阶段 5：设置界面重组

目标：设置界面与新模型完全一致。

执行清单：

- [x] `字体` 分组只保留文本样式能力
- [x] `边距与排版` 分组只保留正文 padding 配置
- [x] `边距与排版` 分组只保留章节头配置
- [x] `边距与排版` 分组只保留排版细节配置
- [x] `信息` 分组只保留 info bar 配置
- [x] `翻页动画` 分组只在 `paged + text` 下展示完整动画项
- [x] 漫画模式设置只展示图片相关项
- [x] 设置项显隐统一交给 capability resolver 控制

阶段完成定义：

- [x] 设置项出现与否由 capability resolver 控制
- [x] 不再出现小说/漫画各自一套半重复设置
- [x] 阶段 5 回归完成：设置项显隐回归

---

## 阶段 6：兼容清理

目标：新字段全面接管后，清掉旧字段主引用。

执行清单：

- [x] 删除旧 summary 对旧字段的主依赖
- [x] 删除旧 presenter 对旧字段的主依赖
- [x] 删除旧 test 对旧字段的主依赖
- [x] 旧字段只保留在 migration adapter
- [x] 补迁移测试
- [x] 补回归测试

阶段完成定义：

- [x] 新字段全面接管
- [x] 旧字段仅用于历史数据导入
- [x] 阶段 6 回归完成：老数据迁移回归

---

## 4. 测试与验证清单

每阶段都要完成最小闭环验证：

- [x] 阶段 1：模式推导单测
- [x] 阶段 2：settings/prefs 迁移单测
- [x] 阶段 3：surface metrics 与章节头显示回归
- [ ] 阶段 4：分页动画手测
- [x] 阶段 5：设置项显隐回归
- [x] 阶段 6：老数据迁移回归

重点手测场景：

- [ ] `text + paged`
- [ ] `text + scroll`
- [ ] `image + paged`
- [ ] `image + scroll`
- [ ] `仿真翻页`
- [ ] 边距与章节头
- [ ] 老设置迁移

---

## 5. 实施要求

- [ ] 后续新增判断不要继续堆进 `reader_page.dart`
- [ ] 模式判定、能力决策、布局决策、动画决策必须优先落到 `features/reader/application/`
- [ ] 页面层只消费结果，不再自己拼模式、能力、布局与动画决策
