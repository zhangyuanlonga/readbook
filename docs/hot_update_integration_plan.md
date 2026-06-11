# 热更新接入方案建议

创建时间：2026-06-10  
适用场景：小修小改快速发布，避免全平台发版

> 接入完成后的日常发版、热更新和全能签无签名 IPA 流程，以 [版本发布决策指南](version_release_decision_guide.md) 的“发布流程”为准；本文保留方案背景和接入说明。

## 1. 方案选型

### 推荐方案：Shorebird

**为什么选 Shorebird？**
- ✅ Flutter 团队核心成员创建
- ✅ 对现有代码零侵入
- ✅ 免费层足够使用

**官网：** https://shorebird.dev

---

### 平台支持情况

| 平台 | Shorebird 支持 | 说明 |
|-----|---------------|------|
| **Android** | ✅ 完全支持 | 生产可用 |
| **iOS** | ✅ 完全支持 | 生产可用 |
| **macOS** | ✅ 实验性支持 | 可用，但标记为 preview |
| **Windows** | ❌ 不支持 | 官方未实现 |
| **Linux** | ❌ 不支持 | 官方未实现 |
| **Web** | ❌ 不支持 | Web 不需要热更新（直接更新服务器） |

**结论：**
- **移动端（Android + iOS）：** 完全支持，推荐使用 ⭐
- **桌面端（macOS）：** 实验性支持，可以尝试 ⚠️
- **桌面端（Windows/Linux）：** 不支持，需传统发版 ❌
- **Web：** 不需要（直接更新部署即可） ✅

---

### 各平台热更新价值分析

#### 📱 移动端（Android + iOS）

**价值：⭐⭐⭐⭐⭐ 非常高**

**原因：**
- 应用商店审核周期长（iOS 1-7天，Android 1-3天）
- 用户更新不及时
- 紧急bug修复需要快速响应

**使用场景：**
- 内测阶段：快速迭代，无需重新签名分发
- 正式上架：bug修复、文案调整

---

#### 🖥️ 桌面端

##### macOS：实验性支持 ⚠️

**价值：⭐⭐⭐ 中等**

**当前状态：**
- Shorebird 标记为 preview（预览版）
- 可以使用，但不保证稳定性

**使用建议：**
- 可以尝试接入
- 用于内部测试
- 生产环境谨慎使用

**接入方式：**
```bash
# macOS 热更新（实验性）
shorebird release macos
shorebird patch macos
```

##### Windows/Linux：不支持 ❌

**价值：⭐ 需求低**

**原因：**
- Shorebird 官方未实现
- 桌面端用户习惯手动更新
- 可以使用应用内自动更新

**替代方案：**
1. **应用内自动更新（推荐）**
   - 检测新版本
   - 下载安装包
   - 提示用户重启

2. **GitHub Releases**
   - 发布新版本到 GitHub
   - 用户手动下载更新

3. **第三方工具**
   - Windows：使用 Squirrel.Windows
   - Linux：使用 AppImage 自动更新

---

#### 🌐 Web：不需要热更新 ✅

**原因：**
- Web 应用直接部署到服务器
- 用户刷新页面即获得最新版本
- 无需热更新机制

**Web 更新流程：**
```bash
# 构建
flutter build web --release

# 部署到服务器
# 用户刷新页面 → 自动更新
```

---

### 推荐接入策略

#### 阶段1：移动端优先（立即执行）

**接入平台：**
- ✅ Android（必须）
- ✅ iOS（必须）

**理由：**
- 移动端是主战场
- 热更新价值最高
- 技术成熟稳定

---

#### 阶段2：macOS 尝试（可选）

**接入平台：**
- ⚠️ macOS（实验性）

**理由：**
- 可以尝试，降低桌面端更新成本
- 标记为 preview，谨慎使用
- 用于内部测试

**接入方式：**
```bash
# 初始化时启用 macOS
shorebird init --platforms=android,ios,macos

# 或者后续添加
shorebird release macos
```

---

#### 阶段3：Windows/Linux 传统方案（当前）

**不使用 Shorebird，使用传统方案：**

1. **应用内自动更新**
2. **GitHub Releases**
3. **手动下载更新**

---

### 实际使用场景

#### 你们项目的情况

**平台分布（估算）：**
- Android：50-60%
- iOS：30-40%
- Windows：5-10%
- macOS：1-3%
- Linux：<1%
- Web：待定

**推荐策略：**
1. **立即接入：** Android + iOS（覆盖 80-90% 用户）
2. **可选尝试：** macOS（覆盖额外 1-3%）
3. **传统方案：** Windows/Linux（应用内更新）
4. **Web：** 直接部署更新

---

## 2. Shorebird 工作原理

### 2.1 核心机制

```text
构建时：
  Flutter代码 → Dart AOT → 生成基线版本
  
热更新时：
  新Dart代码 → 生成patch → 上传Shorebird服务器
  
用户侧：
  启动应用 → 检查更新 → 下载patch → 应用patch → 重启生效
```

### 2.2 能更新什么

✅ **可以热更新：**
- Dart 业务逻辑代码
- UI 布局和样式
- 文案修改
- 小bug修复
- 配置调整

