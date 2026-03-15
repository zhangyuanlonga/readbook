# Backend Mobile Integration Guide

This document captures the current backend integration conventions in the app, using the Announcement module as the canonical reference, plus the new device/reader/auth/analytics flow.

## 0. Shared API Conventions (Reference: Announcement)

The app uses a shared `ApiClient` wrapper with a standard response envelope and error mapping.

### Response Envelope (Required)

All backend responses are expected to be shaped as:

##  开发检查
 每次执行完计划或者进度则需要进行自检
 ```bash
flutter analyze
flutter test
```


```json
{
  "code": "OK",
  "message": "",
  "data": { }
}
```

- `code == "OK"` means success
- Non-OK codes are mapped into `AppException`
- `data` is decoded by the caller

### Base URL

- From `APPREAD_API_BASE_URL`
- Default: `http://localhost:8080`

### Caching

- GET requests can enable cache with TTL (see Announcement service)

### References

- `ApiClient`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/network/api_client.dart`
- `BaseUrl`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/network/api_config.dart`
- `AnnouncementService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/announcement/application/announcement_service.dart`


## 1. Device Heartbeat (Anonymous OK)

Call on cold start and app foreground.

### Request

`POST /v1/devices/heartbeat`

```json
{
  "install_id": "uuid-per-install",
  "device_uid": "hashed-device-id",
  "platform": "android",
  "device_brand": "xiaomi",
  "device_model": "2304FPN6DC",
  "os_version": "14",
  "app_version": "1.2.0"
}
```

### Notes

- Recommended cadence: cold start + app foreground
- If device info unchanged, backend may only update `last_seen_at`
- Response includes `device` object (optional cache)

### App Implementation

- Device identity: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/device/device_identity_service.dart`
- Heartbeat service: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/device/device_heartbeat_service.dart`
- Lifecycle hook: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/app/app.dart`


## 2. Reader Register (Anonymous OK)

Used when reader_id is needed (uploading sources, reading profile).

### Request

`POST /v1/readers/register`

```json
{
  "install_id": "uuid-per-install"
}
```

### Response

- Returns `reader` (the `is_vip` field is reader-level and ignored; account VIP should use `GET /v1/users/me`)

### Compatibility

- `readers/register` no longer accepts device fields

### App Implementation

- Reader identity: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/reader/reader_identity_service.dart`
- Cached keys: `reader.id` (SharedPreferences)


## 3. Login / Register

### Request

`POST /v1/auth/login`

```json
{
  "username": "user001",
  "password": "passw0rd",
  "install_id": "uuid-per-install"
}
```

`POST /v1/auth/register`

```json
{
  "username": "user001",
  "password": "passw0rd",
  "install_id": "uuid-per-install"
}
```

### Response

- Returns `access_token`

### App Implementation

- Auth service: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_service.dart`
- Session store: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_session_store.dart`


## 4. Bind Device After Login

### Request

`POST /v1/auth/bind-device`

Header:

```
Authorization: Bearer <access_token>
```

Body:

```json
{
  "install_id": "uuid-per-install"
}
```

### Result

- Success: device bound to account, historical stats merged
- `409 Conflict`: device already bound to another account, prompt user

### App Implementation

- `AuthService.bindDevice(...)`


## 5. User Profile (Logged In)

`GET /v1/users/me`

### Response fields

- `user_id` `username` `created_at` `vip_level` `plan_type` `vip_status` `vip_expire_at` `features`

### App Implementation

- User profile service: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/user/user_profile_service.dart`
- Profile UI: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/auth/presentation/user_profile_page.dart`


## 6. Analytics Events (Anonymous or Logged In)

Continue existing event reporting logic.

### Request

`POST /v1/analytics/visit`

```json
{
  "install_id": "uuid-per-install",
  "user_id": "usr_xxx",
  "reader_id": "r_xxx",
  "platform": "android",
  "channel": "stable",
  "app_version": "1.2.3",
  "occurred_at": "2026-03-15T08:00:00Z"
}
```

