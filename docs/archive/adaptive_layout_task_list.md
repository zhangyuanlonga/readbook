# 全页面自适应开发任务清单

更新时间：2026-04-08  
用途：把当前项目所有主要页面的自适应现状、问题类型、建议改造方式和优先级整理成开发任务清单。  
说明：本清单基于当前代码实现，不是理想化页面清单。

## 1. 任务分级说明

- `P0`
  当前用户最容易感知问题，且改造收益最高
- `P1`
  主页面，当前大屏体验明显还有空间
- `P2`
  常用二级页面，已有基础但需要补齐
- `P3`
  信息页或已相对成熟页面，暂不优先

改造方式说明：

- `重排`
  通过断点和容器宽度改变内容结构、列数、分栏关系
- `缩放`
  保留结构，对尺寸、间距、控件密度做有限比例调整
- `增强`
  在现有基础上做少量结构或密度补强

## 2. 主壳层与全局

### 2.1 主壳层

文件：

- [lib/app/shell_scaffold.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/shell_scaffold.dart)

当前状态：

- `600+` 切 `NavigationRail`
- 手机端底部导航
- 主导航结构级自适应已经具备

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 统一标准导航和苹果风格导航的视觉差异边界
- [ ] 复核 `standard` 和 `cupertinoDock` 两种底部导航在主流宽度上的高度、留白和内容遮挡
- [ ] 复核 `NavigationRail` 下的内容区左右留白是否与页面限宽策略一致

### 2.2 全局断点与布局基础设施

文件：

- [lib/app/layout/app_layout.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/layout/app_layout.dart)

当前状态：

- 已有统一断点
- 已有 `pageContentMaxWidth` / `sheetHeightFactor`
- 已有部分网格列数计算逻辑

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 把页面型内容区和控制型面板区的断点口径进一步拆清
- [ ] 明确哪些页面只允许看 `constraints.maxWidth`
- [ ] 明确哪些页面允许看整屏宽度
- [ ] 视需要补充面板缩放公共 helper，避免各页面重复定义缩放因子

## 3. P0 页面

### 3.1 阅读页设置弹层

文件：

- [lib/features/reader/presentation/reader_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart)

当前状态：

- 外层已有 `sheetHeightFactor + maxWidth`
- 内部历史上固定尺寸较多
- 是当前最容易在大屏上显得挤的区域

改造方式：

- `缩放为主，局部重排为辅`

任务：

- [ ] 完成“界面设置”紧凑模式全部固定尺寸的统一缩放
- [ ] 统一入口胶囊、字号控制、背景色、背景图、翻页动画区域的比例关系
- [ ] 在窄宽度下，顶部快捷入口从固定 3 列降到 2 列
- [ ] 在更宽面板下，允许快捷入口从 3 列升到 4 列
- [ ] 清理同一个弹层里“有些区域缩放、有些区域固定”的混合状态
- [ ] 复核阅读设置与漫画设置两套分支的视觉一致性

## 4. P1 页面

### 4.1 书源页

文件：

- [lib/features/source/presentation/source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)

当前状态：

- 已做限宽
- 主体仍偏单列列表页

改造方式：

- `重排`

任务：

- [ ] 为 `600+` 宽度设计书源页主结构
- [ ] 为 `840+` 宽度设计书源筛选/分组与列表的并列关系
- [ ] 提升大屏下列表项的信息密度
- [ ] 把搜索、过滤汇总、分组入口从“手机式竖排串联”调整成更适合中屏/大屏的结构

### 4.2 书架页

文件：

- [lib/features/bookshelf/presentation/bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart)
- [lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart)
- [lib/features/bookshelf/presentation/widgets/bookshelf_page_sections.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/widgets/bookshelf_page_sections.dart)

当前状态：

- 已有部分列数逻辑
- 网格列数会变
- 页面骨架仍偏手机单列滚动

改造方式：

- `重排`

任务：

- [ ] 明确书架页中屏和大屏的顶部摘要区结构
- [ ] 优化筛选条、标签、继续阅读卡片与内容区的层级关系
- [ ] 分别为“列表模式”和“网格模式”设计大屏策略
- [ ] 校验网格列数增长后，信息密度是否真的提升，而不只是封面变小

### 4.3 搜索页

文件：

- [lib/features/search/presentation/search_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/search_page.dart)
- [lib/features/search/presentation/widgets/search_input_card.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_input_card.dart)
- [lib/features/search/presentation/widgets/search_book_card.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_book_card.dart)
- [lib/features/search/presentation/widgets/search_report_summary.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_report_summary.dart)

当前状态：

- 已有限宽
- 条件区和结果区仍偏单列串联

改造方式：

- `重排`

任务：

- [ ] 设计中屏以上搜索页信息层级
- [ ] 搜索输入卡、搜索报告、结果区不再全部手机式纵向堆叠
- [ ] 搜索结果卡片在更宽内容区启用更高信息密度
- [ ] 评估是否需要在中屏以上拆出侧边过滤或结果辅助区

### 4.4 书籍详情页

文件：

- [lib/features/book/presentation/book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart)
- [lib/features/book/presentation/widgets/book_detail_primary_actions.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/widgets/book_detail_primary_actions.dart)
- [lib/features/book/presentation/widgets/book_detail_sections.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/widgets/book_detail_sections.dart)

当前状态：

- 已有限宽
- 仍偏手机单列详情结构

改造方式：

- `重排`

任务：

- [ ] `600+` 下将封面/摘要/操作区做成更清晰的分栏
- [ ] 章节预览、缓存、换源等模块在大屏上重新组织
- [ ] 提升详情页在中屏和大屏上的信息利用率

