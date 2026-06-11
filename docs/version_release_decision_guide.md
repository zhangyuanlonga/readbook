# 版本发布决策指南

创建时间：2026-06-10  
用途：每次提交代码后，快速判断应该使用正常发版还是热更新

## 快速决策流程图

```text
代码修改完成
    ↓
是否涉及原生代码？ ──YES──→ 正常发版 ✋
    ↓ NO
是否涉及插件升级？ ──YES──→ 正常发版 ✋
    ↓ NO
是否涉及权限变更？ ──YES──→ 正常发版 ✋
    ↓ NO
是否涉及资源文件变更？ ──YES──→ 正常发版 ✋
    ↓ NO
是否涉及数据库表变更？ ──YES──→ 正常发版 ✋
    ↓ NO
是否是新功能上线？ ──YES──→ 正常发版 ✋
    ↓ NO
    ↓
使用热更新 🚀
```

---

## 决策表格（快速查询）

| 变更类型 | 示例 | 发版方式 | 原因 |
|---------|------|---------|------|
| **原生代码** | Swift/Kotlin 修改 | 正常发版 | 热更新不支持原生 |
| **原生插件** | 升级 camera 插件 | 正常发版 | 插件包含原生代码 |
| **权限变更** | 添加相机权限 | 正常发版 | 需要修改 Manifest/Info.plist |
| **资源文件** | 更换启动图、字体 | 正常发版 | 资源包打包在 APK/IPA 中 |
| **数据库表** | 新增表或列 | 正常发版 | 需要迁移逻辑 |
| **新功能** | 新增阅读模式 | 正常发版 | 重大功能变更 |
| **文案修改** | 错别字、提示语 | 热更新 🚀 | 纯 Dart 代码 |
| **UI微调** | 间距、颜色调整 | 热更新 🚀 | 纯 Dart 代码 |
| **小bug修复** | 空指针、逻辑错误 | 热更新 🚀 | 纯 Dart 代码 |
| **配置调整** | API地址、开关 | 热更新 🚀 | 纯 Dart 代码 |
| **业务逻辑** | 计算逻辑优化 | 热更新 🚀 | 纯 Dart 代码 |

---

## 详细判断标准

### ✋ 必须使用正常发版

#### 1. 原生代码变更
```text
❌ 修改了以下文件：
  - android/app/src/ 下的 Kotlin/Java 文件
  - ios/Runner/ 下的 Swift/Objective-C 文件
  - android/app/build.gradle
  - ios/Podfile
```

**示例：**
- 添加原生推送功能
- 修改应用图标
- 调整原生启动页

#### 2. 插件升级或新增
```text
❌ pubspec.yaml 中插件变更：
  - 升级插件版本（如 camera: ^0.10.0 → ^0.11.0）
  - 新增插件（如添加 video_player）
  - 删除插件
```

**示例：**
- 升级 `image_picker` 插件
- 新增 `flutter_local_notifications` 插件

#### 3. 权限变更
```text
❌ 修改了：
  - android/app/src/main/AndroidManifest.xml（权限）
  - ios/Runner/Info.plist（权限）
```

**示例：**
- 添加相机权限
- 添加定位权限
- 添加通知权限

#### 4. 资源文件变更
```text
❌ 修改了：
  - assets/ 下的图片、字体等
  - pubspec.yaml 中的 assets 声明
  - android/app/src/main/res/ 下的资源
```

**示例：**
- 更换应用图标
- 添加新字体文件
- 更新启动图

#### 5. 数据库 schema 变更
```text
❌ 修改了：
  - lib/data/datasources/local/app_database.dart 中的表结构
  - 新增表、新增列、修改列类型
  - 需要数据迁移
```

**示例：**
- 添加新表 `user_preferences`
- 为 `books` 表添加 `rating` 列
- 修改 `created_at` 类型

#### 6. 重大功能上线
```text
❌ 新增：
  - 全新模块（如新增"听书"功能）
  - 重大功能（如新增"社区"模块）
  - 架构调整（如重构阅读器）
```