❌ **不能热更新：**
- 原生代码（Swift/Kotlin/Java）
- 插件原生部分
- 资源文件（图片、字体）需谨慎
- AndroidManifest / Info.plist
- 权限变更

---

## 3. 接入步骤

### 阶段1：准备工作（1天）

#### 3.1 注册 Shorebird 账号

- [ ] 访问 https://console.shorebird.dev
- [ ] 使用 Google 账号登录
- [ ] 创建 Organization
- [ ] 获取 API Token

#### 3.2 安装 Shorebird CLI

```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# 验证安装
shorebird --version
```

#### 3.3 登录 Shorebird

```bash
shorebird login
```

---

### 阶段2：项目配置（半天）

#### 3.4 初始化项目

```bash
cd /Users/zhangyuanlong/storage/FlutterProject/flutterreadbook
shorebird init
```

**会生成：**
- `shorebird.yaml` - 配置文件
- `.shorebird/` 目录 - 缓存和配置

#### 3.5 配置 shorebird.yaml

```yaml
# shorebird.yaml
app_id: your-app-id-here  # 自动生成

# Android 和 iOS 都支持
platforms:
  android: true
  ios: true
```

---

### 阶段3：首次发布（1天）

#### 3.6 构建基线版本（Android）

```bash
# Release APK，同时生成可上传/备份的 AAB
shorebird release android \
  --artifact apk \
  --build-name 1.3.0 \
  --build-number 26061101
```

**注意：**
- 首次发布会生成基线版本
- 记录 release version（如 1.3.0+26061101）
- 移动端正式分发包必须来自 `shorebird release`，不能用普通 `flutter build` 产物代替基线

#### 3.7 构建基线版本（iOS）

```bash
# iOS Release；项目当前不使用本机签名，后续交给全能签
shorebird release ios \
  --no-codesign \
  --build-name 1.3.0 \
  --build-number 26061101
```

**iOS 内测阶段：**
- `--no-codesign` 会生成 `.xcarchive`，Shorebird 会跳过 IPA
- 需要按 [版本发布决策指南](version_release_decision_guide.md) 从 `.xcarchive` 手动封未签名 IPA
- 未签名 IPA 交给全能签签名并分发给用户

**iOS 特殊说明：**
- 本机不需要 Apple Developer 账号或 Provisioning Profile 才能生成未签名基线包
- 首次构建时间较长

---

### 阶段4：发布热更新（10分钟）

#### 3.8 修改代码

```dart
// 示例：修改文案
// lib/features/mine/presentation/settings_page.dart
Text('设置') → Text('应用设置')
```

#### 3.9 发布 patch

```bash
shorebird patch \
  --platforms=android,ios \
  --release-version=1.3.0+26061101 \
  --no-codesign
```

**发布后：**
- patch 自动上传到 Shorebird 服务器
- 用户下次启动时自动检查更新
- 下载 patch（通常几百 KB）
- 重启后生效
- **iOS 内测用户无需重新签名安装！** ⭐

---

## 4. 项目集成建议

### 4.1 更新策略

#### 推荐：后台静默下载

```dart
// lib/app/startup/app_startup_coordinator.dart

Future<void> _checkHotUpdate() async {
  // Shorebird 会自动在后台检查和下载
  // 下次启动时自动应用
  // 无需任何代码，开箱即用
}
```

#### 可选：主动检查并提示

```dart
import 'package:shorebird_code_push/shorebird_code_push.dart';

class UpdateService {
  final _shorebird = ShorebirdCodePush();
  
  Future<void> checkForUpdate() async {
    // 检查是否有更新
    final isUpdateAvailable = await _shorebird.isNewPatchAvailableForDownload();
    
    if (isUpdateAvailable) {
      // 显示提示："发现新版本，是否立即更新？"
      final shouldUpdate = await _showUpdateDialog();
      
      if (shouldUpdate) {
        // 下载 patch
        await _shorebird.downloadUpdateIfAvailable();
        
        // 提示重启
        await _showRestartDialog();
      }
    }
  }
  
  Future<bool> _showUpdateDialog() async {
    // 显示更新对话框
    return true; // 用户点击"更新"
  }
  
  Future<void> _showRestartDialog() async {
    // 提示"更新完成，请重启应用"
    // 或者自动重启：Restart.restartApp();
  }
}
```

### 4.2 版本管理策略

#### 建议的版本发布流程

```text
1. 大版本更新（需要全平台发版）
   - 新功能上线
   - 原生代码变更
   - 插件升级
   - 权限变更
   → 使用正常发版流程（App Store / Google Play）

2. 小版本更新（使用热更新）
   - 文案修改
   - UI 微调
   - 小bug修复
   - 配置调整
   → 使用 Shorebird patch

3. 紧急修复（使用热更新）
   - 线上严重bug
   - 用户体验问题
   - 不能等审核的修复
   → 使用 Shorebird patch
```

---

## 5. 最佳实践

### 5.1 适合热更新的场景 ✅

1. **文案修正**
   - 错别字修复
   - 提示语优化
   - 多语言翻译调整

