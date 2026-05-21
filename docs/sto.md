# 存储治理开发阶段任务

更新时间：2026-05-20

状态：开发执行稿

关联规则文档：

- [storage_governance_draft_2026-05-20.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_governance_draft_2026-05-20.md)
- [development_architecture_guardrails.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/development_architecture_guardrails.md)

## 1. 目标

本任务单用于把“存储治理”从原则落到开发阶段执行。

本轮目标：

1. 明确所有本地存储落位
2. 把用户资产、业务数据、缓存、敏感信息彻底分层
3. 解决覆盖安装后卡顿和残留膨胀问题
4. 建立可验证的升级迁移链
5. 建立后续不回退的规则约束

## 2. 分阶段总览

| 阶段 | 名称 | 目标 | 优先级 |
|---|---|---|---|
| Phase 0 | 冻结新增问题 | 停止继续扩大存储混乱 | P0 |
| Phase 1 | 存储盘点 | 找全所有持久化入口 | P0 |
| Phase 2 | 规则定版 | 明确数据分类和落位标准 | P0 |
| Phase 3 | 高风险迁移 | 优先迁出大 JSON / 混放资产 | P0 |
| Phase 4 | 缓存收敛 | 建立统一缓存协议 | P1 |
| Phase 5 | 升级验证 | 建立覆盖安装与版本迁移回归链 | P0 |
| Phase 6 | 长期守卫 | 防止未来继续回退 | P1 |

## 3. Phase 0：冻结新增问题

### 3.1 任务

- [x] 禁止新增大 JSON 写入 `SharedPreferences`
- [x] 禁止新增用户资产写入缓存目录
- [x] 禁止新增“清理全部”式模糊清理入口
- [x] 禁止新增启动时高风险自动清理
- [x] 所有新持久化点必须在评审中说明落位

### 3.1.a 本次落地记录

- 2026-05-20：已新增 `tool/check_storage_governance_guard.dart`
- 2026-05-20：已将守卫接入 `tool/run_architecture_green_suite.dart`
- 2026-05-20：已按代码真实现状登记 19 处历史性 `SharedPreferences` JSON 写入基线，只拦截后续新增项
- 2026-05-20：已新增“临时/缓存目录使用基线守卫”，防止把用户资产误带入临时目录链路
- 2026-05-20：已新增“启动期清理调用守卫”，防止后续把缓存清理/模糊清理挂回启动流程
- 2026-05-20：已补 `Phase 1` 首版盘点文档 `docs/storage_inventory_2026-05-20.md`
- 2026-05-20：当前 Phase 0 状态更新为“已完成首轮冻结”，后续仍需持续维护守卫基线

### 3.2 产物

- 新增存储接入 checklist
- PR 检查项更新

### 3.2.a 存储接入 Checklist

- 新增持久化前，必须先回答：为什么不是数据库 / 托管文件 / 缓存 / 安全存储
- 如果是 `SharedPreferences`，必须证明是轻量、低复杂度、非增长型数据
- 如果是文件，必须说明它是不是用户资产，以及为什么不应进入缓存目录
- 如果是缓存，必须说明目录、key 规则、是否可重建、清理边界
- 如果是敏感数据，必须走 `flutter_secure_storage`
- 如果涉及迁移，优先采用“新老双读 -> 新写新结构 -> 迁移 -> 删除旧结构”
- 如果新增启动期任务，必须证明不会触发高风险自动清理
- 如果新增清理入口，必须明确只作用于可重建缓存

### 3.3 验收

- 新功能 PR 中，涉及本地存储必须说明：位置、是否可删、是否可迁移

## 4. Phase 1：存储盘点

### 4.1 任务

- [x] 盘点 `SharedPreferences` 全部 key
- [x] 盘点 `drift` 全部表、字段、迁移分支
- [x] 盘点托管文件目录与路径恢复逻辑
- [x] 盘点缓存目录与缓存 key 规则
- [x] 盘点 `flutter_secure_storage` 使用点
- [x] 为每项数据补充“当前落位 / 目标落位 / 风险等级”

### 4.2 盘点字段

每项至少记录：

- 模块
- 数据名
- 当前存储位置
- key / 表 / 目录
- 是否持续增长
- 是否可重建
- 是否用户资产
- 是否敏感
- 是否影响升级
- 建议目标位置

### 4.3 产物

- `storage_inventory_yyyy-mm-dd.md`
- 当前已产出：[storage_inventory_2026-05-20.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_inventory_2026-05-20.md)

