# 里程碑 04：成熟库替代与架构样板治理

创建日期：2026-06-03

状态：执行中。Phase 4.1 已完成；Phase 4.2、Phase 4.3 已完成首轮试点但阶段未收口。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。移动端继续作为稳定基线。

核心目标：在前三个里程碑已经完成业务闭环、多端 UI 和本地资源能力后，系统治理当前仍然手写的通用基础设施与样板代码。优先使用项目已采用或成熟验证的 Flutter / Dart 生态库，减少页面状态、模型序列化、图片缓存、路由字符串、表单校验、全局单例和监控样板。

## 1. 阶段定位

第四里程碑不是技术重写，也不是更换主架构。

本阶段关注：

- 继续沿用 Riverpod、GoRouter、Dio、Drift、logger、SharedPreferences / secure storage 的现有成熟栈。
- 不引入 GetX、Bloc、get_it 等替代当前主架构的方案，除非后续有单独架构决策。
- 将已经复杂化的 `setState` / `ValueNotifier` / 手写事件流收敛到 Riverpod controller / notifier。
- 将手写 `toJson` / `fromJson` / `copyWith` / equality 样板逐步迁移到 `freezed`、`json_serializable` 或 Drift 生成模型。
- 将封面网络图片缓存、cookie jar、REST API DTO、表单验证、错误监控等通用能力交给成熟库或生成工具。
- 保持行为等价，小步迁移，每次迁移必须有测试或 guard 证明。

## 2. 不做项

- [x] 不重写前三个里程碑已经跑通的业务链路。
- [x] 不把 Riverpod 替换成 Bloc / GetX / Provider。
- [x] 不把 GoRouter 替换成 auto_route / beamer。
- [x] 不把 Drift 替换成 floor / objectbox。
- [x] 不一次性迁移所有旧模型。
- [x] 不为了减少代码行数破坏兼容字段、存储 key 或数据库迁移。
- [x] 不新增只支持单端、会拖累 Web JS / Desktop 的库。

## 3. 优先级

优先级按收益和风险排序：

1. 高风险手写状态：阅读器、书架、主题管理等超大页面。
2. 高重复手写模型：JSON、copyWith、状态对象、DTO。
3. 高维护成本基础设施：封面磁盘缓存、cookie jar、路由字符串、日志监控。
4. 中低风险体验样板：表单验证、局部动画、UI 小组件。

## 4. 阶段执行总览

按阶段推进，完成一个阶段后勾选总览项，再进入下一阶段。除非阶段说明允许并行，否则默认按顺序执行。

- [x] Phase 4.1：治理基线与试点范围确认。
- [ ] Phase 4.2：高风险页面状态管理收口试点。
- [ ] Phase 4.3：模型与 JSON 代码生成试点。
- [ ] Phase 4.4：网络图片与封面缓存替代。
- [ ] Phase 4.5：API 客户端与网关通信治理。
- [ ] Phase 4.6：路由字符串与 typed route 治理。
- [ ] Phase 4.7：表单与验证统一。
- [ ] Phase 4.8：依赖注入与全局单例治理。
- [ ] Phase 4.9：日志与错误监控接入。
- [ ] Phase 4.10：总体验收、回归和文档收口。

## 5. Phase 4.1：治理基线与试点范围确认

目标：先建立迁移边界和试点清单，避免在超大页面、模型和基础设施上同时开太多口子。

任务：

- [x] 盘点本里程碑涉及的候选文件、负责人、影响平台和测试入口。
- [x] 明确本阶段不迁移主架构：Riverpod、GoRouter、Dio、Drift 保持不变。
- [x] 为每类治理确认第一个试点：状态、模型、图片缓存、API、路由、表单、DI、日志。
- [x] 建立迁移准入规则：行为等价、移动端不回退、必须补测试或 guard。
- [x] 在任务系统或文档中记录每个 Phase 的执行负责人和计划完成时间。

阶段完成条件：

