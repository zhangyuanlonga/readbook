# 同步系统执行计划

更新时间：2026-04-29  
用途：作为同步系统落地的唯一执行清单，统一 `WebDAV` 首版、scope 拆分、阶段顺序、验收口径与文档维护规则。  
总计划状态：`进行中专题`

关联文档：

- `docs/development_architecture_guardrails.md`
- `docs/sync_webdav_design.md`
- `docs/project_architecture_unification_plan.md`
- `docs/product_features_guide.md`

---

## 1. 约束基线

本计划执行时必须遵守：

- [development_architecture_guardrails.md](./development_architecture_guardrails.md)
- [sync_webdav_design.md](./sync_webdav_design.md)
- [project_architecture_unification_plan.md](./project_architecture_unification_plan.md)
- [product_features_guide.md](./product_features_guide.md)

本专题硬约束：

- [ ] 同步功能必须作为独立 `feature` 落地，不把 `WebDAV` 逻辑塞回 `reader / bookshelf / mine / source` 页面
- [ ] 页面层不直接访问 `AppDatabase`、`SharedPreferences`、`MethodChannel`
- [ ] 同步编排必须收口到 `features/sync/application/`
- [ ] 远端协议与本地 merge 逻辑必须解耦，不能把业务规则写进 `WebDAV driver`
- [ ] 凭据不明文写入普通 `SharedPreferences` 或普通 Drift 字段
- [ ] `v1` 不同步本地图书文件、本地图书章节、本地图书作用域阅读数据
- [ ] `reading_stats` 首版不作为独立事实源，继续依赖 `reading_history` 重建
- [ ] 登录态、cookie、token、运行时缓存不进入首版同步

---

## 2. 目标

本计划要完成的不是“加一个 WebDAV 按钮”，而是建立一套可继续扩展到多网盘/多服务器的同步系统。

本轮目标：

- [ ] 建立独立 `sync feature`
- [ ] 建立 profile / scope / job / conflict / remote driver 的基础结构
- [ ] 落地 `WebDAV` 首版远端驱动
- [ ] 支持按 scope 勾选同步项
- [ ] 打通首批高价值 scope 的最小闭环
- [ ] 补同步历史、失败记录、最小测试和文档回填口径

---

## 3. 功能范围

### 3.1 首批支持

- [ ] `书架 - 书籍列表`
- [ ] `书架 - 标签 / 分类 / 顺序体系`
- [ ] `阅读 - 阅读进度`
- [ ] `阅读 - 阅读历史`
- [ ] `阅读 - 阅读统计（依赖历史重建）`
- [ ] `阅读 - 书签`
- [ ] `阅读 - 在读 / 读完状态`
- [ ] `书籍资料 - 自定义书名 / 作者 / 简介`
- [ ] `书籍资料 - 自定义封面配置`
- [ ] `书源 - 书源列表 / 源码 / 启用状态`
- [ ] `高级主题 - 主题配置`

### 3.2 首批可选资源项

- [ ] `书籍资料 - 自定义封面图片文件`
- [ ] `高级主题 - 主题壁纸 / 阅读壁纸资源`

### 3.3 后续范围

- [ ] `阅读器 - 界面设置`
- [ ] `阅读器 - 视觉覆盖设置`
- [ ] `外观 - 基础主题 / 导航 / Mine 页偏好`
- [ ] `书架 - 展示偏好`
- [ ] `搜索 - 搜索历史`
- [ ] `首页 - 打卡记录 / 每日目标`
- [ ] `发现 - 当前选择的发现源`
- [ ] `字体 / 图集 / 启动图 / 底栏图集`

### 3.4 明确不做

- [ ] 本地图书文件与章节内容同步
- [ ] 账号登录态同步
- [ ] 书源登录态同步
- [ ] cookie / token 同步
- [ ] runtime 诊断 / source health / cache 类状态同步

---

## 4. 阶段状态总览

- [x] 阶段 0：冻结范围与作用域口径
- [x] 阶段 1：建立 `sync feature` 骨架
- [x] 阶段 2：本地 profile / job / conflict 持久化
- [x] 阶段 3：`WebDAV` driver 与连接验证
- [x] 阶段 4：首批轻量 scope 闭环
- [x] 阶段 5：高价值配置类 scope 闭环
- [x] 阶段 6：历史 / 统计 / 书架组织闭环
- [x] 阶段 7：资源类 scope 闭环
- [x] 阶段 8：设置页 / 历史页 / 自动化验收

规则：

