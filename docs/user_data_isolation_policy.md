# 用户数据隔离策略

创建时间：2026-06-10

## 隔离原则

- 跟在线账号、权限、私人内容相关的数据必须按 `userId` 隔离。
- 本地图书文件、阅读器外观设置、应用主题等设备级偏好不按账号隔离。
- 未登录态统一使用 `local_user` 作为本地作用域。

## 必须隔离

| 数据 | 当前存储 | 隔离方式 |
| --- | --- | --- |
| 私人书源 | 服务端 + 本地展示缓存 | API 实时请求，登出清理展示缓存 |
| 搜索历史 | `SharedPreferences` | `search.history.{userId}` |
| 在线章节缓存 | Drift `chapter_caches` | 后续表迁移增加 `user_id` |
| 在线阅读进度 | Drift `reading_progresses` | 后续表迁移增加 `user_id` |
| 书签/笔记 | Drift `bookmarks` | 后续表迁移增加 `user_id` |
| 搜索命中统计 | Drift `search_source_hits` | 后续表迁移增加 `user_id` |

## 不隔离

| 数据 | 原因 |
| --- | --- |
| 本地图书文件 | 设备资产，不属于在线账号 |
| 阅读器主题、字号、翻页设置 | 设备级偏好 |
| 应用主题、导航偏好 | 设备级偏好 |
| 封面图片缓存 | 可重建公共缓存，不作为权限来源 |

## 本轮代码治理

- 搜索历史已改为按 `search.history.{userId}` 保存。
- 未登录时搜索历史写入 `search.history.local_user`。
- 旧 `search.history` 仍可读取，避免升级后历史丢失。

## 后续数据库迁移建议

1. 将 `chapter_caches`、`bookmarks`、`reading_progresses`、`search_source_hits` 重建为包含 `user_id` 的复合主键或唯一索引。
2. 迁移旧数据到 `local_user` 或当前登录用户。
3. 所有读取和写入都通过当前会话解析 `userId`。
4. 为迁移补充按用户查询和多账号切换测试。