- [x] 试点清单确认。
- [x] 风险和回滚方式确认。
- [x] 后续 Phase 可以独立领取执行。

试点进展（2026-06-03）：

| 治理类型 | 首个试点 | 候选文件 | 负责人 | 影响平台 | 测试入口 | 计划完成 |
| --- | --- | --- | --- | --- | --- | --- |
| 状态管理 | 阅读器 session generation / task token 收口到 Riverpod family notifier | `reader_session_controller.dart`、`reader_page.dart` | Codex | 全平台，移动端为稳定基线 | `flutter test test/features/reader/application/reader_session_controller_test.dart` | 2026-06-03 |
| 模型状态 | 阅读器 session state 使用 `freezed` 生成 `copyWith` / equality | `reader_session_state.dart` | Codex | 全平台 | `flutter test test/features/reader/application/reader_session_state_test.dart` | 2026-06-03 |
| JSON payload | 分页缓存 slice 使用 `json_serializable` 生成 JSON 样板 | `reader_pagination_models.dart` | Codex | 全平台 | `flutter test test/features/reader/application/reader_pagination_cache_service_test.dart` | 2026-06-03 |
| 图片缓存 | `ResolvedBookCover` 适配层 + `cached_network_image` / `flutter_cache_manager` 评估 | `resolved_book_cover.dart`、`disk_cached_cover_image.dart`、缓存治理服务 | 待领取 | Android、iOS、Web JS、Desktop | `flutter test test/app/widgets/resolved_book_cover_test.dart test/core/cache/app_cache_governance_service_test.dart` | Phase 4.4 |
| API | 低风险 REST DTO / service，暂不触碰 SSE 网关协议 | `api_client.dart`、在线书籍详情 / 账号类 DTO | 待领取 | 全平台 | API client 与网关协议测试 | Phase 4.5 |
| 路由 | 复杂 reader / book detail route helper 或 typed route | `router.dart`、`reader_route.dart`、`book_detail_route.dart` | 待领取 | 全平台 | `dart run tool/check_route_inventory.dart` | Phase 4.6 |
| 表单 | 认证表单共享 validation model 或 `formz` 试点 | 登录、注册、资料编辑页面 | 待领取 | 全平台 | auth / profile widget tests | Phase 4.7 |
| DI | 业务 service 静态单例 provider 化 | `SourceHealthService.instance` 等业务单例 | 待领取 | 全平台 | provider override 单元测试 | Phase 4.8 |
| 日志 | `AppLogger.error` 到监控 SDK adapter 选型 | `app_logger.dart`、本地日志导出 | 待领取 | 全平台，需隐私开关 | logger / diagnostics tests | Phase 4.9 |

迁移准入规则：

- 必须保持 Riverpod、GoRouter、Dio、Drift 主架构不变，不为单个试点引入替代主栈。
- 必须保持行为等价，尤其阅读器移动端手势、翻页、加载、预加载和错误回退不回退。
- 必须保留旧字段、旧缓存 payload、旧存储 key 和数据库迁移兼容；不能为了 codegen 删除兼容逻辑。
- 每次迁移必须至少有单元测试、smoke test 或 guard 覆盖；没有测试的高风险页面只允许先抽离纯逻辑。
- 回滚方式：撤回本次试点文件的 provider / generated model 接入，保留原手写模型或页面私有 controller；不得清理用户数据或缓存作为回滚前提。

## 6. Phase 4.2：高风险页面状态管理收口试点

当前判断：

- 项目主状态管理已经是 Riverpod，方向合理。
- `reader_page.dart`、`bookshelf_page.dart`、`advanced_theme_list_page.dart`、`advanced_theme_editor_page.dart`、`search_page.dart` 等仍有大量页面私有字段、`setState`、`ValueNotifier` 和手动订阅。
- 这些状态已经超过普通临时 UI 状态的范围，继续堆在页面层会影响测试、拆分和生命周期清理。

任务：

