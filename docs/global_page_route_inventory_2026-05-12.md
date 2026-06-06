# 全局页面路由清单

更新时间：2026-06-06

本文用于 `tool/check_route_inventory.dart` 校验。新增路由必须同步登记。

## 路由表

| 路由 | 名称 | 所属模块 | 页面 / 说明 |
| --- | --- | --- | --- |
| `/` | root | app | 根据启动策略重定向 |
| `/bookshelf` | bookshelf | bookshelf | 书架 |
| `/discover` | discover | discover | 发现 |
| `source/:sourceId/category/:categoryId` | discover-category-books | discover | 发现分类书籍，嵌套路由 |
| `/stats` | stats | reader | 阅读统计 |
| `/mine` | mine | mine | 我的 |
| `/announcements` | announcements | announcement | 公告列表 |
| `/announcements/:id` | announcement-detail | announcement | 公告详情 |
| `/auth` | auth | auth | 登录 |
| `/profile` | profile | auth | 用户资料 |
| `/search` | search | search | 搜索 |
| `/source/webview-login` | source-webview-login | source | 书源 WebView 登录 |
| `/book/:bookId` | book | book | 书籍详情 |
| `/local-library` | local-library | bookshelf | 本地图书库 |
| `/local/book/:bookId` | local-book | bookshelf | 本地图书详情重定向 |
| `/read-records` | read-records | reader | 旧阅读记录入口，重定向到 `/stats` |
| `/local/reader/:bookId/:chapterId` | local-reader | reader | 本地图书阅读重定向 |
| `/reader/:bookId/:chapterId` | reader | reader | 阅读器 |
| `/appearance` | appearance | mine | 外观设置 |
| `/appearance/reader-background` | reader-background | mine | 阅读器背景 |
| `/appearance/launch-image` | launch-image | mine | 启动图 |
| `/appearance/launch-image/editor` | launch-image-editor | mine | 启动图编辑 |
| `/appearance/advanced-themes` | advanced-themes | mine | 高级主题 |
| `/appearance/advanced-themes/editor` | advanced-theme-editor | mine | 高级主题编辑 |
| `/bottom-nav-icon-galleries` | bottom-nav-icon-galleries | mine | 底部导航图标库 |
| `/bottom-nav-icon-galleries/editor` | bottom-nav-icon-gallery-editor | mine | 底部导航图标编辑 |
| `/cover-galleries` | cover-galleries | mine | 封面图库 |
| `/cover-galleries/editor` | cover-gallery-editor | mine | 封面图库编辑 |
| `/mine/tags` | mine-tags | mine | 标签管理 |
| `/mine/categories` | mine-categories | mine | 分类管理 |
| `/membership` | membership | mine | 会员中心 |
| `/about` | about | mine | 关于 |
| `/system-settings` | system-settings | mine | 系统设置 |
| `/font-management` | font-management | mine | 字体管理 |
| `/bookmarks` | bookmarks | mine | 书签 |
| `/error-center` | error-center | mine | 错误中心 |
| `/feedback` | feedback | mine | 反馈列表 |
| `/feedback/:id` | feedback-detail | mine | 反馈详情 |
| `/feedback/compose` | feedback-compose | mine | 反馈提交 |

## 维护规则

- 新增 route 后必须同步本表。
- 删除 route 后必须从本表移除。
- 重定向 route 也必须登记。
- 嵌套路由使用源码中的原始 path 登记，避免校验脚本漏判。
