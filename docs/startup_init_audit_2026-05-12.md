# 启动与初始化链路梳理（2026-05-12）

## 目标

整理应用在冷启动、首帧后初始化、恢复前台时会发生的本地读取、计算和服务端请求，区分：

- 必要且轻量：保留
- 必要但可优化：改造实现方式
- 非必要或时机不对：延后、降频或移除

## 一、首帧前同步读取

入口文件：[lib/app/bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart)

当前会做的事情：

- `SharedPreferences.getInstance()`
- 各类 UI 配置 `prime(prefs)`：
  - 导航样式
  - 导航文字显示
  - 标准底栏外观
  - 苹果底栏外观
  - 主题模式
  - 种子色
  - 当前高级主题 id
  - 我的页会话
  - 界面字体 / 缩放 / 字重
  - 我的页显示项
  - 我的页启动默认页
- 启动图开关 `StartupArtworkStore.primeStartupEnabledSync(prefs)`

判断：

- 这一层大部分是轻量键值读取，属于合理保留。
- 这里没有明显的“无用服务器请求”。

建议：

- 保留这层同步 prime，不建议为了“更纯粹”去掉，否则只会把首屏稳定配置变成首屏闪动。

## 二、首帧后本地任务

入口文件：

- [lib/app/bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart)
- [lib/app/startup/app_startup_coordinator.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/app_startup_coordinator.dart)

### 2.1 `StartupArtworkStore.prime()`

文件：[lib/app/startup_artwork_store.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup_artwork_store.dart)

当前行为：

- 首帧后异步执行
- 读取启动图服务
- 读取当前高级主题
- 根据 `theme.launchImageGalleryId` 解析启动图路径

风险：

- 启动图依赖完整主题读取
- 主题和启动图绑定导致冷启动行为与原生启动页不一致
- 这条链路与真正的“原生冷启动”脱节

建议：

- 保留“启动图预热”功能
- 移除“启动时读取主题后再解析图集”的行为
- 改成“主题应用时预计算启动图快照，启动时只读快照”

### 2.2 文件路径根目录预热

文件：[bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart)

当前行为：

- `ManagedFilePathResolver.primeCurrentRoots()`

判断：

- 合理，但不是首帧必须
- 已经在首帧后，问题不大

建议：

- 保留
- 仅在实际遇到慢盘设备时再考虑进一步延后

### 2.3 Source 日志恢复

文件：[bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart)

当前行为：

- `SourceLogStore.instance.restore()`

判断：

- 属于诊断功能
- 不是 UI 必需

建议：

- 保留在 deferred 阶段
- 不要前移

### 2.4 字体恢复

文件：[bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart)

当前行为：

- `ReaderFontRegistryService().restoreRegisteredFonts()`

判断：

- 本地 IO + 字体注册
- 对首次进入阅读页之外的页面不是硬依赖

建议：

- 当前放在 deferred 阶段是合理的
- 若后续仍有启动抖动，可继续延后到首次进入阅读器前懒恢复

### 2.5 资源迁移 / 存储维护

文件：

- [bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart)
- [lib/app/startup/managed_asset_path_migration_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/managed_asset_path_migration_service.dart)
- [lib/app/startup/startup_storage_maintenance_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/startup_storage_maintenance_service.dart)

当前行为：

- 首帧后执行迁移与清理

判断：

- 这些是后台维护逻辑
- 不建议删

建议：

- 保留
- 若数据量大，可考虑分批或空闲时执行

### 2.6 Source 诊断恢复与健康状态 hydration

文件：

- [lib/features/source/application/source_runtime_diagnostics_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_diagnostics_service.dart)
- [lib/features/source/application/source_health_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_health_service.dart)

当前行为：

- `reportRecoveredInvocations()`
- `hydrate()`

判断：

- 都是本地状态恢复
- 对书源页、搜索页、阅读器失败降级有帮助

建议：

- 保留 deferred
- 不要移到首帧前

### 2.7 本地数据库 warmup

文件：[lib/app/startup/app_startup_coordinator.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/app_startup_coordinator.dart)

当前行为：

- `sourceRuntimeFacade.listScriptSources()`
- 用于预热本地数据库