- [x] 梳理 `reader_page.dart` 页面状态，区分 UI 临时态、业务态、运行态、缓存态、平台态。
- [x] 将阅读器业务态迁移到 `ReaderSessionController` / Riverpod `Notifier` 或 `AsyncNotifier`。
- [ ] 将书架筛选、排序、选择、卡片加载态迁移到 Riverpod state model。
- [ ] 将高级主题列表和编辑器的长生命周期状态迁移到 feature provider。
- [ ] 页面只负责渲染和意图分发，不再直接维护跨页面业务状态。
- [x] 新增状态模型优先使用 `freezed`，避免手写大段 `copyWith`。

通过标准：

- [ ] 关键页面 `setState` 数量明显下降。
- [x] 跨页面共享状态不再藏在页面私有字段里。
- [x] 迁移后的 controller / notifier 有最小单元测试。
- [x] 移动端阅读器默认手势和体验不回退。

阶段完成条件：

- [x] 至少完成一个高风险页面的状态迁移试点。
- [x] 对应页面 smoke / controller 测试通过。
- [x] 记录未迁移状态和下一批候选。

试点进展（2026-06-03）：

- 已将阅读器章节加载、预加载、分页 task generation 的 controller 暴露为 `readerSessionControllerProvider`，采用 Riverpod `NotifierProvider.family` 按页面打开 scope 隔离，避免多阅读器实例共享 generation。
- `reader_page.dart` 不再直接创建普通 `ReaderSessionController`，改为从 provider family 读取 notifier；页面关闭时主动 `cancelAll()` 并 `invalidate` 当前 scope。
- 保留原 `ReaderSessionController` 纯 Dart API，作为行为等价回滚点，也方便后续继续单测。
- 新增 provider 级单测覆盖 generation snapshot 发布和不同 reader scope 隔离。

本轮状态分类：

| 类型 | 示例 | 本轮处理 |
| --- | --- | --- |
| 业务态 / 运行态 | chapter content、preload、pagination generation token | 已迁入 provider family 试点 |
| UI 临时态 | overlay、drag、tap、动画 controller、临时 sheet 状态 | 暂留页面层 |
| 缓存态 | 分页缓存、章节窗口、预缓存图片 URL | 暂留服务 / 页面层，后续与缓存治理联动 |
| 平台态 | 音量键、电量、亮度、系统 UI | 暂留 adapter + 页面生命周期 |
| 跨页面候选 | 书架筛选排序、高级主题编辑 session、搜索渲染状态 | 记录为下一批候选 |

本阶段剩余收口项：

- `bookshelf_page.dart`：筛选、排序、选择、卡片加载 `ValueNotifier`。
- `advanced_theme_list_page.dart` / `advanced_theme_editor_page.dart`：长生命周期编辑状态和资源引用状态。
- `search_page.dart` / `search_render_state_controller.dart`：搜索进度和渲染批次状态。
- `reader_page.dart`：继续降低页面层 `setState` 数量，让页面更接近只负责渲染和意图分发。

## 7. Phase 4.3：模型与 JSON 代码生成试点

当前判断：

- 项目已经引入 `freezed`，但大量旧实体仍手写 `toJson`、`fromJson`、`copyWith`、`hashCode`、字段读取 helper。
- 典型风险文件包括 `app_advanced_theme.dart`、`reader_settings.dart`、`reading_progress.dart`、`bookmark.dart`、`reader_document.dart`、`bottom_nav_icon_gallery.dart`、`feedback_models.dart`、`reader_pagination_models.dart`。
- 这些代码不适合一次性机械迁移，但新增和改动窗口应默认用生成工具。

任务：

- [x] 为新增复杂状态模型默认使用 `freezed`。
- [x] 为新增 API DTO 默认使用 `json_serializable`。
- [x] 选择一组低风险模型试点迁移，保留旧字段兼容测试。
- [ ] 优先迁移阅读器状态、分页缓存 payload、反馈 / 会员 / 用户等 DTO。
- [ ] 高级主题模型只在测试覆盖充分时分批迁移。
- [ ] 建立“禁止新增复杂手写 JSON 模型”的开发规则回归检查。

