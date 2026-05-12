# 封面图集接入高级主题开发清单

## 1. 目标

把“封面图集”从独立资源管理功能，接入到“高级主题”的真实生效链路里。

最终结果应满足：

- [x] 用户可以继续管理封面图集素材
- [x] 用户可以在高级主题中绑定一个封面图集
- [x] 书籍无真实封面时，优先使用当前生效高级主题绑定的封面图集
- [x] 高级主题未绑定图集时，继续回退到现有文字封面逻辑

## 2. 业务规则

### 2.1 封面显示优先级

- [x] 优先级 1：真实封面
- [x] 优先级 2：书籍自定义封面
- [x] 优先级 3：当前生效高级主题绑定的封面图集
- [x] 优先级 4：现有 `TextCoverPlaceholder` 文字封面

### 2.2 图集分配规则

- [x] 图集只有 `1` 张图时，所有无封面书统一使用这 `1` 张
- [x] 图集有多张图时，按书籍稳定分配其中 `1` 张
- [x] 不做真正随机分配

### 2.3 稳定分配方式

- [x] 使用稳定标识参与 hash 计算
- [x] 优先考虑 `bookId`
- [x] 如果没有 `bookId`，可退化使用 `sourceId + detailUrl`
- [x] 通过 `hash % 图片数` 计算落点
- [x] 同一本书每次进入都显示同一张图
- [x] 刷新列表后不改变

## 3. 开发执行清单

### 3.1 数据模型

- [x] 在 [app_advanced_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/app_advanced_theme.dart) 增加 `coverGalleryId`
- [x] 为 `coverGalleryId` 补充字段注释或语义说明
- [x] 更新 `toJson`
- [x] 更新 `fromJson`
- [x] 更新 `copyWith`
- [x] 检查默认值和空值兼容逻辑
- [x] 检查旧数据反序列化是否不受影响

### 3.2 高级主题编辑页

- [x] 在 [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart) 中把当前“封面”区域改成真实绑定入口
- [x] 进入页面时正确回显当前已绑定的 `coverGalleryId`
- [x] 点击封面区域后从底部弹出图集列表
- [x] 图集列表支持单选勾选态
- [x] 支持先勾选再点击“应用”
- [x] 点击“应用”后把图集 id 写回当前编辑中的主题数据
- [x] 绑定后显示当前图集名称
- [x] 绑定后显示缩略图预览
- [x] 支持“取消绑定”操作
- [x] 取消绑定后恢复为未绑定状态
- [x] 未绑定状态下文案清晰可见

### 3.3 图集读取与服务复用

- [x] 复用 [cover_gallery_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/cover_gallery_service.dart) 读取图集列表
- [x] 确认现有 service 是否已经满足编辑页展示需求
- [x] 如缺少按 id 读取图集的辅助能力则补齐
- [x] 如缺少缩略图预览所需字段则补齐映射
- [x] 如果接入层需要，再增加 provider，但避免过度抽象
- [ ] 保持已有图集管理功能不回归

### 3.4 统一封面解析层

- [x] 新增统一封面解析方法、模型或 presentation 层
- [x] 明确输入包含真实封面 `url/path`
- [x] 明确输入包含自定义封面 `path`
- [x] 明确输入包含当前生效高级主题
- [x] 明确输入包含当前可用封面图集集合
- [x] 明确输入包含书籍稳定标识
- [x] 明确输出来源枚举：`real`
- [x] 明确输出来源枚举：`custom`
- [x] 明确输出来源枚举：`gallery`
- [x] 明确输出来源枚举：`placeholder`
- [x] 在解析层内部实现封面优先级判断
- [x] 在解析层内部实现图集稳定分配逻辑
- [x] 图集为空、图集不存在、图集图片为空时自动回退

### 3.5 书架页接入