### 4.4 验收

- 所有持久化入口可追踪
- 能一眼区分业务数据 / 缓存 / 用户资产 / 敏感信息

### 4.4.a 当前状态

- 2026-05-20：Phase 1 首版盘点已完成，后续若发现漏项以代码现状继续滚动修订 inventory

## 5. Phase 2：规则定版

### 5.1 任务

- [x] 定义 `SharedPreferences` 使用红线
- [x] 定义数据库适用边界
- [x] 定义托管文件目录规范
- [x] 定义缓存目录规范
- [x] 定义敏感信息安全存储规范
- [x] 定义清理逻辑边界
- [x] 定义新功能存储接入 checklist

### 5.2 关键决策

- [x] 高级主题走数据库索引还是文件索引
- [x] 图集类数据走数据库索引还是文件索引
- [x] 书籍自定义状态是否表化
- [x] 缓存是否统一引入注册表

### 5.3 产物

- 存储定版规范
- 接入 checklist
- 当前已产出：[storage_governance_spec_2026-05-21.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_governance_spec_2026-05-21.md)

### 5.4 验收

- 团队对“什么存哪里”达成统一口径

### 5.4.a 当前状态

- 2026-05-21：Phase 2 已完成首轮定版，后续若代码现状变化，同步更新规范文档

## 6. Phase 3：高风险迁移

### 6.1 目标

优先处理最可能导致覆盖安装后性能恶化的对象。

### 6.2 第一批迁移对象

- [x] 高级主题聚合 JSON
- [x] 封面图集聚合 JSON
- [x] 启动图集聚合 JSON
- [x] 复杂阅读偏好聚合对象
- [x] 聚合式业务状态对象

### 6.3 统一迁移策略

每个迁移项统一按下面执行：

1. 设计目标结构
2. 实现新结构读写
3. 老结构与新结构双读
4. 启动或首次访问时迁移
5. 迁移成功后记录版本标记
6. 观察稳定后删除旧结构

### 6.4 验收

- 高风险对象不再依赖 `SharedPreferences` 大 JSON

### 6.4.a 本次落地记录

- 2026-05-21：已完成 `reader.progress.<bookId>` -> `reading_progresses` 数据库表迁移
- 2026-05-21：`ReaderPreferencesService` 已切为“数据库优先读写 + 老 SharedPreferences 双读迁移 + 成功后清旧 key”
- 2026-05-21：已补数据库 schema 升级到 `v28` 与阅读进度迁移测试
- 2026-05-21：已完成 `app.advancedThemes` -> `Documents/advanced_themes/index.json` 文件索引迁移
- 2026-05-21：`AdvancedThemeService` 已切为“文件索引优先读写 + 老 SharedPreferences 双读迁移 + 成功后清旧 key”
- 2026-05-21：已补高级主题文件索引迁移测试
- 2026-05-21：已完成 `coverGallery.galleries` -> `Documents/cover_galleries/index.json` 文件索引迁移
- 2026-05-21：已完成 `launchImageGallery.galleries` -> `Documents/launch_image_galleries/index.json` 文件索引迁移
- 2026-05-21：封面图集与启动图集服务已切为“文件索引优先读写 + 老 SharedPreferences 双读迁移 + 成功后清旧 key”
- 2026-05-21：已补封面图集与启动图集文件索引迁移测试
- 2026-05-21：已完成 `remote.access.snapshot.v1.<userId>` -> `remote_access_snapshots` 数据库迁移
- 2026-05-21：已完成 `source.health.snapshots.v1` -> `source_health_snapshots` 数据库迁移
- 2026-05-21：RemoteAccessSnapshot 与 SourceHealthPersistence 已切为“数据库优先读写 + 老 SharedPreferences 双读迁移 + 成功后清旧 key”
- 2026-05-21：已补 remote access / source health 迁移测试
- 2026-05-21：已完成 `auth.*` 凭证迁移，切为“安全存储优先 + 旧 prefs 双读迁移 + 成功后清旧 token key”
- 2026-05-21：`MinePageSessionPriming` 已调整为只预热展示缓存，启动不再依赖 token 留在 `SharedPreferences`
- 2026-05-21：已补 `auth.*` 迁移、logout、refresh token 链路与页面 smoke 覆盖
- 2026-05-21：已复跑 `tool/check_storage_governance_guard.dart`，无需新增 auth 相关 guard baseline
- 2026-05-21：当前 Phase 3 状态为“进行中”，已完成阅读进度、高级主题、封面图集、启动图集、remote access、source health、auth 七条真实迁移链，剩余主要为书架大对象