## 5. P2 页面

### 5.1 我的页

文件：

- [lib/features/mine/presentation/mine_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/mine_page.dart)

当前状态：

- 已有限宽
- 常用/其他 action 区偏手机布局

改造方式：

- `增强`

任务：

- [ ] 让 action 区在更宽宽度下更舒展
- [ ] 复核 profile 卡与 action 区的视觉比例
- [ ] 评估是否需要把“常用 / 其他”在中屏以上做成分栏

### 5.2 外观页

文件：

- [lib/features/mine/presentation/appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart)

当前状态：

- 已有 `optionGridColumnsForWidth`
- 是二级设置页里自适应基础相对较好的一页

改造方式：

- `增强`

任务：

- [ ] 复核预览卡在中屏/大屏下的空间利用率
- [ ] 统一各 section card 的宽度和密度策略
- [ ] 评估是否需要把预览区与选项区拆成更明显的两层布局

### 5.3 系统设置页

文件：

- [lib/features/mine/presentation/system_settings_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/system_settings_page.dart)

当前状态：

- 已有限宽
- 仍偏典型单列设置页

改造方式：

- `增强`

任务：

- [ ] 复核 section card 在中屏上的留白与层级
- [ ] 把适合并列的设置项改成双列或网格

### 5.4 书签页

文件：

- [lib/features/mine/presentation/bookmarks_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/bookmarks_page.dart)

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 复核书签列表项在更宽宽度下的信息密度
- [ ] 评估是否需要分栏或更宽内容排版

### 5.5 缓存管理页

文件：

- [lib/features/mine/presentation/cache_management_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/cache_management_page.dart)

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 复核状态摘要区和列表区的大屏结构
- [ ] 评估统计信息是否适合并排展示

### 5.6 阅读记录页

文件：

- [lib/features/reader/presentation/reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart)

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 让统计区、筛选区、列表区在中屏以上关系更清晰
- [ ] 复核图表和时间视图的大屏可读性

### 5.7 错误中心页

文件：

- [lib/features/error/presentation/error_center_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/error/presentation/error_center_page.dart)

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 提升日志卡片在宽屏下的阅读效率
- [ ] 评估是否适合把过滤控制区和日志列表区更清晰分层

### 5.8 本地图书导入页

文件：

- [lib/features/bookshelf/presentation/local_library_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/local_library_page.dart)

优先级：

- `P2`

改造方式：

- `增强`

任务：

- [ ] 复核空状态/导入状态卡片在大屏上的体量和层级
- [ ] 评估是否需要左右结构而不是单列大卡片

## 6. P3 页面

### 6.1 发现页

文件：

- [lib/features/discover/presentation/discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart)

当前状态：

- 已有 compact / wide 分支
- 已有 side panel 宽度差异

改造方式：

- `增强`

优先级：

- `P3`

任务：

- [ ] 复核 wide layout 的内容区比例是否最优
- [ ] 只做收尾优化，不作为第一批重点改造对象

### 6.2 公告列表页 / 公告详情页

文件：

- [lib/features/announcement/presentation/announcement_list_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/presentation/announcement_list_page.dart)
- [lib/features/announcement/presentation/announcement_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/presentation/announcement_detail_page.dart)

优先级：

- `P3`

改造方式：

- `增强`

任务：

- [ ] 维持限宽信息页策略即可
- [ ] 仅在需要时优化阅读宽度与信息层级

### 6.3 登录页 / 用户资料页

文件：

- [lib/features/auth/presentation/auth_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/auth/presentation/auth_page.dart)
- [lib/features/auth/presentation/user_profile_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/auth/presentation/user_profile_page.dart)

优先级：

- `P3`

改造方式：

- `增强`

任务：

- [ ] 保持限宽和表单可读性即可
- [ ] 非核心高收益区域

### 6.4 反馈页 / 关于页 / 其他信息页

文件：

- [lib/features/mine/presentation/feedback_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/feedback_page.dart)
- [lib/features/mine/presentation/about_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/about_page.dart)

优先级：

- `P3`

改造方式：

- `增强`

任务：

- [ ] 维持信息页限宽即可
- [ ] 不是前期主要投入方向

## 7. 非页面级但需要跟进的组件

### 7.1 书架网格组件

文件：

- [lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart)
- [lib/features/bookshelf/presentation/widgets/bookshelf_page_sections.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/widgets/bookshelf_page_sections.dart)

任务：

- [ ] 校验列数增长后的内容密度是否同步提升
- [ ] 校验标题、作者、状态信息是否支持不同列宽下的层级变化

### 7.2 搜索结果卡组件

文件：

- [lib/features/search/presentation/widgets/search_book_card.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_book_card.dart)

任务：

- [ ] 为更宽卡片模式准备更高信息密度展示

### 7.3 阅读设置组件内部控件

文件：

- [lib/features/reader/presentation/reader_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart)

任务：

- [ ] 统一紧凑模式内部缩放口径
- [ ] 避免部分区域缩放、部分区域固定

## 8. 推荐执行顺序

建议按以下顺序推进：

1. 阅读设置弹层
2. 书源页
3. 书架页
4. 搜索页
5. 书籍详情页
6. 我的页 / 外观页 / 系统设置页
7. 阅读记录页 / 错误中心页 / 本地图书导入页
8. 发现页及信息页收尾

## 9. 最终结论

如果按“全页面”来梳理，当前最值得优先改造适配的不是全部页面平均推进，而是：

- 阅读设置弹层
- 书源页
- 书架页
- 搜索页
- 书籍详情页

这些页面要么用户感知最强，要么当前最像“限宽版手机 UI”，要么当前大屏收益明显不足。