通过标准：

- [x] 新增模型不再手写大段 `copyWith` / JSON。
- [x] 试点模型迁移前后兼容测试通过。
- [x] `build_runner` 生成流程纳入常规验证。

阶段完成条件：

- [x] 至少完成一组低风险模型的 codegen 迁移。
- [x] 兼容旧 JSON 字段的测试通过。
- [ ] 新增复杂模型默认使用生成工具的规则已同步。

试点进展（2026-06-03）：

- `ReaderSessionGenerationState`、`ReaderVisiblePosition`、`ReaderViewportSession`、`ReaderSessionState` 已迁移到 `freezed`，生成 `copyWith`、equality 和调试输出。
- `ReaderPagedSlice` 已迁移到 `json_serializable`，保留缺字段默认值，兼容旧分页缓存 payload。
- 新增 `json_annotation` 直接依赖与 `json_serializable` dev 依赖，生成文件纳入源码。
- 生成命令：`dart run build_runner build --delete-conflicting-outputs`。当前 build_runner 可完成生成，但 `json_serializable 6.11.4` 会提示包 language version 3.7 与其建议范围 `^3.8.0` 不一致；本阶段不抬 SDK，先记录为后续依赖治理约束。

新增规则：

- 新增复杂状态模型默认使用 `freezed`，仅纯值对象且无 `copyWith` / equality 需求时允许手写。
- 新增 JSON DTO / payload 默认使用 `json_serializable`，保留旧字段默认值和兼容测试。
- 已有高风险模型不得机械一次性迁移；主题、阅读进度、书签、用户数据类模型必须先补足兼容测试。

本阶段剩余收口项：

- 高级主题模型仍未迁移，需先补足兼容测试后分批处理。
- “禁止新增复杂手写 JSON 模型”仍只是文档规则，后续需要接入 guard 或 review checklist。

## 8. Phase 4.4：网络图片与封面缓存替代

当前判断：

- 项目有手写 `CoverImageDiskCache` 和 `DiskCachedCoverImage`，包含下载、并发门、过期、磁盘清理、降级展示。
- 这类能力属于成熟库擅长的通用问题，应优先替换为稳定图片缓存库。

推荐方案：

- 首选 `cached_network_image` + `flutter_cache_manager`。
- 如需要更复杂的手势、缩放或图片状态，再评估 `extended_image`。
- 继续保留项目自己的封面解析、占位、业务 fallback 和缓存治理入口。

任务：

- [ ] 建立统一 `ResolvedBookCover` 图片加载适配层。
- [ ] 用成熟库替换 `CoverImageDiskCache` 的下载、磁盘缓存和过期逻辑。
- [ ] 将封面缓存继续纳入 `AppCacheGovernanceService`。
- [ ] 确认 Web JS、macOS、Android、iOS 行为一致或有明确降级。
- [ ] 删除或冻结旧手写缓存实现。

通过标准：

- [ ] 封面加载、失败占位、缓存命中、清理都可验证。
- [ ] 缓存治理不误删用户资产。
- [ ] 不再维护手写下载并发和磁盘过期逻辑。

阶段完成条件：

- [ ] 封面缓存替代完成。
- [ ] Web / Native 降级策略确认。
- [ ] 缓存治理测试通过。

## 9. Phase 4.5：API 客户端与网关通信治理

当前判断：

- 项目已经集中使用 Dio，未发现大量裸 `http.get` + `jsonDecode`。
- `ApiClient` 已集中处理通用 REST 请求、重试、缓存、token 刷新。
- 仍有手写 cookie jar、REST DTO 解析、SSE event parser 等样板。

推荐方案：

- 保留 Dio 作为网络底座。
- REST API 可以逐步接入 `retrofit` + `json_serializable`。
- cookie 管理优先使用 `dio_cookie_manager` + `cookie_jar`。
- SSE / 服务器书源网关流式协议如果业务强定制，可以继续保留手写 parser，但要封装边界和测试。

任务：

