# 热更新接入方案建议

创建时间：2026-06-10  
适用场景：小修小改快速发布，避免全平台发版

## 1. 方案选型

### 推荐方案：Shorebird（Flutter 官方背书）

**为什么选 Shorebird？**
- ✅ Flutter 团队核心成员创建
- ✅ 支持 Android / iOS
- ✅ 不违反 App Store 政策（只更新 Dart 代码）
- ✅ 对现有代码零侵入
- ✅ 免费层足够使用

**官网：** https://shorebird.dev

### 不推荐方案

❌ **CodePush（微软）**
- 主要为 React Native 设计
- Flutter 支持不完善

❌ **自建热更新**
- 开发成本高
- 维护成本高
- 容易违反应用商店政策

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

# 可选：自定义配置
# auto_update: true        # 启动时自动检查更新
# update_url: https://...  # 自定义更新服务器（可选）
```

---

### 阶段3：首次发布（1天）

#### 3.6 构建基线版本（Android）

```bash
# Release APK
shorebird release android

# 或者 AAB（Google Play）
shorebird release android --artifact aab
```

**注意：**
- 首次发布会生成基线版本
- 记录 release version（如 1.0.0+1）
- 这个版本需要发布到应用商店

#### 3.7 构建基线版本（iOS）

```bash
# iOS Release
shorebird release ios

# 需要配置签名
# 使用 Xcode 打开项目配置签名
```

**iOS 特殊说明：**
- 需要 Apple Developer 账号
- 需要配置 Provisioning Profile
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
# Android patch
shorebird patch android

# iOS patch
shorebird patch ios
```

**发布后：**
- patch 自动上传到 Shorebird 服务器
- 用户下次启动时自动检查更新
- 下载 patch（通常几百 KB）
- 重启后生效

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

**最后更新：** 2026-06-10