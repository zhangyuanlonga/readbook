# 阅读器根因修复并行执行计划

更新时间：2026-04-25  
用途：将当前阅读器从“一个超大页面堆叠多套能力”重构为“页面壳层 + 正文展示层 + 分页引擎层 + 设置语义层 + 跳转服务层”的唯一执行计划。  
要求：任务必须可分阶段推进、可打勾、可并行拆解、执行不漂移，不夹带额外功能。

## 1. 最终目标

本轮执行的唯一目标：

- 完整承接 `MD3` 阅读器这块的配置能力
- 解决阅读正文层级过深、职责混乱、分页/滚动/设置互相牵扯的根本问题
- 将当前阅读器改造成便于并行开发和长期维护的清晰架构

这轮不追求：

- 新增阅读器花哨功能
- 同时做视觉大改版
- 在重构过程中顺手加入不相关交互

## 2. 执行原则

所有任务执行必须遵守以下规则：

1. 只做计划内事项，不夹带额外功能。
2. 先拆职责，再调视觉，不允许先靠补参数维持表面效果。
3. 同一阶段内，只有满足“完成标准”后才能打勾。
4. 可并行任务必须明确文件归属，避免多人同时改同一块。
5. 每阶段完成后必须先过分析和测试，再进入下一阶段。

## 3. 架构目标图

目标架构统一收敛为：

- `ReaderShell`
  负责页面壳层、系统 UI、覆盖层、背景亮度层
- `ReaderSurface`
  负责阅读面、正文可用区域、surface metrics
- `TextPagedView`
  负责分页正文展示
- `TextScrollView`
  负责滚动正文展示
- `MangaView`
  负责漫画正文展示
- `PaginationEngine`
  负责断句、分页、分页缓存、分页签名
- `ReaderSettingsGroups + PresetService`
  负责设置语义与 preset
- `ReaderJumpService`
  负责目录、书签、搜索、进度定位统一跳转

## 4. 当前根因定位

当前核心问题不是某一个 bug，而是三类结构性问题：

### 4.1 必须拆

- `lib/features/reader/presentation/reader_page.dart`
  过大，当前承担：
  页面壳层、背景、分页、滚动、漫画、设置、目录、换源、分页预计算、动画状态机

### 4.2 必须统一

- 正文可用区域
  只能由 `ReaderSurfaceMetrics` 决定
- 分页输入
  只能由 `ReaderPaginationSpec` 决定
- 跳转口径
  目录 / 书签 / 搜索 / 进度定位统一走同一跳转服务

### 4.3 必须收口

- 设置入口
  必须从“字段堆叠”收口为“语义分组 + preset + 高级项”
- 页眉页脚语义
  分页模式是页面本体，滚动模式是浮层

## 5. 串行与并行边界

### 5.1 必须串行的阶段

以下阶段必须按顺序推进：

1. 阶段 A：页面模型收口
2. 阶段 B：回归保护补齐
3. 阶段 C：设置模型收口
4. 阶段 D：分页输入收口
5. 阶段 E：体验基线自动化

原因：

- 后续并行拆分必须建立在统一页面模型、统一分页输入和回归保护存在的前提下

### 5.2 可以并行的阶段

从阶段 F 开始，允许并行拆解，但必须按“写入面互不重叠”执行。

并行的前提：

- 阶段 A-E 已完成
- 阶段 F 的接口层已经固定
- 每条并行任务有明确文件归属

## 6. 分阶段任务

### 阶段 A：页面模型收口

- [x] 抽出统一的 `ReaderSurfaceMetrics`
- [x] 滚动和分页统一依赖 `ReaderSurfaceMetrics`
- [x] 顶部/底部 reserve 收口到统一入口
- [x] 背景层只服务阅读 surface

完成标准：

- 正文可用区域只有一个来源
- 不再在多个方法里重复解释顶部/底部留白

### 阶段 B：回归保护补齐

- [x] 文本阅读模式一致性回归
- [x] 排版细节配置回归
- [x] surface/layout 统一口径回归

完成标准：

- 切换分页/滚动不丢逻辑位置
- 关键排版配置有测试保护

### 阶段 C：设置模型收口