**示例：**
- 新增听书功能
- 新增社区模块
- 新增云同步功能

---

### 🚀 可以使用热更新

#### 1. 文案修改
```dart
// ✅ 可以热更新
Text('设置') → Text('应用设置')
'登录成功' → '欢迎回来'
'确定' → '确认'
```

#### 2. UI样式调整
```dart
// ✅ 可以热更新
padding: EdgeInsets.all(8) → padding: EdgeInsets.all(12)
color: Colors.blue → color: Theme.of(context).primaryColor
fontSize: 14 → fontSize: 16
```

#### 3. 布局微调
```dart
// ✅ 可以热更新
Row → Column
MainAxisAlignment.start → MainAxisAlignment.center
CrossAxisAlignment.start → CrossAxisAlignment.end
```

#### 4. 业务逻辑优化
```dart
// ✅ 可以热更新
if (count > 10) → if (count > 20)
'https://api.old.com' → 'https://api.new.com'
maxRetries = 3 → maxRetries = 5
```

#### 5. 小bug修复
```dart
// ✅ 可以热更新
final user = response['user'];  // 可能空指针
→
final user = response['user'] ?? {};  // 修复

// ✅ 可以热更新
if (list.length > 0)  // 逻辑错误
→
if (list.isNotEmpty)  // 修复
```

#### 6. 配置调整
```dart
// ✅ 可以热更新
static const apiBaseUrl = 'https://api.test.com';
→
static const apiBaseUrl = 'https://api.prod.com';

// ✅ 可以热更新
static const cacheMaxAge = Duration(hours: 1);
→
static const cacheMaxAge = Duration(hours: 2);
```

---

## 实际案例

### 案例1：修复登出清理bug

**变更内容：**
```dart
// lib/features/auth/application/auth_service.dart
Future<void> logout() async {
  await _prefs.remove('auth.user_id');
  await _prefs.remove('auth.username');
  // 新增：清理 secure storage
  await _secureStorage.delete(key: 'auth.access_token');
}
```

**判断：**
- ❓ 原生代码？NO
- ❓ 插件升级？NO
- ❓ 权限变更？NO
- ❓ 资源文件？NO
- ❓ 数据库表？NO
- ❓ 新功能？NO

**结论：🚀 使用热更新**

---

### 案例2：添加相机权限

**变更内容：**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
```

**判断：**
- ❓ 权限变更？YES ✋

**结论：✋ 正常发版**

---

### 案例3：升级 image_picker 插件

**变更内容：**
```yaml
# pubspec.yaml
dependencies:
  image_picker: ^0.8.6 → ^1.0.0