- [ ] 未完成上一阶段，不进入下一阶段
- [ ] 每完成一个勾选项，必须同步更新本文件
- [ ] 每完成一个阶段，必须补“阶段完成定义”
- [ ] 若实施过程中调整 scope、顺序或口径，先改文档，再改代码

---

## 5. 阶段 0：冻结范围与作用域口径

目标：

- 把“功能清单”和“技术 scope”对齐，避免实现时继续发散

执行清单：

- [x] 确认首批 scope 名称与依赖关系
- [x] 确认首批不包含本地图书作用域
- [x] 确认 `reading_stats -> reading_history` 依赖口径
- [x] 确认 `book_metadata_assets -> book_metadata_overrides` 依赖口径
- [x] 确认 `advanced_theme_assets -> advanced_theme_presets` 依赖口径
- [x] 确认 `bookshelf_taxonomy -> bookshelf_collection` 关系与 UI 提示口径

阶段完成定义：

- [x] 功能名、scope 名、远端 dataset 名三者一一对应
- [x] 不再继续争论首版是否同步本地图书作用域

---

## 6. 阶段 1：建立 `sync feature` 骨架

目标：

- 建立符合架构约束的目录、provider 和 application 入口

执行清单：

- [x] 新建 `lib/features/sync/`
- [x] 建立 `presentation / application / domain / data / providers / routes`
- [x] 建立 `SyncScope`、`SyncProfile`、`SyncJob`、`SyncConflict` 基础模型
- [x] 建立 `SyncRemoteDriver` 抽象接口
- [x] 建立 `sync` feature provider 组合根
- [x] 确认页面层只消费 provider，不直接组装依赖

建议目录：

```text
lib/features/sync/
  presentation/
  application/
  domain/
  data/
  providers.dart
  routes.dart
```

阶段完成定义：

- [x] `sync feature` 可以独立承载后续能力
- [x] 新代码未违反开发约束文档的一票否决项

---

## 7. 阶段 2：本地持久化与凭据安全存储

目标：

- 建立 profile / scope state / job / conflict 本地事实表
- 建立凭据安全存储

执行清单：

- [x] 设计 `sync_profiles`
- [x] 设计 `sync_scope_states`
- [x] 设计 `sync_jobs`
- [x] 设计 `sync_conflicts`
- [x] 评估并接入安全存储方案
- [x] 让 `secretRef` 只指向安全存储，不持久化密码正文
- [x] 补数据库迁移与最小 smoke 验证

阶段完成定义：

- [x] 能本地保存同步配置
- [x] 能本地记录任务和冲突
- [x] 凭据不落普通明文字段

---

## 8. 阶段 3：`WebDAV` Driver 与连接验证

目标：

- 打通远端目录、读写文件、revision/etag 基础能力

执行清单：

- [x] 实现 `WebDavSyncRemoteDriver`
- [x] 支持 Basic Auth
- [x] 支持 `PROPFIND / GET / PUT / MKCOL`
- [x] 支持 `ETag + If-Match`
- [x] 支持 `ensureReady()`
- [x] 支持测试连接
- [x] 支持创建最小远端目录和 `manifest.json`

阶段完成定义：

- [x] 能在真实 WebDAV 目标上完成最小往返
- [x] 连接失败、鉴权失败、目录失败有稳定错误口径

---

## 9. 阶段 4：首批轻量 Scope 闭环

目标：

- 先打通模型简单、用户价值高、资源负担低的 scope

执行顺序建议：

- [x] `reading_progress`
- [x] `bookmarks`
- [x] `script_sources`
- [x] `reading_book_statuses`

执行清单：

- [x] 为每个 scope 建立 exporter / importer
- [x] 建立三方合并入口
- [x] 为每个 scope 建立本地 key 规则
- [x] 导入后做最小回写验证

阶段完成定义：

- [x] 用户能手动执行一次同步并看到结果
- [x] 上述 4 个 scope 都具备最小闭环

---

## 10. 阶段 5：高价值配置类 Scope 闭环

目标：

- 打通“用户明显会在意”的自定义资产配置

执行顺序建议：

- [x] `book_metadata_overrides`
- [x] `advanced_theme_presets`

执行清单：

- [x] 建立 `BookMetadataOverride` 同步链路
- [x] 明确仅同步远程书籍作用域 override
- [x] 建立 `AdvancedTheme` 配置同步链路
- [x] 建立 `activeThemeId` 同步口径
- [x] 补主题配置冲突按 `updatedAt` 处理逻辑

阶段完成定义：

- [x] 用户自定义书名/作者/简介/封面配置可跨设备同步
- [x] 高级主题配置可跨设备同步

---

## 11. 阶段 6：历史 / 统计 / 书架组织闭环

目标：