- [x] 建立 `ReaderSettingsGroups`
- [x] 建立 `ReaderSettingsPresetService`
- [x] 抽出：正文排版 / 正文版面 / 章节头 / 信息栏 / 视觉装饰
- [x] 建立 preset：字体、间距、章节头、信息样式

完成标准：

- 设置项已具备语义分组模型
- 后续 UI 接线不必直接堆 raw fields

### 阶段 D：分页输入收口

- [x] 建立 `ReaderPaginationSpec`
- [x] 分页和断句只依赖 `ReaderPaginationSpec`
- [x] 分页签名改为基于 `ReaderPaginationSpec`
- [x] 预计算缓存统一依赖 `ReaderPaginationSpec`

完成标准：

- 分页、断句、签名、分页缓存输入一致

### 阶段 E：体验基线自动化

- [x] 分页底部预留基线
- [x] 滚动底部留白基线
- [x] 背景变化不影响正文内容区基线
- [x] 模式切换不丢逻辑位置基线

完成标准：

- 结构性体验回归已有自动化护栏

### 阶段 F：展示层拆分

目标：把 `reader_page.dart` 拆成清晰展示层，不再让页面文件直接承担全部阅读模式。

#### F1 壳层拆分

- [x] 新建 `reader_shell.dart`
- [x] 将页面壳层、系统 UI、overlay、背景亮度层迁入 `ReaderShell`
- [x] `reader_page.dart` 只保留入口组装逻辑

写入归属：

- `lib/features/reader/presentation/reader_shell.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### F2 文本滚动展示拆分

- [x] 新建 `reader_text_scroll_view.dart`
- [x] 迁出 `_buildReaderList / _buildStandardReaderList / _buildContinuousTextReader`
- [x] 迁出滚动正文相关选择、间距、正文 block 展示逻辑

写入归属：

- `lib/features/reader/presentation/reader_text_scroll_view.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### F3 文本分页展示拆分

- [x] 新建 `reader_text_paged_view.dart`
- [x] 迁出 `_buildPagedReader / _buildPagedTransitionStack / _buildPagedPageContainer`
- [x] 迁出分页页内容展示逻辑

写入归属：

- `lib/features/reader/presentation/reader_text_paged_view.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### F4 漫画展示拆分

- [x] 新建 `reader_manga_view.dart`
- [x] 迁出 `_buildMangaReader / _buildMangaContinuousReader / _buildMangaPagedReader`
- [x] 迁出漫画图像卡片和缩放逻辑

写入归属：

- `lib/features/reader/presentation/reader_manga_view.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### F5 信息栏与章节头展示拆分

- [x] 新建 `reader_chrome_widgets.dart`
- [x] 迁出 `_buildPinnedChapterHeader / _buildReaderInfoBar / _buildPageIndexOverlay`
- [x] 明确分页与滚动模式的信息栏职责分离

写入归属：

- `lib/features/reader/presentation/reader_chrome_widgets.dart`
- `lib/features/reader/presentation/reader_page.dart`

阶段 F 完成标准：

- `reader_page.dart` 明显瘦身
- 文本分页、文本滚动、漫画视图各自独立
- 页眉页脚/章节头展示从页面主文件中拆出

### 阶段 G：分页引擎拆分

目标：把分页引擎和展示层彻底分开。

#### G1 分页计算拆分

- [x] 新建 `reader_pagination_engine.dart`
- [x] 迁出 `_ensurePagination / _paginateParagraphSlices / _paginateCurrentChapter`

写入归属：

- `lib/features/reader/application/reader_pagination_engine.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### G2 分页缓存拆分

- [x] 新建 `reader_pagination_cache_service.dart`
- [x] 迁出预计算缓存读写逻辑

写入归属：

- `lib/features/reader/application/reader_pagination_cache_service.dart`
- `lib/features/reader/presentation/reader_page.dart`

阶段 G 完成标准：

- 页面不再直接做分页计算
- 页面不再直接做分页缓存读写

### 阶段 H：设置 UI 收口

目标：让阶段 C 的分组和 preset 真正成为唯一设置入口。

#### H1 设置面板拆分

- [x] 新建 `reader_settings_sheet.dart`
- [x] 迁出 `_showSettingsSheet` 内的大量嵌套构建函数
- [x] 让设置 UI 只读 `ReaderSettingsGroups + PresetService`

写入归属：

- `lib/features/reader/presentation/reader_settings_sheet.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### H2 基础设置收口