```

**判断：**
- ❓ 插件升级？YES ✋

**结论：✋ 正常发版**

---

### 案例4：调整缓存过期时间

**变更内容：**
```dart
// lib/core/cache/cache_budget_policy.dart
static const chapterCachesStalePeriod = Duration(days: 90);
→
static const chapterCachesStalePeriod = Duration(days: 180);
```

**判断：**
- ❓ 原生代码？NO
- ❓ 插件升级？NO
- ❓ 权限变更？NO
- ❓ 资源文件？NO
- ❓ 数据库表？NO
- ❓ 新功能？NO

**结论：🚀 使用热更新**

---

### 案例5：修改 API 地址

**变更内容：**
```dart
// lib/core/network/api_config.dart
static const baseUrl = 'https://api-test.example.com';
→
static const baseUrl = 'https://api-prod.example.com';
```

**判断：**
- ❓ 原生代码？NO
- ❓ 插件升级？NO
- ❓ 权限变更？NO
- ❓ 资源文件？NO
- ❓ 数据库表？NO
- ❓ 新功能？NO

**结论：🚀 使用热更新**

---

### 案例6：新增数据库列

**变更内容：**
```dart
// lib/data/datasources/local/app_database.dart
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  // 新增列
  RealColumn get rating => real().nullable()();  // ← 新增
}
```

**判断：**
- ❓ 数据库表？YES ✋

**结论：✋ 正常发版**

---

## 边界情况判断

### 情况1：只修改 Dart 代码，但改动很大

**示例：** 重构了整个阅读器渲染逻辑

**判断：**
- 虽然是纯 Dart 代码，但属于重大功能变更
- 建议：✋ 正常发版（风险可控，充分测试）

### 情况2：资源文件很小（如单个小图标）

**示例：** 更换一个 16x16 的小图标

**判断：**
- 仍然属于资源文件变更
- 结论：✋ 正常发版

### 情况3：插件只升级 patch 版本

**示例：** `image_picker: ^1.0.0 → ^1.0.1`

**判断：**
- 仍然是插件变更
- 结论：✋ 正常发版

### 情况4：紧急线上bug，但涉及数据库

**示例：** 数据库查询逻辑错误导致崩溃

**判断：**
- 如果只修改查询逻辑（Dart 代码）→ 🚀 热更新
- 如果需要修改表结构 → ✋ 正常发版

---

## 发布流程

### 当前 Shorebird 基线记录

- Shorebird app：`Selune`
- Shorebird app_id：`8f2dce99-c6fb-48c8-bd98-9d1235665622`
- 当前移动端有效基线：`1.3.0+26061101`
- 历史误发基线：`1.1.0+26041801`

`1.1.0+26041801` 不需要主动删除。旧 release 不会影响 `latest`，也不会影响 `1.3.0+26061101` 后续打 patch；只要后续不要分发旧包、不要对旧 release 发 patch 即可。如果确认没有任何用户安装过旧基线，可以在 Shorebird Console 里按需清理；如果有任何测试用户装过，保留它更安全，因为删除基线可能让该版本失去后续 patch 关系。当前 CLI 没有 `releases delete` 命令。

### 正常发版流程：移动端 Shorebird 基线

适用场景：大版本、小版本、原生/插件/权限/资源/数据库 schema 变更，或需要让用户安装一个新的全量包。

版本号必须高于线上版本，格式固定为 `展示版本+构建号`。例如线上 `1.2.0+26061001`，下一版使用 `1.3.0+26061101`。

```bash
# 1. 确认环境
export PATH="$HOME/.shorebird/bin:$PATH"
shorebird doctor
shorebird account apps

# 2. 更新 pubspec.yaml
# version: 1.3.0+26061101

# 3. Android 基线：生成 APK 和 AAB，并上传 Shorebird release
shorebird release android \
  --artifact apk \
  --build-name 1.3.0 \
  --build-number 26061101

# 4. iOS 基线：不签名，只上传 Shorebird release 并生成 .xcarchive
shorebird release ios \
  --no-codesign \
  --build-name 1.3.0 \
  --build-number 26061101
```

Android 产物位置：

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

iOS 使用全能签时，Shorebird `--no-codesign` 会跳过 IPA，需要从 `.xcarchive` 手动封未签名 IPA：

```bash
VERSION="1.3.0+26061101"
APP_PATH="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
IPA_STAGING="build/ios/unsigned_ipa"
IPA_PATH="build/ios/Selune-unsigned-${VERSION}.ipa"

rm -rf "$IPA_STAGING"
rm -f "$IPA_PATH"
mkdir -p "$IPA_STAGING/Payload"
ditto "$APP_PATH" "$IPA_STAGING/Payload/Runner.app"
(cd "$IPA_STAGING" && zip -qry "../Selune-unsigned-${VERSION}.ipa" Payload)