- [ ] 盘点 REST 端点，区分普通 REST 与流式网关。
- [ ] 选择低风险 REST service 试点 `retrofit`。
- [ ] 将 cookie jar 从手写 Map 迁到成熟 cookie 管理库。
- [ ] 将 API 响应 DTO 迁移到生成模型。
- [ ] 为网关 SSE parser 保留协议测试，避免误迁。

通过标准：

- [ ] REST service 请求样板减少。
- [ ] cookie 行为有回归测试。
- [ ] 在线搜索、详情、目录、正文流式链路不回退。

阶段完成条件：

- [ ] 至少一个 REST service 完成 codegen 或 typed DTO 试点。
- [ ] cookie 管理迁移或保留理由明确。
- [ ] 网关流式协议测试通过。

## 10. Phase 4.6：路由字符串与 typed route 治理

当前判断：

- 项目已经使用 GoRouter，方向合理。
- 页面里仍散落 `context.go('/bookshelf')`、`context.push('/membership')` 等硬编码字符串。

推荐方案：

- 短期：集中 route path / route name 常量和 route helper。
- 中期：评估 `go_router_builder` 的 typed route，逐步替换复杂参数路由。

任务：

- [ ] 建立 route name / path 常量规范。
- [ ] 为书籍详情、阅读器、本地阅读、主题编辑等参数复杂路由创建 helper。
- [ ] 避免页面自行拼 query string。
- [ ] 路由清单和 `check_route_inventory.dart` 同步更新。

通过标准：

- [ ] 新增导航不再手写裸字符串。
- [ ] 复杂路由参数有单元测试。
- [ ] route inventory 保持绿色。

阶段完成条件：

- [ ] 新增导航不再直接写裸字符串。
- [ ] 至少一条复杂参数路由完成 helper / typed route 迁移。
- [ ] `check_route_inventory.dart` 通过。

## 11. Phase 4.7：表单与验证统一

当前判断：

- 登录、注册、资料编辑等页面仍手写 validator、密码强度、确认密码逻辑。
- 当前规模不需要急于引入大型表单框架，但重复继续增长时应收口。

推荐方案：

- 认证表单和资料表单优先试点 `formz`。
- 简单设置表单继续使用 Flutter 原生控件和项目内部 validator。

任务：

- [ ] 将账号、密码、确认密码、邮箱、手机号等规则收敛到统一验证模型。
- [ ] 登录 / 注册表单试点 `formz` 或共享 validation service。
- [ ] 保留服务端错误展示和当前交互体验。

通过标准：

- [ ] 重复 validator 数量下降。
- [ ] 表单错误文案一致。
- [ ] 登录、注册、资料编辑测试通过。

阶段完成条件：

- [ ] 认证或资料表单完成一个验证模型试点。
- [ ] 重复 validator 有统一落点。
- [ ] 表单交互和服务端错误展示不回退。

## 12. Phase 4.8：依赖注入与全局单例治理

当前判断：

- Riverpod 已承担主要依赖注入，不需要引入 `get_it`。
- 仍有 `AppDatabase.instance`、`SourceHealthService.instance`、`AuthEventBus.instance`、`CoverImageDiskCache.instance`、`AppLogger.instance` 等静态单例。
- 静态单例会降低测试替换和生命周期治理能力。

任务：

- [ ] 盘点全局 `instance` 和静态 `StreamController`。
- [ ] 优先将业务 service 单例迁移为 provider 管理。
- [ ] 保留底层日志等少数基础设施单例，但通过 provider 暴露。
- [ ] 页面不得直接访问 `*.instance`，必须通过 provider / dependency factory。

通过标准：

- [ ] 页面层直接使用静态单例数量下降。
- [ ] 测试可通过 provider override 替换依赖。
- [ ] 事件流订阅有明确生命周期。

阶段完成条件：

- [ ] 全局 `instance` 清单完成。
- [ ] 至少迁移一个业务 service 到 provider 生命周期管理。
- [ ] 页面层直接访问静态单例数量下降。