### Notes

- `install_id` is required
- When logged in, include `user_id` and `reader_id`

### App Implementation

- Analytics service: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/analytics/analytics_service.dart`
- Lifecycle hook: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/app/app.dart`


## 7. App Updates (Anonymous)

`POST /v1/app-updates/check`

```json
{
  "platform": "all",
  "channel": "stable",
  "version_code": 10012,
  "install_id": "uuid-per-install"
}
```

### App Implementation

- Update service: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/app_update/app_update_service.dart`
- About page UI: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/mine/presentation/about_page.dart`

## 8. Token Refresh (401)

`POST /v1/auth/refresh`

```json
{ "refresh_token": "<refresh_token>" }
```

### App Implementation

- Refresh API: `AuthService.refresh(...)`
- Auto refresh on 401: `ApiClient` internal logic (when `enableAuthRefresh` is true)
- Refresher adapter: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_token_refresher_impl.dart`

## 9. Logout

`POST /v1/auth/logout`

```json
{ "refresh_token": "<refresh_token>" }
```

### App Implementation

- `AuthService.logout(...)`

## 10. Compatibility Reminders (Must Tell Mobile)

- `POST /v1/readers/register` only accepts `install_id`
- Device info must go to `POST /v1/devices/heartbeat`


## 11. Reference: Announcement Integration (Working Example)

Use this as the template for new backend endpoints.

### Endpoints

- `GET /v1/announcements`
- `GET /v1/announcements/latest`
- `GET /v1/announcements/:id`

### Features

- Cache for GET requests
- Model decode in domain layer
- Read-state persistence in SharedPreferences

### References

- `AnnouncementService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/announcement/application/announcement_service.dart`
- `Announcement models`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/domain/entities/announcement.dart`
- `Read state`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/announcement/application/announcement_read_state_service.dart`
- `Startup dialog`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/app/app.dart`


## 12. Implementation Checklist (Suggested)

- Create services that mirror `AnnouncementService` structure
- Use `ApiClient` for all requests
- Keep response envelope handling consistent
- Add basic caching only for GETs
- Store lightweight state via SharedPreferences when needed


## 后端接入计划

 确认 APPREAD_API_BASE_URL 在各环境的配置方式与默认值
 设备心跳服务封装 POST /v1/devices/heartbeat
 冷启动与前后台切换时机接入心跳上报
 reader 注册服务封装 POST /v1/readers/register
 需要 reader_id 的业务点梳理并接入调用
 登录/注册服务封装 POST /v1/auth/login
 登录成功后绑定设备 POST /v1/auth/bind-device
 处理 409 Conflict 绑定冲突提示方案
 事件上报补齐 install_id + user_id/reader_id
 响应 envelope 解析与错误映射保持一致
 API 调用埋点/日志（若有统一日志标准）
登录/注册页面计划

 确认登录/注册是单页切换还是两个页面
 确认是否需要验证码登录
 将现有顶部卡片样式迁移为登录/注册入口
 表单校验与错误提示样式对齐现有 UI
 登录成功后的状态刷新与路由跳转
 绑定设备调用与失败提示接入
 与 reader 注册流程的衔接策略确认
## 测试计划

 API 服务单元测试（或最小冒烟测试）
 登录/绑定设备流程手测
 事件上报的请求体字段核对

## 执行状态（当前项目）

- [x] 设备心跳服务已封装并接入 App 冷启动/前后台切换
- [x] 设备字段采集（install_id/device_uid/platform/brand/model/os/app_version）
- [x] Reader 注册服务封装（未强制在启动时调用）
- [x] 登录/绑定设备服务封装并接入登录页
- [x] Analytics Visit 事件上报服务封装并接入生命周期（代替 app-open）
- [x] 登录/注册 UI 页面实现与绑定流程串联
- [x] Token refresh + logout + analytics/visit 接口封装
- [x] 用户信息接口封装并展示在账号信息页
- [x] 检查更新接口封装并在关于页可触发