# 应输出：code object is not signed at all
codesign -dv --verbose=4 "$IPA_STAGING/Payload/Runner.app" 2>&1 || true
```

发给用户安装的是：

```text
Android APK: build/app/outputs/flutter-apk/app-release.apk
iOS unsigned IPA: build/ios/Selune-unsigned-1.3.0+26061101.ipa
```

### 正常发版流程：桌面端传统包

Shorebird 当前用于移动端基线。macOS 是 preview，Windows/Linux 不支持。桌面端仍使用统一脚本走传统全量发版：

```bash
FULL_VERSION=1.3.0+26061101 \
./scripts/build_unified_artifacts.sh macos release
```

如需一次性打非 Shorebird 的传统全平台包，仍可使用：

```bash
FULL_VERSION=1.3.0+26061101 \
./scripts/build_unified_artifacts.sh android,ios,macos release
```

注意：传统脚本打出的 Android/iOS 包可以安装，但不会自动成为 Shorebird 可 patch 的基线。移动端正式分发包优先使用 `shorebird release` 产物。

### 热更新流程：移动端 patch

适用场景：已经有用户安装了当前 Shorebird 基线，只改 Dart 业务逻辑、UI、文案、接口策略等，不改原生、插件、资源和数据库 schema。

```bash
# 1. 确认当前线上基线
export PATH="$HOME/.shorebird/bin:$PATH"
shorebird releases list

# 2. 发布 patch 到当前移动端基线
shorebird patch \
  --platforms=android,ios \
  --release-version=1.3.0+26061101 \
  --no-codesign

# 3. 验证 patch 列表和 Console 下载/错误数据
shorebird patches list --release-version=1.3.0+26061101
```

发布 patch 后，用户下次启动会自动检查和下载；通常需要重启应用后生效。iOS 内测用户不需要重新全能签安装。

### 发布后校验

```bash
shorebird doctor
shorebird releases list

# Android APK 版本
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | head

# iOS unsigned IPA 中 .app 的版本和显示名
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' \
  build/ios/unsigned_ipa/Payload/Runner.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  build/ios/unsigned_ipa/Payload/Runner.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
  build/ios/unsigned_ipa/Payload/Runner.app/Info.plist

# iOS 未签名状态
codesign -dv --verbose=4 build/ios/unsigned_ipa/Payload/Runner.app 2>&1 || true
```

---

## 检查清单

### 每次提交前自查

- [ ] 我修改了哪些文件？
- [ ] 是否涉及原生代码？
- [ ] 是否涉及插件变更？
- [ ] 是否涉及权限变更？
- [ ] 是否涉及资源文件？
- [ ] 是否涉及数据库表结构？
- [ ] 是否是重大功能上线？

**如果以上全部为 NO → 🚀 热更新**  
**如果任意一项为 YES → ✋ 正常发版**

---

## 特殊情况处理

### 同时有正常发版和热更新的需求

**场景：** 
- 新功能需要正常发版
- 旧版本有紧急bug需要修复

**处理：**
1. 为新功能创建 release branch
2. 为紧急修复使用 hotfix branch
3. hotfix 使用热更新发布到当前线上版本
4. release 正常发版

```bash
# hotfix（热更新）
git checkout -b hotfix/login-bug
# 修复bug
shorebird patch \
  --platforms=android,ios \
  --release-version=1.3.0+26061101 \
  --no-codesign

# release（正常发版）
git checkout -b release/v1.4.0
# 开发新功能
shorebird release android \
  --artifact apk \
  --build-name 1.4.0 \
  --build-number 26070001
shorebird release ios \
  --no-codesign \
  --build-name 1.4.0 \
  --build-number 26070001
```

---

## 总结

### 记住这个原则

**能用热更新的就用热更新 🚀**  
**必须正常发版的才发版 ✋**

### 快速记忆

- 纯 Dart 代码修改 → 🚀 热更新
- 涉及原生/插件/权限/资源 → ✋ 正常发版
- 不确定时 → 看决策表格

### 每次发布前问自己

"这个改动涉及原生层吗？"
- YES → 正常发版
- NO → 热更新

---

## 相关文档

- [热更新接入方案](hot_update_integration_plan.md)
- [项目文档总索引](README.md)

---

**最后更新：** 2026-06-11
