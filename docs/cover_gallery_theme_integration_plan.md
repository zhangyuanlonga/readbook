# 封面图集接入高级主题任务计划

## 1. 目标

把“封面图集”从独立资源管理功能，接入到“高级主题”的真实生效链路里。

最终目标：

- 用户管理封面图集素材
- 在高级主题里选择一个封面图集
- 书籍无真实封面时，优先使用当前生效高级主题绑定的封面图集
- 如果没有绑定图集，再回退到现有文字封面逻辑

## 2. 业务规则

### 2.1 封面显示优先级

1. 真实封面
2. 书籍自定义封面
3. 当前生效高级主题绑定的封面图集
4. 现有 `TextCoverPlaceholder` 文字封面

### 2.2 图集分配规则

- 图集只有 `1` 张图：所有无封面书统一使用这 `1` 张
- 图集有 `多` 张图：按书籍稳定分配一张，不做真正随机

### 2.3 稳定分配方式

推荐使用：

- `bookId`
- 或 `sourceId + detailUrl`

做 hash，再 `% 图片数` 取图。

要求：

- 同一本书每次进入都稳定显示同一张图
- 不会因为刷新列表而改变

## 3. 可勾选任务

### 3.1 数据模型

- [ ] 在 [app_advanced_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/app_advanced_theme.dart) 增加 `coverGalleryId`
- [ ] 补充 `toJson`
- [ ] 补充 `fromJson`
- [ ] 补充 `copyWith`

### 3.2 高级主题编辑页

- [ ] 在 [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart) 中把当前“封面”区域改成真实绑定入口
- [ ] 点击封面后从底部弹出图集列表
- [ ] 支持先勾选再点击“应用”
- [ ] 绑定后显示当前图集名称
- [ ] 绑定后显示缩略图预览
- [ ] 支持取消绑定，恢复为未绑定状态

### 3.3 图集读取与服务复用

- [ ] 复用 [cover_gallery_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/cover_gallery_service.dart) 读取图集列表
- [ ] 如缺少按 id 读取图集的辅助能力则补齐
- [ ] 如果接入层需要，再增加 provider，但避免过度抽象

### 3.4 统一封面解析层

- [ ] 新增统一封面解析方法或 presentation 层
- [ ] 明确输入：
  - [ ] 真实封面 url/path
  - [ ] 自定义封面 path
  - [ ] 当前生效高级主题
  - [ ] 当前可用封面图集
  - [ ] 书籍稳定标识
- [ ] 明确输出来源：
  - [ ] `real`
  - [ ] `custom`
  - [ ] `gallery`
  - [ ] `placeholder`

### 3.5 书架页接入

- [ ] 在 [bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart) 接入统一封面解析层
- [ ] 替换当前直接回退 `TextCoverPlaceholder` 的逻辑
- [ ] 验证列表卡片封面
- [ ] 验证宫格卡片封面
- [ ] 验证继续阅读卡封面

### 3.6 发现页接入

- [ ] 在 [discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart) 接入统一封面解析层
- [ ] 让无封面书能吃到当前主题绑定图集

### 3.7 其他页面统一接入

- [ ] 梳理其他 fallback 使用点
- [ ] 接入 [bookmarks_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/bookmarks_page.dart)
- [ ] 接入 [cache_management_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/cache_management_page.dart)
- [ ] 接入 [reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart)

### 3.8 生效与回退验证

- [ ] 未启用高级主题时，仍走旧逻辑
- [ ] 启用高级主题但未绑定封面图集时，仍走文字封面
- [ ] 启用高级主题且绑定图集时，无真实封面书使用图集图片
- [ ] 同一本书在不同页面使用同一张图
- [ ] 不同书能分配到不同图片

## 4. 推荐实施顺序

- [ ] 第一步：`coverGalleryId` 数据模型
- [ ] 第二步：高级主题编辑页封面绑定 UI
- [ ] 第三步：统一封面解析层
- [ ] 第四步：书架页接入
- [ ] 第五步：发现页接入
- [ ] 第六步：其他列表页逐步替换

## 5. 验收标准

- [ ] 高级主题可绑定一个封面图集
- [ ] 绑定交互简单：底部弹出、勾选、应用
- [ ] 无真实封面时，图集生效
- [ ] 图集多图时按书籍稳定分配
- [ ] 同一本书在书架、发现等页面封面一致
- [ ] 未绑定时完全回退到现有文字封面
- [ ] `flutter analyze` 通过

## 6. 暂不做事项

- 分类 -> 图集联动
- 标签 -> 图集联动
- 高级主题绑定多个封面图集
- 真随机切换封面
- 替代真实封面
- 阅读器正文页封面相关联动