## 7. Phase 4：缓存收敛

### 7.1 任务

- [x] 建立缓存分类
- [x] 建立统一缓存 key 规则
- [x] 建立缓存预算上限
- [x] 建立缓存过期策略
- [x] 建立缓存清理入口边界
- [x] 明确“缓存可删，但用户资产不可删”

### 7.2 缓存分类建议

- 章节缓存
- 分页缓存
- 封面下载缓存
- 运行时临时文件
- 解析中间结果

### 7.3 产物

- 缓存协议文档
- 缓存预算配置
- 当前已产出代码：[app_cache_governance_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/cache/app_cache_governance_service.dart)

### 7.4 验收

- 删除缓存后不会误伤用户资产
- 清理逻辑只作用于可重建数据

### 7.4.a 当前状态

- 2026-05-21：已完成缓存分类、预算、过期策略和清理边界首轮收口
- 2026-05-21：已新增缓存汇总服务，统一查看章节缓存、分页缓存、封面缓存的条目数 / 体积 / 预算

## 8. Phase 5：升级验证

### 8.1 任务

- [x] 建立从旧版本到新版本的升级测试矩阵
- [ ] 建立多次覆盖安装场景回归
- [ ] 建立删除重装对照场景
- [x] 建立迁移失败回滚策略
- [x] 建立异常数据样本回归

### 8.2 覆盖场景

- 老用户单次升级
- 老用户多次覆盖安装
- 大量本地图书用户
- 大量主题/图集用户
- 清缓存后重启
- 删除重装后恢复

### 8.3 产物

- 升级回归清单
- 迁移验证脚本或手工步骤
- 当前已产出：[storage_upgrade_validation_2026-05-21.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_upgrade_validation_2026-05-21.md)

### 8.4 验收

- 覆盖安装不会明显放大存储膨胀
- 迁移链可回放

### 8.4.a 当前状态

- 2026-05-21：已完成 Phase 5 首版升级验证矩阵
- 2026-05-21：已把阅读进度数据库升级链、阅读进度迁移链、高级主题迁移链纳入回归清单
- 2026-05-21：覆盖安装多次回放与删除重装对照仍待后续补齐

## 9. Phase 6：长期守卫

### 9.1 任务

- [x] 为 `SharedPreferences` 新增使用守卫
- [x] 为缓存目录新增边界守卫
- [x] 为托管文件目录新增边界守卫
- [x] 为数据库迁移新增回归守卫
- [x] 为 PR 模板新增存储接入检查项

### 9.2 守卫方式

- 架构检查脚本
- PR checklist
- 回归测试模板
- 迁移验证清单

### 9.3 验收

- 后续功能默认遵循新规则，不靠人工记忆

### 9.3.a 当前状态

- 2026-05-21：已扩 `tool/check_storage_governance_guard.dart`，覆盖 `SharedPreferences`、临时目录、启动清理、托管目录边界
- 2026-05-21：已将数据库迁移回归测试接入 `tool/run_architecture_green_suite.dart`
- 2026-05-21：已新增 [pull_request_template.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/.github/pull_request_template.md) 的存储治理检查项
- 2026-05-21：Phase 6 已完成首轮守卫落地

## 10. 建议执行顺序

建议按下面顺序推进：

1. Phase 0：冻结新增问题
2. Phase 1：完整盘点
3. Phase 2：规则定版
4. Phase 3：高风险迁移
5. Phase 4：缓存收敛
6. Phase 5：升级验证
7. Phase 6：长期守卫

不要反过来做。

如果在规则未定版前先迁移，很容易返工。

## 11. 当前建议优先事项

如果现在就开始开发，建议优先做：

- [ ] 先补完整存储清单
- [ ] 先把 `SharedPreferences` 中高风险大对象列出来
- [ ] 先确定高级主题 / 图集 / 启动图集的最终落位
- [ ] 先完成一条“老结构迁移到新结构”的最小样板
- [ ] 再扩展到其他模块

## 12. 完成标准

当以下条件全部满足，可视为存储治理完成：

- [ ] 持久化入口全部有清单
- [ ] 用户资产与缓存彻底隔离
- [ ] `SharedPreferences` 不再承载大 JSON 主数据
- [ ] 关键业务主数据具备结构化存储
- [ ] 升级迁移链可验证
- [ ] 覆盖安装场景稳定
- [ ] 后续开发有守卫，避免回退