2. **UI微调**
   - 间距调整
   - 颜色调整
   - 布局微调

3. **小bug修复**
   - 空指针异常
   - 逻辑错误
   - 数据展示问题

4. **配置调整**
   - API地址切换
   - 功能开关
   - 默认值调整

5. **A/B测试**
   - 不同版本快速切换
   - 灰度发布

### 5.2 不适合热更新的场景 ❌

1. **原生功能变更**
   - 添加权限
   - 原生插件升级
   - AndroidManifest 变更

2. **重大功能上线**
   - 新模块开发
   - 架构调整
   - 数据库表变更

3. **资源文件变更**
   - 大量图片更新
   - 字体文件更新
   - 资源包更新

### 5.3 风险控制

#### 回滚机制

```bash
# 列出所有 patch
shorebird patch list

# 回滚到之前的版本
shorebird patch promote <patch-number>
```

#### 灰度发布

```bash
# 发布给 10% 用户
shorebird patch android --staging-percentage 10

# 观察24小时无问题后全量
shorebird patch android --staging-percentage 100
```

#### 监控

- [ ] 在 Shorebird Console 监控 patch 下载率
- [ ] 监控崩溃率是否上升
- [ ] 收集用户反馈
- [ ] 发现问题立即回滚

---

## 6. 成本评估

### 6.1 Shorebird 定价

**免费层（推荐起步）：**
- 每月 5,000 次 patch 下载
- 适合中小规模应用
- 无限次 patch 发布

**Pro 层（$20/月）：**
- 每月 25,000 次下载
- 团队协作功能
- 优先支持

**Enterprise 层（定制）：**
- 无限次下载
- 私有部署
- SLA 保障

### 6.2 开发成本

- 初始接入：1-2天
- 每次热更新发布：10-15分钟
- 维护成本：几乎为零

---

## 7. 实施计划

### 第1周：试点验证

- [ ] 接入 Shorebird（阶段1-3）
- [ ] 在测试环境验证
- [ ] 发布一个简单的文案修改 patch
- [ ] 验证更新流程

### 第2周：正式上线

- [ ] 构建基线版本并发布到应用商店
- [ ] 等待审核通过
- [ ] 记录 release version

### 第3周开始：日常使用

- [ ] 小修改使用热更新
- [ ] 大版本使用正常发版
- [ ] 建立热更新发布流程

---

## 8. 注意事项

### 8.1 应用商店政策

**App Store（iOS）：**
- ✅ 允许热更新 bug 修复和微小改进
- ❌ 不允许改变应用核心功能
- ❌ 不允许绕过审核添加新功能
- **Shorebird 符合政策**：只更新 Dart 代码，不修改原生

**Google Play（Android）：**
- ✅ 政策相对宽松
- ✅ 允许代码热更新
- **Shorebird 符合政策**

### 8.2 技术限制

1. **首次需要全量发布**
   - 必须先发布基线版本到应用商店
   - 后续才能使用热更新

2. **patch 大小限制**
   - 每个 patch 建议 < 10MB
   - 过大会影响下载体验

3. **Flutter 版本兼容**
   - 确保 Shorebird 支持你的 Flutter 版本
   - 当前支持 Flutter 3.0+

### 8.3 最佳实践

- ✅ 热更新前在测试环境充分测试
- ✅ 记录每次 patch 的变更内容
- ✅ 监控更新成功率和崩溃率
- ✅ 准备回滚预案
- ❌ 不要在热更新中包含高风险变更
- ❌ 不要依赖热更新解决所有问题

---

## 9. 与现有改造计划的结合

### 9.1 配合存储治理

热更新非常适合配合存储治理改造：

1. **阶段1紧急修复**
   - 登出清理逻辑修复 → 热更新
   - 数据健康检查 → 需要发版（新增功能）

2. **阶段2缓存治理**
   - 缓存清理参数调整 → 热更新
   - 新增清理入口 → 需要发版

3. **配置调整**
   - API地址切换 → 热更新
   - 缓存过期时间调整 → 热更新

### 9.2 配合 API 治理

1. **拦截器逻辑微调** → 热更新
2. **新增拦截器** → 需要发版
3. **401 处理优化** → 热更新

---

## 10. 总结

### 推荐接入 Shorebird 的理由

1. ✅ **快速修复线上问题**
   - 10分钟发布修复
   - 用户无感知更新
   - 不用等应用商店审核

2. ✅ **降低发版成本**
   - 小修改不需要全平台发版
   - 节省审核时间
   - 提升用户体验

3. ✅ **风险可控**
   - 支持回滚
   - 支持灰度
   - 监控完善

4. ✅ **接入简单**
   - 1-2天完成接入
   - 对现有代码零侵入
   - 开箱即用

### 不接入的风险

- ❌ 小bug修复需要等待1-7天审核
- ❌ 用户体验受影响
- ❌ 紧急问题无法快速响应

### 建议

**立即接入！** 投入1-2天时间，长期受益。

---

## 相关文档

- Shorebird 官方文档：https://docs.shorebird.dev
- Flutter 热更新最佳实践：https://flutter.dev/docs/deployment/cd

---

**最后更新：** 2026-06-11