## 13. Phase 4.9：日志与错误监控接入

当前判断：

- 项目已用 `logger`，不是散落 `print()`。
- 本地诊断日志 `SourceLogStore` 对开发和用户反馈有价值。
- 缺少生产环境错误监控和 crash 上报。

推荐方案：

- 保留 `logger` + 本地诊断导出。
- 生产监控评估 `sentry_flutter` 或 `firebase_crashlytics`。
- Web / Desktop / Mobile 上报开关和隐私策略必须明确。

任务：

- [ ] 建立错误监控选型结论：Sentry 或 Firebase Crashlytics。
- [ ] 明确采集范围、脱敏规则、用户开关和平台支持范围。
- [ ] 将 `AppLogger.error` 与监控 SDK 适配。
- [ ] 继续保留本地日志导出。

通过标准：

- [ ] crash / error 可在目标平台捕获。
- [ ] 日志不泄露 token、路径敏感信息或用户正文内容。
- [ ] 诊断导出仍可用。

阶段完成条件：

- [ ] 错误监控选型结论完成。
- [ ] 隐私、脱敏、平台支持范围确认。
- [ ] `AppLogger.error` 到监控 SDK 的适配方案完成或明确延后。

## 14. 已合理项目，保持不迁移

以下方向当前已合理，不作为第四里程碑替换目标：

- 状态管理主栈：继续 Riverpod，不迁 Bloc / GetX。
- 路由主栈：继续 GoRouter，不迁 auto_route / beamer。
- 数据库主栈：继续 Drift，不迁 floor / objectbox。
- 轻量偏好：继续 SharedPreferences，但复杂结构要转 typed service / Drift / 文件索引。
- 安全凭证：继续 flutter_secure_storage，并保留必要 fallback。
- 平台能力：继续 capability / adapter / conditional import。
- UI 组件：继续 Material + 项目 adaptive 组件，不引入大型 UI 套件。
- 阅读器核心动画：保留业务定制，不为装饰性库强行替换。

## 15. Phase 4.10：总体验收、回归和文档收口

建议测试：

```bash
flutter test test/features/reader/application/reader_session_controller_test.dart
flutter test test/features/bookshelf/application/bookshelf_provider_smoke_test.dart
flutter test test/core/cache/app_cache_governance_service_test.dart
flutter test test/core/network/api_client_test.dart test/core/network/http_client_test.dart
flutter test test/features/auth/application/auth_provider_smoke_test.dart
```

建议 guard：

```bash
flutter analyze
dart run tool/check_architecture_guardrails.dart
dart run tool/check_storage_governance_guard.dart
dart run tool/check_route_inventory.dart
flutter build web --no-pub
```

通过标准：

- [ ] 不新增复杂手写状态模型、JSON DTO 和裸路由字符串。
- [ ] 高风险页面状态迁移至少完成一个核心页面。
- [ ] 封面缓存替代完成并通过缓存治理测试。
- [ ] REST DTO / route helper / form validation 至少各完成一个试点。
- [ ] Web JS 构建通过。
- [ ] Android / iOS 关键体验不回退。

阶段完成条件：

- [ ] Phase 4.1-4.9 总览项全部完成或明确延期。
- [ ] 所有新增依赖和生成工具有平台支持结论。
- [ ] README、架构计划、相关 guard 文档完成同步。

## 16. 风险

- [ ] 代码生成迁移可能破坏旧字段兼容，需要补兼容测试。
- [ ] 图片缓存替换可能影响 Web 和 Desktop 缓存清理语义。
- [ ] 状态迁移容易改动阅读器行为，必须小步等价迁移。
- [ ] typed route 迁移可能影响深链和 query 参数。
- [ ] 错误监控接入必须处理隐私、脱敏和平台差异。

## 17. 执行记录

- [ ] 开始日期：
- [ ] 完成日期：
- [ ] 已验证平台：
- [ ] 未验证平台和原因：
- [ ] 关键改动：
- [ ] 遗留问题：
