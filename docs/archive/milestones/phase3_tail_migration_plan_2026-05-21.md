# Phase 3 尾项迁移计划

更新时间：2026-05-21

状态：待评审

适用范围：

- `auth.*` 登录态与凭证迁移
- `bookshelf.*` 书架聚合状态迁移

关联文档：

- [存储治理定版规范](storage_governance_spec_2026-05-21.md)
- [存储盘点清单](storage_inventory_2026-05-20.md)

## 1. 结论先行

当前 `Phase 3` 剩余最重的两块，不再是前面那种“小闭环迁移”，而是两条独立主线：

1. `auth.*`
2. `bookshelf.*`

建议把它们拆成两条子计划执行，不要混成一个大改动。

建议顺序：

1. 先做 `auth.*`
2. 再做 `bookshelf.*`

原因：

- `auth.*` 风险高但对象小，先解决安全问题
- `bookshelf.*` 数据量和依赖面更大，适合在认证链稳定后单独推进

## 2. 主线 A：`auth.*` 迁移计划

目标：

- 把登录 token / refresh token / 过期时间 / 账号标识从 `SharedPreferences` 迁到安全存储
- 不打断当前启动预热、Mine 页预热、鉴权刷新链路

当前问题：

- `auth.access_token`
- `auth.refresh_token`
- `auth.access_expires_at`
- `auth.refresh_expires_at`
- `auth.user_id`
- `auth.username`
- `auth.account`
- `auth.display_name`

以上都还在 `SharedPreferences`

### A0 范围确认

- [x] 明确哪些字段必须进安全存储
- [x] 明确哪些字段可以保留在轻量缓存层做启动预热
- [x] 明确 `MinePageSessionPriming` 是否允许只预热脱敏展示信息

完成标准：

- 对“安全存储字段”和“可留轻量字段”有清单

本次落地口径：

- 安全存储字段：`auth.access_token`、`auth.refresh_token`、`auth.access_expires_at`、`auth.refresh_expires_at`
- 轻量缓存字段：`auth.user_id`、`auth.username`、`auth.account`、`auth.display_name`
- `MinePageSessionPriming` 允许只预热脱敏展示信息，不再依赖 token 留在 `SharedPreferences`

### A1 安全存储接入层

- [x] 新增 `AuthSessionSecretStore` 或同级封装
- [x] 支持读写 access token / refresh token
- [x] 支持迁移期双读旧 prefs
- [x] 支持清理旧 prefs 中对应 key

完成标准：

- 有独立的认证凭证安全存储入口

### A2 会话模型拆分

- [x] 把 `AuthSessionStore` 拆成“凭证读取”和“展示信息读取”两层
- [x] 保证现有 `getSession()` 调用方无感
- [x] 启动时先读安全存储，再补充轻量展示字段

完成标准：

- `AuthSessionStore` 不再直接依赖 token 在 prefs 中存在

### A3 迁移链落地

- [x] 首次读取时：新老双读
- [x] 新写时：新结构优先写安全存储
- [x] 迁移成功后：删除旧 prefs token key
- [x] 保留一段兼容窗口再删剩余旧读逻辑

完成标准：

- 旧用户无需重登即可迁移

本次落地说明：

- `AuthSessionStore` 已切为“安全存储优先 + 旧 prefs 凭证双读迁移”
- 首次命中旧凭证时会写回安全存储并清理旧 prefs token key
- 新写始终优先写安全存储，展示字段继续保留轻量缓存
- 已保留 `enableLegacyCredentialFallback` 兼容窗口开关，后续可在稳定后移除旧读逻辑

### A4 启动预热与页面兼容

- [x] `MinePageSessionPriming` 与启动预热兼容新结构
- [x] Auth provider / refresh token 链路兼容新结构
- [x] 页面 smoke test 补新结构覆盖

完成标准：

- 启动不丢登录态
- Mine 页、个人页、鉴权刷新链路正常

### A5 验证与收尾

- [x] 单元测试覆盖旧 prefs -> 安全存储迁移
- [x] 单元测试覆盖 clear / logout
- [x] smoke test 覆盖启动后可读取会话
- [x] 更新 storage guard 基线

完成标准：

- `auth.*` 不再属于 `SharedPreferences` 高风险项

本次验证说明：

- 已补迁移、clear、logout、refresh token 链路、启动预热兼容测试
- 已补 `MinePage` 新结构 smoke 覆盖
- `tool/check_storage_governance_guard.dart` 已复跑，未产生新的 auth 相关基线项

## 3. 主线 B：`bookshelf.*` 迁移计划

目标：

- 把书架主集合及其 taxonomy 聚合状态从 `SharedPreferences` 迁出
- 收口到结构化存储，避免书架数据继续膨胀

当前高风险对象：

- `bookshelf.books`
- `bookshelf.book_tags`
- `bookshelf.tag_order`
- `bookshelf.tag_metadata.v1`
- `bookshelf.category_order`
- `bookshelf.category_metadata.v1`
- `bookshelf.base_filter_order`

### B0 目标结构定版

- [x] 明确书架主数据是走数据库表还是文件索引
- [x] 明确标签 / 分类 / 顺序是否拆表
- [x] 明确展示偏好和业务主数据的边界

建议口径：

- 书架主数据、标签、分类、顺序元数据：数据库
- 纯展示偏好：继续留轻量偏好层