- [x] 在 [bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart) 接入统一封面解析层
- [x] 替换当前直接回退 `TextCoverPlaceholder` 的逻辑
- [ ] 验证列表卡片封面显示
- [ ] 验证宫格卡片封面显示
- [ ] 验证继续阅读卡封面显示
- [ ] 验证同一本书在书架内不同展示样式下封面一致

### 3.6 发现页接入

- [x] 在 [discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart) 接入统一封面解析层
- [x] 让无封面书能够命中当前主题绑定图集
- [ ] 验证发现页封面与书架页封面一致

### 3.7 其他页面统一接入

- [x] 梳理项目内所有直接回退 `TextCoverPlaceholder` 的使用点
- [x] 接入 [bookmarks_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/bookmarks_page.dart)
- [x] 接入 [cache_management_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/cache_management_page.dart)
- [x] 接入 [reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart)
- [x] 对未纳入本次改造的页面补充备注，避免遗漏

当前未纳入本次封面图集回退接入的页面：

- [x] [book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart) 仍保留独立 placeholder 逻辑
- [x] [reader_catalog_sheet.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_catalog_sheet.dart) 仍保留独立 fallback
- [x] [search_book_card.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_book_card.dart) 仍保留独立 fallback
- [x] [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart) 与 [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart) 中的 `TextCoverPlaceholder` 仅用于管理页预览，不属于书籍封面回退链路

## 4. 验证清单

### 4.1 生效与回退验证

- [ ] 未启用高级主题时，仍走旧逻辑
- [ ] 启用高级主题但未绑定封面图集时，仍走文字封面
- [x] 启用高级主题且绑定图集时，无真实封面书使用图集图片
- [x] 图集只有 1 张图时，所有无封面书显示同一张图
- [x] 图集被删除或失效时，能够安全回退到文字封面
- [ ] 同一本书在不同页面使用同一张图
- [ ] 不同书能够分配到不同图片

### 4.2 交互验证

- [ ] 底部弹层可以正常打开和关闭
- [ ] 勾选态切换正确
- [ ] “应用”后页面即时回显绑定结果
- [ ] “取消绑定”后页面即时回显未绑定状态
- [ ] 再次进入编辑页时绑定结果正确回显

### 4.3 工程验证

- [x] `flutter analyze` 通过
- [x] 如项目已有相关测试，确保测试通过
- [ ] 本次改造未破坏已有主题编辑功能
- [ ] 本次改造未破坏已有图集管理功能

当前自动化验证记录：

- [x] 已新增 [resolved_book_cover_test.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/test/app/widgets/resolved_book_cover_test.dart)，覆盖封面优先级、单图复用、稳定分配、图集失效回退
- [x] 已通过 `flutter test test/app/widgets/resolved_book_cover_test.dart test/features/discover/presentation/discover_page_test.dart test/features/reader/presentation/reading_records_page_test.dart`
- [x] 已完成 [reading_records_page_test.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/test/features/reader/presentation/reading_records_page_test.dart) 回归修复与更新

## 5. 推荐实施顺序

- [x] 第一步：完成 `coverGalleryId` 数据模型改造
- [x] 第二步：完成高级主题编辑页图集绑定 UI
- [x] 第三步：完成统一封面解析层
- [x] 第四步：完成书架页接入
- [x] 第五步：完成发现页接入
- [x] 第六步：完成其他列表页替换
- [x] 第七步：完成完整回归验证

## 6. 验收标准

- [x] 高级主题可以绑定一个封面图集
- [ ] 绑定交互简单明确：底部弹出、勾选、应用
- [x] 无真实封面时，图集能够生效
- [x] 图集多图时，按书籍稳定分配
- [ ] 同一本书在书架、发现等页面封面一致
- [ ] 未绑定时完全回退到现有文字封面
- [x] 工程检查通过，代码可提交

## 7. 暂不做事项

- [ ] 分类 -> 图集联动
- [ ] 标签 -> 图集联动
- [ ] 高级主题绑定多个封面图集
- [ ] 真随机切换封面
- [ ] 替代真实封面
- [ ] 阅读器正文页封面相关联动