判断：

- 非首屏必须
- 会和启动初期 UI、图片、主题、滚动布局争本地 IO

建议：

- 已经适合继续延后
- 可以保留，但应明确视为“空闲预热”，不是 startup ready 后立刻执行

## 三、首帧后远端请求

### 3.1 启动公告

文件：

- [lib/app/startup/app_announcement_coordinator.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/app_announcement_coordinator.dart)
- [lib/features/announcement/application/announcement_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/application/announcement_service.dart)

当前行为：

- 启动完成后尝试 `fetchLatestAnnouncement()`

判断：

- 业务上可理解
- 已有缓存与只显示一次控制

建议：

- 保留
- 若继续减负，可把请求窗口再后移一点，或者只在当天首次打开时请求

### 3.2 设备心跳

文件：

- [lib/app/lifecycle/app_lifecycle_coordinator.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/lifecycle/app_lifecycle_coordinator.dart)
- [lib/core/device/device_heartbeat_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/device/device_heartbeat_service.dart)

当前行为：

- 启动 deferred 阶段会发
- 恢复前台时也会发
- 已有 2 分钟节流

判断：

- 有业务价值
- 频率已经收敛

建议：

- 保留

### 3.3 访问统计

文件：

- [lib/app/lifecycle/app_lifecycle_coordinator.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/lifecycle/app_lifecycle_coordinator.dart)
- [lib/core/analytics/analytics_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/analytics/analytics_service.dart)

当前行为：

- 启动 deferred 阶段会发
- 恢复前台时也会发
- 已有 30 分钟节流

判断：

- 有业务价值
- 但不应靠近首屏体验

建议：

- 保留
- 不再前移

### 3.4 启动更新检查

文件：

- [lib/app/startup/app_startup_coordinator.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/app_startup_coordinator.dart)
- [lib/core/app_update/app_update_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/app_update/app_update_service.dart)

当前行为：

- 启动 deferred 阶段检查更新

判断：

- 功能合理
- 但不是每次启动都必须尽快出现

建议：

- 可以继续保留
- 若后续还要压启动负担，可考虑仅每日一次或仅手动检查

## 四、启动后会触发的主题读取

### 4.1 当前高级主题 id

文件：[lib/features/mine/application/advanced_theme_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_provider.dart)

当前行为：

- `activeThemeId` 先通过 `prime` 同步拿到

判断：

- 轻量
- 合理保留

### 4.2 完整高级主题读取

文件：

- [advanced_theme_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_provider.dart)
- [app.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart)

当前行为：

- `App.build()` 直接 `watch(activeAdvancedThemeProvider)`
- 会异步读取完整主题，用于高级主题配色 / 背景 / 字体

判断：

- 这是主题能力本身的一部分，不是无用读取
- 但它属于启动后一定会触发的完整本地数据读取

建议：

- 先保留
- 如果后续仍有启动闪动，再考虑做更轻的 `appearance snapshot`

## 五、启动时最像“启动图问题”的项

### 高风险项

- 启动图当前依赖完整主题读取
- 启动图冷启动阶段与原生启动页表现不一致
- 启动后本地数据库 warmup 时机仍偏早

### 中风险项

- 完整高级主题异步读取
- 启动公告远端请求
- 启动更新检查远端请求

### 低风险项

- SharedPreferences prime
- 生命周期初始化与事件流订阅
- 心跳 / visit 已有节流

## 六、建议优先级

### P0：优先处理

- 把启动图改成“快照驱动”
  - 主题应用时写入启动图快照
  - 启动时只读快照，不再 `loadActiveTheme()`

### P1：第二步处理

- 把本地数据库 warmup 再延后，明确变成空闲预热
- 评估启动更新检查是否改成“每日一次”

### P2：按需处理

- 如果仍能感知到主题切换闪动，再做主题外观快照
- 评估字体恢复是否改成阅读器首次进入前懒加载

## 七、当前结论

当前启动链里真正最不合理的，不是普通主题 prime，也不是公告或心跳，而是：

- 启动图为了主题联动，在启动期额外读取完整主题

这条链应该优先拆掉。
