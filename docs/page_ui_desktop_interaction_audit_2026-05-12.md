# 页面桌面交互审计

更新时间：2026-05-12  
关联计划：`docs/page_ui_component_governance_plan_2026-05-12.md` UI-G5

## 0. 审计结论

桌面/Web 当前已经有大屏布局基础，但普通列表页的指针和键盘体验仍偏移动端：

- `MouseRegion`、`Shortcuts`、`KeyboardListener` 覆盖很少。
- 阅读器已有专用焦点和键盘路径，应作为桌面交互保留项。
- 大量页面依赖 `onLongPress`、`PopupMenuButton`，桌面端还需要 hover、focus、右键/更多菜单、显式滚动反馈。

## 1. 高频/重点页面

| 页面/文件 | 当前交互 | 优先级 | 建议 |
| --- | --- | --- | --- |
| `BookshelfPage` | 批量选择、长按、菜单已有 | P0 | 补 hover/focus、方向键选择、显式选择态 |
| `ReaderPage` | 已有键盘/滚轮/focus 路径 | 保留 | 纳入回归，不随普通页面规则改坏 |
| `SearchPage` | 结果列表和过滤面板偏触控 | P1 | `Ctrl/Cmd+F` 聚焦搜索，结果键盘选择 |
| `BookmarksPage` | 分组/详情分栏已有 | P1 | 分组列表补键盘上下选择、focus 可见 |
| `AdvancedThemeEditorPage` | 资源卡片长按较多 | P1 | 桌面改 hover 工具、右键/更多菜单 |
| `FontManagementPage` | 菜单和导入已有 | P1 | 字体列表补 hover/focus/快捷操作 |
| `SourcePage` / `ScriptSourceEditorPage` | 能力开启后工作台 | P2 | 编辑器快捷键、日志面板、运行/保存快捷键 |

## 2. 迁移规则

- 高频列表补 hover 和 focus，可见态不能只依赖颜色轻微变化。
- 长列表补 `Scrollbar` 或平台默认可见滚动反馈。
- 搜索类页面支持 `Ctrl/Cmd+F` 聚焦搜索。
- 编辑类页面支持 `Ctrl/Cmd+S` 保存，`Esc` 关闭浮层。
- 可批量操作页面补桌面工具条和右键/更多菜单。
- 阅读器键盘翻页、滚轮、窗口缩放分页恢复纳入保留回归。

## 3. G5 验收结论

- 已完成桌面交互静态审计和页面优先级归档。
- 已明确普通页面后续桌面增强方向。
- 阅读器既有桌面交互作为保留基线，不纳入批量迁移。
