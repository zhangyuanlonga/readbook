# 自适应改造清单

更新时间：2026-04-08  
用途：基于当前项目代码，给出页面级自适应改造优先级清单。  
说明：这份清单不是理想化建议，而是结合当前实现方式、现有基础设施和实际问题感知整理出来的落地排序。

## 1. 判定标准

页面分为 4 类：

- `优先改造`
  当前用户感知问题明显，且收益高
- `建议改造`
  当前能用，但大屏体验明显还有空间
- `局部增强`
  主体结构基本可用，重点补内容密度或局部组件
- `暂不优先`
  当前实现已经相对稳定，不是自适应改造的高收益区域

改造方式统一按两类理解：

- `重排`
  指列数、分栏、信息层级、区域关系变化
- `缩放`
  指保留结构，仅对密度、尺寸、间距做有限比例调整

## 2. 优先级总览

### P0

- 阅读页设置弹层

### P1

- 书源页
- 书架页
- 搜索页
- 书籍详情页

### P2

- 我的页及其设置类子页面
- 阅读记录页
- 错误中心页

### P3

- 发现页
- 公告页
- 登录/反馈/关于等信息页

## 3. 页面级清单

## 3.1 阅读页设置弹层

文件：

- [lib/features/reader/presentation/reader_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart)

优先级：

- `P0`

当前状态：

- 外层有 `sheetHeightFactor` 和最大宽度
- 内层大量固定尺寸
- 视觉密度高，用户感知问题最明显

现有问题：

- 主流大屏仍然显得挤
- 胶囊卡片、字号控制、背景色、背景图等区域尺度不一致
- 面板虽然限宽，但内部之前偏手机密度

推荐方案：

- `缩放为主`
- 必要时对快捷入口做少量重排

原因：

- 这是典型控制面板
- 用户更需要“同一套结构更舒服”，而不是彻底换布局

建议动作：

- 统一所有固定尺寸到一个缩放因子体系
- 背景图卡片、色点、胶囊卡片、图标、间距、圆角统一收敛
- 顶部快捷入口允许在极窄宽度下从 3 列降到 2 列

## 3.2 书源页

文件：

- [lib/features/source/presentation/source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)

优先级：

- `P1`

当前状态：

- 已有限宽保护
- 主体仍是居中单列列表

现有问题：

- 大屏只是“不太宽”，不是“更好用”
- 搜索、分组、列表信息层没有明显大屏结构变化
- 主流大屏下仍像手机版拉宽

推荐方案：

- `重排`

建议动作：

- `600+` 引入更清晰的筛选摘要区
- `840+` 考虑左侧筛选 / 分组，右侧列表
- 列表项在大屏增加次级信息展示
- 搜索栏和筛选汇总不再全部纵向堆叠

## 3.3 书架页

文件：

- [lib/features/bookshelf/presentation/bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart)
- [lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart)

优先级：

- `P1`

当前状态：

- 有部分列数逻辑
- 有网格列数根据宽度变化
- 页面整体仍偏手机滚动思路

现有问题：

- 列数变化不等于布局优化完成
- 顶部筛选、标签、继续阅读、摘要区和内容区关系仍偏手机
- 列表模式的大屏收益不明显

推荐方案：

- `重排`

建议动作：

- 书架头部操作区在中屏以上做更强的分组和摘要布局
- 网格和列表分别补大屏策略
- 继续阅读卡片、筛选条、标签摘要不要再完全按单列心智组织

## 3.4 搜索页

文件：

- [lib/features/search/presentation/search_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/search_page.dart)

优先级：

- `P1`

当前状态：

- 已有 `LayoutBuilder + maxWidth`
- 结果页主体仍偏单列

现有问题：

- 大屏时信息密度不高
- 条件区、结果摘要区、结果区关系还不够拉开
- 只是“限宽居中”

推荐方案：

- `重排`

建议动作：

- 中屏以上拆分搜索条件区与结果区
- 大屏结果卡片增加更高信息密度
- 报告卡、筛选卡、搜索结果不要完全按手机顺序串行排列