- 打通价值最高但结构更复杂的一组 scope

执行顺序建议：

- [x] `reading_history`
- [x] `reading_stats`
- [x] `bookshelf_collection`
- [x] `bookshelf_taxonomy`

执行清单：

- [x] 为 `ReadingRecordSession` 增加同步侧稳定 key 口径
- [x] 明确 `ReadingRecordDay` 只做本地重建，不直接作为远端事实源
- [x] 打通 `reading_history` 导入后重建统计页
- [x] 打通 `bookshelf_collection`
- [x] 打通 `bookshelf_taxonomy`
- [x] 校验书架标签/分类体系不会因同步丢失

阶段完成定义：

- [x] 阅读历史与统计页体验闭环成立
- [x] 书架列表与组织体系闭环成立

---

## 12. 阶段 7：资源类 Scope 闭环

目标：

- 把配置引用到的资源文件补齐为可选同步能力

执行顺序建议：

- [x] `book_metadata_assets`
- [x] `advanced_theme_assets`

执行清单：

- [x] 建立资源文件哈希与远端传输规则
- [x] 建立资源上传 / 下载 / 缺失降级口径
- [x] 让资源 scope 显式依赖配置 scope
- [x] 缺资源时 UI 不崩溃，允许配置先导入

阶段完成定义：

- [x] 自定义封面文件可选同步
- [x] 高级主题壁纸资源可选同步

---

## 13. 阶段 8：设置页 / 历史页 / 自动化验收

目标：

- 把同步系统做成用户可用，而不是仅有内部服务

执行清单：

- [x] 同步设置页
- [x] scope 分组勾选 UI
- [x] scope 依赖联动提示
- [x] 推荐组合入口
- [x] 同步历史页
- [x] 最小失败重试
- [x] 最小自动同步触发
- [x] 同步专题测试与文档回填

阶段完成定义：

- [x] 用户能独立配置一个 WebDAV profile
- [x] 用户能看见同步历史、错误、成功摘要
- [x] 文档、代码、验证结果三者一致

---

## 14. 首批影响文件清单

预计主落点：

- [ ] `lib/features/sync/`
- [ ] `lib/data/datasources/local/app_database.dart`
- [ ] `lib/app/composition/app_providers.dart`
- [ ] `lib/features/source/providers.dart`
- [ ] `lib/features/mine/providers.dart`
- [ ] `lib/features/book/providers.dart`
- [ ] `lib/features/reader/application/reading_record_service.dart`
- [ ] `lib/features/reader/application/reading_records_query_service.dart`
- [ ] `lib/features/source/application/source_runtime_facade.dart`
- [ ] `lib/features/mine/application/advanced_theme_service.dart`
- [ ] `lib/features/bookshelf/application/bookshelf_service.dart`

说明：

- 若执行中新增关键文件，必须先回填本节，再继续开发。

---

## 15. 测试与验收口径

最小测试集：

- [ ] profile 持久化 smoke
- [ ] `WebDAV` 连接验证 smoke
- [ ] 三方合并单测
- [ ] `reading_progress` 导入导出测试
- [ ] `bookmarks` 导入导出测试
- [ ] `script_sources` 导入导出测试
- [ ] `advanced_theme_presets` 导入导出测试
- [ ] `reading_history -> reading_stats` 重建测试
- [ ] `bookshelf_collection + bookshelf_taxonomy` 闭环测试

真实链路最小验收：

- [ ] 新建 profile 并测试连接
- [ ] 勾选 `reading_progress` 后双端继续阅读位置一致
- [ ] 勾选 `bookmarks` 后双端书签一致
- [ ] 勾选 `script_sources` 后双端书源列表一致
- [ ] 勾选 `advanced_theme_presets` 后双端主题配置一致
- [ ] 勾选 `bookshelf_collection + bookshelf_taxonomy` 后双端书架组织一致

---

## 16. 文档维护规则

- [ ] 同步系统后续实现一律以本文件为唯一执行清单
- [ ] `scope` 口径变更时，先改 `docs/sync_webdav_design.md`
- [ ] 阶段完成后，先回填本文件，再回填总计划
- [ ] 若新增新的同步 scope，必须先补“功能同步清单”再落代码

---

## 17. 当前建议

当前最合理的首个实现批次不是“先做所有页面”，而是：

1. 阶段 1 到阶段 3：骨架、持久化、WebDAV driver
2. 阶段 4：`reading_progress / bookmarks / script_sources / reading_book_statuses`
3. 阶段 5：`book_metadata_overrides / advanced_theme_presets`

等这两批稳定后，再进入阅读历史、统计和书架组织这组更复杂的闭环。
