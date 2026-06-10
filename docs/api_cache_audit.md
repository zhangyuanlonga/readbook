# API 缓存审计

创建时间：2026-06-10

## 代码入口

| 文件 | 接口类型 | 当前缓存状态 | 治理结论 |
| --- | --- | --- | --- |
| `lib/core/network/api_client.dart` | 统一 API 客户端 | 已支持内存缓存 | 默认 `REALTIME`，新增 `ApiCachePolicy` |
| `lib/features/announcement/application/announcement_service.dart` | 公告 | 使用 `enableCache` | 可保留短缓存 |
| `lib/features/search/application/server_online_search_service.dart` | 在线搜索 | 未启用 API 缓存 | 必须实时 |
| `lib/features/search/application/server_book_gateway_service.dart` | 书籍网关 | 未启用 API 缓存 | 搜索实时，详情/章节可短缓存 |
| `lib/features/mine/application/private_book_source_service.dart` | 私人书源 | 未启用 API 缓存 | 必须实时 |
| `lib/core/user/user_profile_service.dart` | 当前用户资料 | 未启用 API 缓存 | 必须实时 |
| `lib/core/membership/membership_service.dart` | 会员/权益 | 未启用 API 缓存 | 必须实时 |
| `lib/core/source_access/source_access_service.dart` | 书源权限 | 未启用 API 缓存 | 必须实时 |
| `lib/core/mobile_features/mobile_feature_service.dart` | 模块权限 | 未启用 API 缓存 | 必须实时 |

## 本轮代码治理

- `ApiClient` 新增 `ApiCachePolicy.realtime/shortCache/longCache`。
- `ApiClient` 的缓存 key 已支持用户作用域：认证请求会写入 `user:{userId}` 前缀。
- 兼容旧 `enableCache` 调用：旧调用会映射为 `SHORT_CACHE`。

## 后续待办

- 为书籍详情、章节正文调用点显式标注 `ApiCachePolicy.shortCache`。
- 为公共配置、分类接口显式标注 `ApiCachePolicy.longCache`。
- 账号切换后如需主动清空内存缓存，应把共享 `ApiCacheStore` 接入账号生命周期协调器。