- [x] 基础设置只保留：主题、字号、字体、间距、边距、信息样式
- [x] preset 作为基础入口
- [x] 高级项放入二级组

写入归属：

- `lib/features/reader/presentation/reader_settings_sheet.dart`

#### H3 高级设置保留但下沉

- [x] 保留字距、段距、缩进、章节头位置、自定义边距、自定义信息栏 margin/padding
- [x] 这些能力不删，只迁到高级设置组

写入归属：

- `lib/features/reader/presentation/reader_settings_sheet.dart`

阶段 H 完成标准：

- 设置入口不再重复暴露同一能力
- `MD3` 配置能力完整可用
- 设置 UI 不再内嵌在 `reader_page.dart`

### 阶段 I：跳转入口统一

目标：统一目录、书签、搜索、进度定位的跳转口径。

#### I1 Jump 服务建立

- [ ] 新建 `reader_jump_service.dart`
- [ ] 统一目录跳转
- [ ] 统一书签跳转
- [ ] 统一搜索结果跳转
- [ ] 统一进度定位跳转

写入归属：

- `lib/features/reader/application/reader_jump_service.dart`
- `lib/features/reader/presentation/reader_page.dart`

#### I2 进度定位面板补齐

- [ ] 增加主流进度定位面板
- [ ] 章节滑杆 + 当前章内进度 + 快速跳转

写入归属：

- `lib/features/reader/presentation/reader_progress_sheet.dart`
- `lib/features/reader/presentation/reader_page.dart`

阶段 I 完成标准：

- 所有阅读定位动作都走统一入口
- 不再存在各自改 scroll/page 状态的旁路

## 7. 并行执行编排

### 7.1 可并行执行的主干

从阶段 F 开始，推荐按 4 条并行工作线推进：

#### 线程 1：展示层拆分

- F1 壳层拆分
- F5 信息栏与章节头拆分

责任边界：

- `reader_shell.dart`
- `reader_chrome_widgets.dart`
- `reader_page.dart` 中壳层相关调用点

#### 线程 2：正文视图拆分

- F2 文本滚动展示拆分
- F3 文本分页展示拆分

责任边界：

- `reader_text_scroll_view.dart`
- `reader_text_paged_view.dart`
- `reader_page.dart` 中文本正文相关调用点

#### 线程 3：漫画与分页引擎拆分

- F4 漫画展示拆分
- G1 分页计算拆分
- G2 分页缓存拆分

责任边界：

- `reader_manga_view.dart`
- `reader_pagination_engine.dart`
- `reader_pagination_cache_service.dart`

#### 线程 4：设置与跳转收口

- H1 设置面板拆分
- H2 基础设置收口
- H3 高级设置下沉
- I1 跳转入口统一
- I2 进度定位面板

责任边界：

- `reader_settings_sheet.dart`
- `reader_progress_sheet.dart`
- `reader_jump_service.dart`

### 7.2 并行执行前置条件

所有线程开始前，必须满足：

- 阶段 A-E 全部完成
- `ReaderSurfaceMetrics / ReaderPaginationSpec / ReaderSettingsGroups / PresetService` 已稳定
- 所有人遵守各自文件归属，不跨线程抢改

### 7.3 并行结束的合流点

所有并行线程结束后统一进入：

- 阶段 J：总回归与视觉核验

## 8. 阶段 J：总回归与视觉核验

- [ ] `flutter analyze`
- [ ] 阅读器相关测试全绿
- [ ] 分页模式手动验证
- [ ] 滚动模式手动验证
- [ ] 设置项手动验证
- [ ] 目录 / 书签 / 搜索 / 进度定位统一跳转手动验证

完成标准：

- 代码层稳定
- 结构层清晰
- 设置层完整
- 体验层可用

## 9. 执行口径

后续执行只按这份文档推进，不再混用别的阶段口径。

打勾规则：

- 代码完成
- 测试通过
- 完成标准满足

三者同时满足，才能打勾。