## 3.5 书籍详情页

文件：

- [lib/features/book/presentation/book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart)

优先级：

- `P1`

当前状态：

- 已有限宽保护
- 主体仍偏单列顺序展开

现有问题：

- 大屏时封面、简介、操作区、章节预览没有明显重组
- 当前结构更像“手机页居中放大”

推荐方案：

- `重排`

建议动作：

- `600+` 封面摘要和操作区分栏
- 目录预览、缓存、换源等模块增强并列关系
- 把大屏空间转成信息层级，不只是更宽留白

## 3.6 我的页

文件：

- [lib/features/mine/presentation/mine_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/mine_page.dart)

优先级：

- `P2`

当前状态：

- 页面限宽明确
- 主体是典型设置/入口列表

现有问题：

- 大屏收益一般，但问题不算最突出

推荐方案：

- `局部增强`

建议动作：

- 常用/其他 action 区在中屏以上进入更舒展宫格
- 个人卡片与 action 区可以考虑分层更清晰

## 3.7 外观页 / 系统设置页 / 书签页 / 缓存页 / 反馈页 / 关于页

文件：

- [lib/features/mine/presentation/appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart)
- [lib/features/mine/presentation/system_settings_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/system_settings_page.dart)
- [lib/features/mine/presentation/bookmarks_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/bookmarks_page.dart)
- [lib/features/mine/presentation/cache_management_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/cache_management_page.dart)
- [lib/features/mine/presentation/feedback_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/feedback_page.dart)
- [lib/features/mine/presentation/about_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/about_page.dart)

优先级：

- `P2`

当前状态：

- 这些页面普遍已有 `LayoutBuilder + maxWidth`
- 外观页已经部分使用 `optionGridColumnsForWidth`

推荐方案：

- `局部增强`

建议动作：

- 先统一信息区和选项区的容器宽度策略
- 再把宫格/选项区域补齐断点逻辑

## 3.8 阅读记录页

文件：

- [lib/features/reader/presentation/reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart)

优先级：

- `P2`

当前状态：

- 已有限宽
- 局部有 `LayoutBuilder`

推荐方案：

- `局部增强`

建议动作：

- 统计卡片、中屏以上的信息排列优化
- 过滤/图表/列表区关系增强

## 3.9 发现页

文件：

- [lib/features/discover/presentation/discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart)

优先级：

- `P3`

当前状态：

- 相比其他页面更成熟
- 已经有 compact / wide 分支
- 中屏和扩展屏有 side panel 宽度区分

推荐方案：

- `暂不优先`

原因：

- 这是当前自适应做得相对更完整的一页
- 不是高优先收益区

## 3.10 公告 / 错误中心 / 登录 / 用户资料等信息页

文件示例：

- [lib/features/announcement/presentation/announcement_list_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/presentation/announcement_list_page.dart)
- [lib/features/announcement/presentation/announcement_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/presentation/announcement_detail_page.dart)
- [lib/features/error/presentation/error_center_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/error/presentation/error_center_page.dart)
- [lib/features/auth/presentation/auth_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/auth/presentation/auth_page.dart)
- [lib/features/auth/presentation/user_profile_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/auth/presentation/user_profile_page.dart)

优先级：

- `P3`

当前状态：

- 大多已经有 `LayoutBuilder + ConstrainedBox`
- 信息量相对有限

推荐方案：

- `暂不优先`

原因：

- 当前收益不如书架/书源/搜索/阅读设置高

## 4. 执行顺序建议

建议按这个顺序推进：

1. 阅读设置弹层
2. 书源页
3. 书架页
4. 搜索页
5. 书籍详情页
6. 我的页和设置页簇
7. 阅读记录页
8. 发现页与信息页收尾

## 5. 最终口径

当前项目最需要改造适配的页面不是全部平均推进，而是：

- 先修用户最能感知的
- 先修“看起来像手机版放大”的
- 先修内容层而不是只修外层容器

一句话总结：

**当前最值得优先改造的是：阅读设置弹层、书源页、书架页、搜索页、书籍详情页。**

