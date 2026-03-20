# Backend Mobile Integration Guide

This document records the backend contract that the Flutter client currently follows after the March 2026 mobile API migration.

## Development Check

Run a quick self-check after finishing integration work:

```bash
flutter analyze
flutter test
```

## 1. Shared Conventions

### Unified Response Envelope

All backend responses use:

```json
{
  "code": "OK",
  "message": "success",
  "data": {}
}
```

- `code == "OK"` means success
- non-OK responses are converted into `ApiException` / `AppException`
- callers only decode the unwrapped `data`

Reference:

- `ApiClient`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/network/api_client.dart`

### Authorization

All authenticated APIs use:

```http
Authorization: Bearer <access_token>
```

References:

- `AuthSessionStore`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_session_store.dart`
- `AuthTokenRefresherImpl`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_token_refresher_impl.dart`

### Time Format

All API time fields use UTC RFC3339, for example:

```text
2027-03-15T00:00:00Z
```

Reference:

- `api_time.dart`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/network/api_time.dart`

### Local Persistence

The client persists these values:

- `install_id`
- `access_token`
- `refresh_token`
- `user_id`

References:

- `DeviceIdentityService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/device/device_identity_service.dart`
- `AuthSessionStore`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_session_store.dart`

## 2. Recommended Access Order

Recommended mobile integration order:

1. Cold start: `POST /v1/devices/heartbeat`
2. Login or register: `POST /v1/auth/login` / `POST /v1/auth/register`
3. After auth success: persist tokens, then trigger `devices/heartbeat` and `analytics/visit`
4. Fetch current user when entering the account page: `GET /v1/users/me`
5. Pull announcements: `GET /v1/announcements` or `GET /v1/announcements/latest`
6. Check updates: `POST /v1/app-updates/check`
7. Report analytics on startup and resume: `POST /v1/analytics/visit`

Current app entry points:

- startup lifecycle: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/app/app.dart`
- auth flow: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_service.dart`
- auth page: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/auth/presentation/auth_page.dart`
- profile page: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/auth/presentation/user_profile_page.dart`

Note:

- the old device-binding flow is no longer part of the mobile client
- login and register no longer send `install_id`

## 3. Endpoint Mapping

### Device Heartbeat

`POST /v1/devices/heartbeat`

Request body:

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

Client notes:

- call on cold start
- call again on app foreground
- the client keeps `install_id` stable per installation

References:

- `DeviceIdentityService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/device/device_identity_service.dart`
- `DeviceHeartbeatService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/device/device_heartbeat_service.dart`

### Login

`POST /v1/auth/login`

Request body:

```json
{
  "username": "user001",
  "password": "passw0rd"
}
```

### Register

`POST /v1/auth/register`

Request body:

```json
{
  "username": "user001",
  "password": "passw0rd"
}
```

Shared response fields used by the client:

- `user_id`
- `username`
- `access_token`
- `access_expires_at`
- `refresh_token`
- `refresh_expires_at`

Client notes:

- login/register only issue tokens
- post-auth heartbeat and analytics are triggered by `AuthService`

References:

- `AuthService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_service.dart`
- `AuthSession`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_session.dart`
- `AuthPage`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/auth/presentation/auth_page.dart`

### Token Refresh

`POST /v1/auth/refresh`

Request body:

```json
{
  "refresh_token": "<refresh_token>"
}
```

Client notes:

- used automatically after `401` when refresh is enabled
- on refresh failure, local session is cleared and the user is sent back to login

References:

- `AuthService.refresh(...)`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_service.dart`
- `AuthTokenRefresherImpl`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_token_refresher_impl.dart`

### Logout

`POST /v1/auth/logout`

Request body:

```json
{
  "refresh_token": "<refresh_token>"
}
```

Client notes:

- logout clears local session
- `install_id` is retained locally

Reference:

- `AuthService.logout(...)`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/auth/auth_service.dart`

### Current User

`GET /v1/users/me`

Response shape used by the client:

```json
{
  "user": {
    "user_id": "usr_xxx",
    "username": "user001",
    "role": "user",
    "created_at": "2026-03-15T08:00:00Z",
    "vip_level": "pro",
    "plan_type": "year",
    "vip_status": "active",
    "vip_expire_at": "2027-03-15T00:00:00Z",
    "features": ["theme_custom", "online_service"]
  }
}
```

Client usage:

- account information page
- VIP information
- feature display through `features`

References:

- `UserProfileService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/user/user_profile_service.dart`
- `UserProfile`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/user/user_profile.dart`
- `UserProfilePage`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/auth/presentation/user_profile_page.dart`

### Analytics Visit

`POST /v1/analytics/visit`

Request body:

```json
{
  "install_id": "uuid-per-install",
  "platform": "android",
  "channel": "stable",
  "app_version": "1.2.3",
  "visit_count": 1,
  "visit_seconds": 0,
  "occurred_at": "2026-03-14T12:00:00Z"
}
```

Client notes:

- anonymous analytics rely on `install_id`
- authenticated analytics additionally attach `Authorization`
- current client reports visit on startup, resume, and post-auth bootstrap

Reference:

- `AnalyticsService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/analytics/analytics_service.dart`

### Announcements

Endpoints:

- `GET /v1/announcements?page=1&page_size=20`
- `GET /v1/announcements/latest`
- `GET /v1/announcements/:id`

Client notes:

- `AnnouncementService` is the reference implementation for standard GET APIs
- latest announcement is prefetched during startup

References:

- `AnnouncementService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/announcement/application/announcement_service.dart`
- `Announcement models`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/domain/entities/announcement.dart`

### App Update Check

`POST /v1/app-updates/check`

Request body:

```json
{
  "app_name": "reader-app",
  "version_code": 10012
}
```

Response fields used by the client:

- `has_update`
- `force_update`
- `latest_version.version_code`
- `latest_version.download_url`
- `latest_version.changelog`

Client notes:

- `app_version` remains the display version, for example `1.0.6`
- `version_code` must be an integer compare key
- do not send `install_id`
- do not rely on `min_supported_code`
- current client normalizes `major.minor.patch` into `major * 10000 + minor * 100 + patch`
- for example `1.0.6 -> 10006`

References:

- `AppUpdateService`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/app_update/app_update_service.dart`
- `AppUpdateCheckResult`: `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/core/app_update/app_update_check_result.dart`