完成标准：

- 书架“主数据”和“展示偏好”边界明确

本次落地口径：

- 书架主数据：数据库 `bookshelf_books`
- 标签关联：数据库 `bookshelf_tag_assignments`
- 标签元数据与顺序：数据库 `bookshelf_tag_metadata`
- 分类元数据与顺序：数据库 `bookshelf_category_metadata`
- 基础筛选顺序：数据库 `bookshelf_base_filter_orders`
- 纯展示偏好：`bookshelf.view.*`、`bookshelf.grid.*`、`bookshelf.list.*`、`bookshelf.sort.mode` 等继续保留轻量偏好层

### B1 表结构设计

- [x] 设计书架主表
- [x] 设计标签表
- [x] 设计分类表
- [x] 设计书籍与标签/分类关联或等价结构
- [x] 设计顺序字段或排序索引结构

完成标准：

- 数据库 schema 能承载现有书架功能

本次落地说明：

- 已在 `schemaVersion 30` 增加书架主表、标签关联表、标签元数据表、分类元数据表、基础筛选顺序表
- 标签与分类顺序通过 `position` 字段承载
- 书籍与标签关联通过 `(sourceId, detailUrl, tagName)` 主键承载

### B2 读链路兼容

- [x] 新数据库读链路实现
- [x] 旧 prefs JSON 读链路保留兼容
- [x] `BookshelfService.getAll()` 对调用方保持兼容

完成标准：

- 页面层不用先大改就能切读

本次落地说明：

- `BookshelfService` 已支持数据库优先读取书架主数据、标签映射、标签顺序、分类顺序、基础筛选顺序
- 保留旧 prefs JSON 回退读取
- 新增 `migrateLegacySnapshotToDatabase()`，供后续 B4 启动迁移直接复用

### B3 写链路切换

- [x] 新增 / 删除 / 更新书架项改走数据库
- [x] 标签操作改走数据库
- [x] 分类操作改走数据库
- [x] 顺序调整改走数据库

完成标准：

- 新写不再回写 `bookshelf.books` 等聚合 JSON

本次落地说明：

- `BookshelfService` 的书架主数据、标签映射、标签元数据、分类元数据、顺序写入已切到数据库
- 新写完成后会清理旧 prefs 聚合 key，不再回写 `bookshelf.books`、`bookshelf.book_tags`、`bookshelf.tag_order`、`bookshelf.category_order`、`bookshelf.base_filter_order`

### B4 迁移执行

- [x] 首次读取时把旧 `bookshelf.books` 迁入数据库
- [x] 同时迁移标签 / 分类 / 顺序元数据
- [x] 迁移成功后清除旧 prefs 主 key
- [x] 保留一段兼容窗口

完成标准：

- 旧用户书架无感迁移

本次落地说明：

- `BookshelfService.getAll()` 在数据库为空时会自动触发 `migrateLegacySnapshotToDatabase()`
- 迁移内容包含书架主集合、标签映射、标签元数据、分类元数据、基础筛选顺序
- 迁移完成后清理旧 prefs key，后续仍保留回退读取代码作为兼容窗口

### B5 页面与同步链校验

- [x] 书架页正常读取
- [x] 图书详情加书架/移出书架正常
- [x] 标签 / 分类管理正常
- [x] 与现有同步逻辑边界重新确认

完成标准：

- 书架主流程可用

本次验证说明：

- 已补图书详情加书架/移出书架与组织保存测试
- 已补展示同步写入书架测试
- 已补标签管理页读取数据库顺序测试
- 同步侧 `bookshelfCollection` / `bookshelfTaxonomy` 仍复用 `BookshelfService` 读写接口，边界保持兼容

### B6 验证与收尾

- [x] 补数据库迁移测试
- [x] 补 `BookshelfService` 单测
- [x] 补书架主流程 smoke test
- [x] 更新 storage guard 基线

完成标准：

- `bookshelf.*` 不再属于 `SharedPreferences` 高风险项

本次验证说明：

- 已补 `app_database_bookshelf_migration_test.dart` 覆盖 v29 -> v30 schema 升级
- 已补 `BookshelfService` 迁移、数据库写入与旧 prefs 清理单测
- 已补 `BookshelfPage` 基于 legacy prefs 自动迁移后的 smoke test
- `tool/check_storage_governance_guard.dart` 已移除书架历史 JSON baseline，复跑后无新增违规

## 4. 建议拆任务方式

建议不要把两条主线绑成一个 PR。

推荐拆分：

1. PR-A：`auth.*` 安全存储迁移
2. PR-B1：书架表结构 + 只读兼容
3. PR-B2：书架写链路切换 + 迁移

## 5. 风险提示

### `auth.*` 风险

- 启动预热依赖当前 prefs 同步读取
- 登录态读取失败会直接影响用户进入页面
- 清理旧 key 时序不对会导致用户被动掉线

### `bookshelf.*` 风险

- 书架是核心主流程
- 数据量大、对象复杂
- 标签 / 分类 / 顺序逻辑互相耦合
- 同步与页面层都可能受到影响

## 6. 建议决策

如果你要继续清空 `Phase 3`，建议按这个顺序执行：

1. 先批准主线 A 全做完
2. 再批准主线 B 分两步做完

如果你只想先解决最高风险，先做主线 A 也成立。
