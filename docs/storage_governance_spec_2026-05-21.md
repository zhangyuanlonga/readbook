# 存储治理定版规范

更新时间：2026-05-21

状态：Phase 2 定版口径，后续开发执行以本文为准

关联文档：

- [sto.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/sto.md)
- [storage_inventory_2026-05-20.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_inventory_2026-05-20.md)
- [storage_governance_draft_2026-05-20.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_governance_draft_2026-05-20.md)

## 1. 适用范围

本文用于统一本项目后续所有本地存储开发口径，覆盖：

- `SharedPreferences`
- `drift`
- 托管文件目录
- 缓存目录
- `flutter_secure_storage`
- 启动期迁移与清理逻辑

如果文档与代码现状冲突，以代码真实现状为准，并更新本文。

## 2. 定版结论

### 2.1 SharedPreferences 使用红线

`SharedPreferences` 只允许存：

- 布尔、数值、枚举、短字符串
- 小型 `StringList`
- 启动期需要同步预热的轻量状态
- 托管文件相对路径引用

`SharedPreferences` 禁止存：

- 大 JSON
- 可持续增长的集合
- 按书 / 按用户持续增长的动态对象
- 用户资产文件本体或 base64 大字符串
- token / password / secret

执行约束：

- 新增 JSON 写入默认禁止，必须先过 `tool/check_storage_governance_guard.dart`
- 动态 key 若存在持续增长趋势，默认先考虑数据库
- `reader.settings.backgroundImageBase64` 这类大字符串视为历史债，不得继续复制到新设计

### 2.2 数据库适用边界

满足任一条件，优先数据库：

- 需要增删改查
- 会持续增长
- 需要按时间排序 / 最近使用 / 统计
- 需要迁移链
- 需要同步合并

当前明确归数据库的对象：

- 阅读进度 `reading_progresses`
- 阅读记录相关表
- 书签
- 阅读状态
- 搜索源命中统计
- 同步配置与同步冲突
- 本地图书索引与本地章节

### 2.3 托管文件目录规范

用户资产必须进入托管文件目录，且与缓存目录彻底隔离。

根目录划分：

- `Documents`：用户可感知、可长期持有的外观资源
- `Support`：应用托管但不可丢失的业务资产和派生资源

目录规范：

- 继续使用 `ManagedAssetStore` 统一做相对路径持久化
- 持久化时优先存相对路径，不存绝对路径
- 新增资产类型默认先补 `ManagedAssetDirectoryPolicy`
- 删除用户资产时，只允许按对象、按 collection 定位删除，不允许模糊路径批量清理

当前定版：

- `profile_avatars`：后续纳入托管文件 policy，归类为用户资产
- `advanced_themes/<themeId>`：继续保留为主题资源目录，归类为用户资产

### 2.4 缓存目录规范

缓存必须满足：

- 可删
- 可重建
- 不含用户资产
- 清理后只影响性能，不影响正确性

缓存允许对象：

- 章节缓存
- 分页缓存
- 封面磁盘缓存
- 导入 / 导出临时工作目录
- 日志 / 诊断导出临时文件

缓存禁止对象：

- 本地图书源文件
- 自定义封面
- 背景图
- 字体文件
- 启动图
- 主题绑定素材

### 2.5 敏感信息规范

敏感信息一律走 `flutter_secure_storage`：

- 登录 token
- refresh token
- WebDAV / sync secret
- 其他密码、密钥、secret

定版决策：

- `auth.access_token`、`auth.refresh_token`、`auth.access_expires_at`、`auth.refresh_expires_at` 已迁入安全存储
- `auth.user_id`、`auth.username`、`auth.account`、`auth.display_name` 仅作为启动预热和展示缓存保留在轻量偏好层

### 2.6 清理逻辑边界

禁止：

- “清理全部本地数据”式模糊入口
- 启动期自动清理用户资产
- 通过模糊目录匹配删除历史资源

允许：

- 只作用于缓存的显式清理
- 用户在对应资源管理页中主动删除自己创建的对象
- 受预算控制的缓存压缩

## 3. 关键决策

### 3.1 高级主题最终落位

定版结论：

- 主题资源本体继续走托管文件目录
- 主题集合索引后续从 `SharedPreferences` 迁出，目标优先为“文件索引 + 托管目录元数据”
- 当前激活主题 ID 与轻量生效快照可保留轻量状态，但不得继续膨胀

选择理由：

- 当前主题强绑定本地壁纸、图集、字体、底栏资源
- 主题资源天然以目录组织，文件索引比把整套资源表化更贴合现状
- 先迁索引，不动资源目录，误伤风险最低

### 3.2 图集类数据最终落位

定版结论：

- 封面图集、启动图集、底栏图集：图片本体继续走托管文件目录
- 图集集合索引后续从 `SharedPreferences` 迁出，目标优先为“文件索引 + 每图集元数据”

### 3.3 书籍自定义状态是否表化

定版结论：

- 是，优先表化

原因：

- 该类数据天然按书增长
- 后续可能参与书架展示、统计、同步和升级迁移

### 3.4 缓存是否统一引入注册表

定版结论：

- Phase 4 再做统一注册表
- 当前阶段先保持显式缓存服务 + 预算参数，不新增复杂抽象

原因：

- 当前缓存对象数量仍可控
- 先完成高风险数据迁移，比先引入总注册表收益更高

## 4. 新功能存储接入 Checklist

每个涉及持久化的新功能，评审必须回答：

1. 这份数据属于：轻量偏好、业务主数据、用户资产、缓存、敏感信息，哪一类？
2. 为什么放这里，而不是数据库 / 托管文件 / 缓存 / 安全存储？
3. 是否持续增长？
4. 是否可重建？
5. 是否属于用户资产？
6. 是否影响升级与覆盖安装？
7. 删除后用户是否会感知“我的内容没了”？
8. 如果有迁移，是否采用“新老双读 -> 新写新结构 -> 迁移 -> 删除旧结构”？

## 5. 本轮迁移优先级

基于当前代码现状，`Phase 3` 迁移顺序定版为：

1. `reader.progress.<bookId>` 迁移到数据库
2. `bookshelf.books`
3. `app.advancedThemes`
4. `coverGallery.galleries`
5. `launchImageGallery.galleries`
6. `auth.*`

## 6. 本轮不做的事情

为了避免额外重构，本轮明确不做：

- 不一次性把所有 JSON 全迁完
- 不引入新的通用存储抽象层
- 不重做主题 / 图集完整架构
- 不在 Phase 2 里先上缓存注册表
