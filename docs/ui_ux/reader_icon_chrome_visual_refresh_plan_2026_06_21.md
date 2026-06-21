# 阅读器图标与 Chrome 视觉改造计划

> 阶段 12 专项。目标是统一阅读器高频操作图标、尺寸、状态颜色和后续替换出口，避免阅读器 chrome、底部菜单、设置面板、目录/书签/批注/缓存等入口继续出现新旧图标混搭。

## 当前审计结论

- 阅读器区域仍大量直接使用 `Icons.xxx`，同一操作在不同文件里存在圆角、填充、outlined 混用。
- 当前项目未引入 `lucide`/Material Symbols 独立图标包，已有依赖主要是 Flutter Material Icons 与 `flutter_svg`。
- 阅读器图标不只是“换图标”，还绑定高频操作语义：顶部栏、底部栏、自动阅读、设置面板、点击分区、选择/批注、缓存、目录、书籍详情、换源等。
- 最适合先做统一出口，再按区域逐步替换。后续如果切换到 lucide 或自定义 svg，只需要优先改统一出口。

## 图标规范

- 阅读器 chrome 优先使用轻量、线性或圆角图标，减少厚重 filled 图标。
- 高频操作尺寸建议：
  - 顶部 chrome：20-22
  - 底部工具栏：20-22
  - 设置面板小入口：16-18
  - 选择/批注工具栏：18-20
- 状态颜色统一跟随阅读器主题：
  - 默认：`ReaderThemeColors.text`
  - 次级：`ReaderThemeColors.meta`
  - 激活：主题 `primary`
  - 禁用：默认颜色降低透明度
- 所有新增或改造的阅读器图标优先从 `ReaderIcons` 取，不再直接散写 `Icons.xxx`。

## 第一批已纳入统一出口

- [x] 顶部 chrome：返回、目录、界面设置、书籍详情、更多
- [x] 底部 chrome：目录、自动阅读、日夜模式、界面设置
- [x] 自动阅读浮层：继续、暂停、目录、设置、退出
- [x] 点击分区编辑器：上一页、下一页、工具栏、目录、自动阅读、灵感、夜间、无操作
- [x] 选择/批注工具栏：复制、灵感、笔记、高亮、加粗、下划线、波浪线、清除、删除
- [x] 字体与翻页设置入口：字体、管理字体、字重、点击分区、快捷开关
- [x] 章节缓存弹窗：章节数、缓存数、完成、失败、进度、停止

## 替换表

| 语义 | 统一出口 | 当前选择 | 备注 |
| --- | --- | --- | --- |
| 返回 | `ReaderIcons.back` | `arrow_back_rounded` | 顶部 chrome 使用，更简洁 |
| 目录 | `ReaderIcons.catalog` | `format_list_bulleted_rounded` | 替代散落的 `list_alt_outlined` |
| 界面设置 | `ReaderIcons.appearance` | `palette_outlined` | 保留轻量风格 |
| 书籍详情 | `ReaderIcons.bookDetail` | `menu_book_rounded` | 替代更厚重的 `auto_stories_rounded` |
| 更多 | `ReaderIcons.more` | `more_horiz_rounded` | 减少顶部竖向厚重感 |
| 日间 | `ReaderIcons.dayMode` | `light_mode_rounded` | 跟随日夜状态 |
| 夜间 | `ReaderIcons.nightMode` | `dark_mode_rounded` | 跟随日夜状态 |
| 自动阅读开始 | `ReaderIcons.play` | `play_arrow_rounded` | 去除圆形 filled 混用 |
| 自动阅读暂停 | `ReaderIcons.pause` | `pause_rounded` | 去除圆形 filled 混用 |
| 缓存章节 | `ReaderIcons.cache` | `download_for_offline_rounded` | 与缓存弹窗统一 |
| 已缓存 | `ReaderIcons.cached` | `task_alt_rounded` | 表达完成状态 |
| 换源 | `ReaderIcons.switchSource` | `swap_horiz_rounded` | 保持原语义 |
| 加入书架 | `ReaderIcons.bookshelfAdd` | `bookmark_add_outlined` | 轻量入口 |
| 已加入书架 | `ReaderIcons.bookshelfAdded` | `bookmark_added` | 当前 Material 无更稳妥 outlined 替代 |

## 后续阶段任务

- [ ] 第二批：阅读器目录弹窗图标统一，包括搜索、排序、文件夹、章节、当前播放/当前章节、更多、删除。
- [ ] 第三批：阅读器设置所有 section 头部图标统一，包括背景、布局、音频、漫画、自动阅读、主题背景。
- [ ] 第四批：阅读错误页、PDF/图片/音频特殊模式、网络图片占位、异常操作入口统一。
- [ ] 第五批：阅读记录页面图标统一。阅读记录属于阅读域但不是阅读器 chrome，可放后处理。
- [ ] 第六批：若确认引入 lucide 或 Material Symbols，先替换 `ReaderIcons`，再少量修正尺寸与语义不匹配处。

## 验收标准

- 高频阅读器 chrome 不再直接散写 `Icons.xxx`，统一从 `ReaderIcons` 获取。
- 自动阅读、日夜模式、目录、设置、缓存、换源、书架操作在顶部栏、底部栏、浮层、点击分区里的图标语义一致。
- 替换后 `dart analyze` 通过。
- 不引入新图标依赖，不影响阅读器章节加载、分页、翻页、缓存等业务逻辑。
