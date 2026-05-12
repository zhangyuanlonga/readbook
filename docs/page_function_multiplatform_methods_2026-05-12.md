# 逐页面功能多端兼容方法

更新时间：2026-05-12  
用途：补齐“每个页面的功能怎么做多端兼容”的执行方法，和 UI 展示计划分工。  
关系：`docs/all_platform_compatibility_plan_2026-05-11.md` 负责阶段闭环；`docs/page_ui_multiplatform_display_plan_2026-05-12.md` 负责页面展示形态；本文件负责页面功能、平台能力、降级方法和验收点。

## 0. 结论先行

逐页面功能兼容不按“这个页面里写 Android / iOS / Web 分支”推进，而按下面顺序推进：

1. 页面先定义自己的核心功能。
2. 每个功能绑定一个 capability、service 或 bridge。
3. 不支持的平台只能隐藏、禁用、占位或 no-op，不能出现可点击但必失败的入口。
4. Web 首版按受限模式处理，本地阅读、设置浏览和基础记录优先，书源运行时继续排除。
5. 每完成一个页面功能阶段，都要回填本文的状态和验证结果。

一句话口径：

**页面只表达“能不能做这件事”，平台差异进入 capability / service / bridge，不进入页面散点判断。**

## 1. 方法分层

| 层级 | 负责内容 | 允许平台差异 | 页面能看到什么 |
| --- | --- | --- | --- |
| Capability | 功能是否可用 | 是 | `supportsLocalFileImport`、`supportsWebDavSync` 这类语义能力 |
| Application Service | 功能流程编排 | 是，但需收口 | 导入、重索引、清理缓存、导出日志等用例 |
| Bridge / Adapter | 原生或 Web 专属实现 | 是 | 稳定 Dart 模型或 no-op 结果 |
| Presentation | 展示和交互分发 | 否，除 UI 自适应 | 禁用态、占位态、调用 service |

强制规则：

- 页面不得直接 import `dart:io`、`drift/native.dart`、WebView / JS runtime、MethodChannel。
- 页面不得用 `Platform.isXxx` 决定业务功能是否可用。
- UI 差异参考 UI 展示计划；功能差异参考本文和 `AppPlatformCapabilities`。
- 新增功能入口必须同时写清 Android、iOS、macOS、Windows、Linux、Web 的状态。

## 2. 平台功能等级

| 等级 | 含义 | 首版处理 |
| --- | --- | --- |
| P0 | 首版必须可用 | 移动端和桌面端完整验收 |
| P1 | 首版可受限 | Web 或格式能力可先降级，但不能白屏或崩溃 |
| P1+ | 独立开关能力 | 通过 dart-define 或设置开关显式启用 |
| P2 | 后续专题 | 入口隐藏或标记后续支持 |
| 延期 | 本轮排除 | 书源运行时、在线搜索、登录调试等 |

## 3. 全局页面功能入口

| 页面/入口 | 核心功能 | 移动端 | 桌面端 | Web | 方法边界 | 降级 |
| --- | --- | --- | --- | --- | --- | --- |
| App Shell | 启动、导航、路由守卫 | P0 | P0 | P1 | `AppPlatformCapabilities`、router guard | 受限页不能空白 |
| 启动任务 | 资源迁移、维护、预热 | P0 | P0 | P1 受限 | `AppStartupCoordinator` 按 capability 跳过 | no-op + 日志 |
| 主导航 | 首页、书架、记录、我的 | P0 | P0 | P1 | 导航项由 capability 过滤 | 延期入口隐藏 |
| 全局占位 | 不支持能力说明 | P0 | P0 | P1 | `FeatureDisabledPage` 或统一 disabled view | 禁用说明 + 返回路径 |

全局待办：

- [x] 书源、同步等延期能力已经接入占位或能力开关。
- [x] Web 首屏已避免外网 CanvasKit 依赖和 native-only 插件注册中断。
- [ ] 所有页面的受限入口统一到同一种 disabled 组件和文案模型。
- [ ] 每个路由补“能力关闭时不会创建重依赖”的回归测试。

## 4. P0 页面功能方法

### 4.1 首页 `HomePage`

核心功能：

- 继续阅读、最近阅读、阅读统计、阅读目标、快捷入口。

多端方法：

- 阅读统计和最近阅读只依赖数据库查询 service，不直接访问 `AppDatabase`。
- 继续阅读入口必须区分本地图书与在线图书；首版只保证本地图书可恢复。
- 书源关闭时，在线推荐、发现和在线搜索快捷入口不出现。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 继续阅读本地图书 | P0 | P0 | P1 | `ReadingRecordService` + 本地 reader route |
| 阅读统计 | P0 | P0 | P1 | 查询 service，Web 取决于 Drift Web 存储 |
| 在线推荐/发现 | 延期 | 延期 | 延期 | `supportsSourceRuntime` |

待办：

- [ ] 继续阅读只跳转可用的本地阅读路径；不可用时展示统一占位。
- [ ] 首页统计在 Web 存储未 ready 时显示空状态，不触发异常。

### 4.2 书架页 `BookshelfPage`

核心功能：

- 本地书籍展示、排序筛选、继续阅读、选择、删除、导入入口。

多端方法：

- 书架列表只消费 repository/query service 暴露的书籍模型。
- 导入入口通过 `supportsLocalFileImport` 控制。
- 删除、归档、封面展示通过托管存储 service，不在页面拼文件路径。
- 在线搜索入口通过 `supportsSourceRuntime` 控制，默认隐藏。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 本地图书列表 | P0 | P0 | P1 | bookshelf query service |
| 排序筛选 | P0 | P0 | P1 | provider state |
| 本地文件导入 | P0 | P0 | P1 受限 | `supportsLocalFileImport` + import service |
| 在线搜索 | 延期 | 延期 | 延期 | `supportsSourceRuntime` |

待办：

- [x] 导入入口已按 capability 禁用。
- [ ] 批量删除和本地文件清理确认不直接依赖页面文件路径。
- [ ] Web 无文件导入时保持书架浏览和设置入口可用。

### 4.3 本地书库页 `LocalLibraryPage`

核心功能：

- 导入本地图书、索引、重索引、查看导入状态、删除本地条目。

多端方法：

- 文件选择和系统分享只进入 import service / bridge。
- 页面只读取 `supportsLocalFileImport`、`supportsManagedFileStorage` 和导入状态。
- 文件名、格式、索引状态由 application 层产出，不在页面使用 `File`。
- Web 首版可以浏览已有数据，但导入和重索引需根据存储能力禁用。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 文件选择导入 | P0 | P0 | P1 受限 | `LocalBookImportService` |
| 系统分享/打开方式 | P0 | P2 | 不支持 | platform bridge |
| 重索引 | P0 | P0 | P1 受限 | local parser + managed storage |
| 删除本地资源 | P0 | P0 | P1 受限 | storage service |

待办：

- [x] 页面已移除直接 `dart:io File` 依赖。
- [ ] 重索引前统一检查 `supportsManagedFileStorage`。
- [ ] Web 未来如接 File System Access API，必须新增 Web adapter，不改页面。

### 4.4 书籍详情页 `BookDetailPage`

核心功能：

- 元信息、封面、简介、目录入口、继续阅读、编辑、删除、重索引。

多端方法：

- 本地图书详情走 local book repository，不触发 source runtime。
- 封面选择通过 `supportsImagePicking` 和 image selection service。
- 切换书源、在线详情、在线章节更新必须挂 `supportsSourceRuntime`。
- 删除和重索引通过 application service，页面不直接操作文件。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 本地详情展示 | P0 | P0 | P1 | repository/query service |
| 继续阅读/目录入口 | P0 | P0 | P1 | local reader route |
| 元信息编辑 | P0 | P0 | P1 | book application service |
| 封面编辑 | P0 | P0 | P1 受限 | `supportsImagePicking` |
| 切换书源 | 延期 | 延期 | 延期 | `supportsSourceRuntime` |

待办：

- [x] 切换书源已按 capability 禁用并补测试。
- [ ] 封面编辑在 Web 和不支持图片选择的平台显示统一禁用态。
- [ ] 删除本地图书时区分“只删记录”和“删除托管文件”的能力文案。

### 4.5 阅读器 `ReaderPage`

核心功能：

- 打开本地章节、翻页/滚动、目录跳转、书签、进度保存、阅读设置、亮度/音量键桥接。

多端方法：

- 章节读取统一走 `ReaderDocument` / local reader application 层。
- 移动端亮度、音量键走 `ReaderPlatformBridgeService`。
- 桌面和 Web 桥接默认 no-op，不影响阅读主流程。
- 键盘、滚轮、窗口变化属于输入能力，不进入原生分支。
- 在线章节缓存、换源阅读、WebView 内容抓取默认排除。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 本地章节阅读 | P0 | P0 | P1 | local reader pipeline |
| 目录跳转 | P0 | P0 | P1 | reader session/controller |
| 书签 | P0 | P0 | P1 | bookmark service |
| 进度保存 | P0 | P0 | P1 | reading record service |
| 亮度桥 | P0 | no-op | no-op | `supportsReaderBrightnessBridge` |
| 音量键翻页 | P0 | no-op | no-op | `supportsReaderVolumeKeyBridge` |
| 在线章节 | 延期 | 延期 | 延期 | `supportsSourceRuntime` |

待办：

- [ ] 桌面键盘翻页和鼠标滚轮作为 P0 输入能力补验收。
- [ ] 窗口尺寸变化后分页恢复进入 reader service 测试。
- [ ] Web 存储未 ready 时阅读器展示可恢复错误，不白屏。

### 4.6 阅读记录页 `ReadingRecordsPage`

核心功能：

- 最近阅读、统计、日历/热力、记录跳转、清理记录。

多端方法：

- 记录查询走 `ReadingRecordsQueryService`。
- 跳转时先判断目标书籍和章节是否仍可用。
- Web 只要数据库可用就应展示，数据库不可用时显示空状态和说明。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 最近记录 | P0 | P0 | P1 | query service |
| 统计 | P0 | P0 | P1 | query service |
| 跳转阅读 | P0 | P0 | P1 | local route guard |
| 清理记录 | P0 | P0 | P1 | application service |

待办：

- [ ] 记录跳转补“本地章节缺失/资源受限”的统一占位。
- [ ] Web 数据库初始化失败时不触发页面异常。

### 4.7 书签页 / 目录书签面板

核心功能：

- 添加书签、删除书签、从书签跳转、按书籍筛选。

多端方法：

- 书签服务只保存稳定书籍和章节定位，不保存平台文件句柄。
- 阅读器内添加书签通过 reader controller 转发，不直接写数据库。
- Web 数据库受限时显示不可持久化或空状态。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 添加/删除书签 | P0 | P0 | P1 | bookmark service |
| 跳转定位 | P0 | P0 | P1 | reader route + chapter locator |
| 书籍筛选 | P0 | P0 | P1 | query service |

待办：

- [ ] 书签定位失败时统一提示并保留记录。
- [ ] 书签服务补 Web 受限存储测试。

### 4.8 我的页 `MinePage`

核心功能：

- 账号概览、设置入口、缓存、错误中心、同步、关于、反馈。

多端方法：

- 入口是否出现由 capability 或登录状态 provider 控制。
- 同步默认 P1+，`supportsWebDavSync=false` 时显示占位。
- 缓存和诊断导出通过 `supportsManagedFileStorage` 降级。
- 反馈和关于不应依赖本地文件系统。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 设置/关于/反馈 | P0 | P0 | P1 | route + service |
| 缓存管理 | P0 | P0 | P1 受限 | `supportsManagedFileStorage` |
| 错误中心 | P0 | P0 | P1 受限 | error service |
| WebDAV 同步 | P1+ | P1+ | 暂缓 | `supportsWebDavSync` |

待办：

- [x] 同步、缓存、错误中心已接能力开关或受限提示。
- [ ] 我的页入口统一展示“可用/受限/后续支持”状态。

### 4.9 系统设置页 `SystemSettingsPage`

核心功能：

- 通用设置、阅读偏好、外观入口、数据/隐私、实验能力开关。

多端方法：

- 设置项只保存语义值，不保存平台 UI 尺寸或原生路径。
- 与能力有关的开关必须读取 capability，不能让用户打开必失败能力。
- Web 受限设置项可以展示但禁用，并说明原因。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 阅读偏好 | P0 | P0 | P1 | preferences provider |
| 外观设置 | P0 | P0 | P1 | theme/resource service |
| 数据维护 | P0 | P0 | P1 受限 | storage/database service |
| 实验能力 | P1+ | P1+ | P1+ | capability + dart-define |

待办：

- [ ] 禁用项统一解释“当前平台不支持”还是“首版未启用”。
- [ ] 设置保存补跨端默认值回归测试。

### 4.10 外观与资源页面

核心功能：

- 主题、阅读背景、启动图、封面、底部导航图标、字体。

多端方法：

- 图片选择通过 image selection service。
- 托管资源通过 managed storage service，不在页面保存绝对路径。
- Web 端优先展示内置资源和占位，自定义本地资源作为 P1 后续能力。
- 字体恢复、资源迁移等启动任务按 capability 跳过。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 内置主题 | P0 | P0 | P1 | theme provider |
| 自定义图片资源 | P0 | P0 | P1 受限 | image selection + managed storage |
| 字体资源 | P0 | P0 | P1 受限 | font registry |
| 启动图显示 | P0 | P0 | P1 | conditional image provider |

待办：

- [x] 启动图文件渲染已通过条件导入避免 Web `dart:io`。
- [ ] 所有资源页面统一处理“资源文件不存在/平台不支持”占位。

### 4.11 缓存管理页

核心功能：

- 查看缓存占用、清理缓存、导出/复制诊断信息。

多端方法：

- 缓存统计由 service 汇总，不在页面枚举目录。
- 清理动作按 `supportsManagedFileStorage` 分级。
- Web 端不支持文件清理时只保留可复制诊断摘要。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 缓存统计 | P0 | P0 | P1 受限 | cache service |
| 批量清理 | P0 | P0 | P1 受限 | storage service |
| 诊断摘要 | P0 | P0 | P1 | diagnostic service |

待办：

- [x] 页面已接 `supportsManagedFileStorage`。
- [ ] Web 只复制摘要时不出现“已导出文件”文案。

### 4.12 错误中心页

核心功能：

- 错误列表、复制、导出、清理、诊断说明。

多端方法：

- 错误数据由 error repository/service 提供。
- 导出文件通过 storage/share adapter；Web 默认复制文本。
- 页面不直接拼日志路径。

平台状态：

| 功能 | 移动端 | 桌面端 | Web | 方法 |
| --- | --- | --- | --- | --- |
| 错误列表 | P0 | P0 | P1 | error query service |
| 复制错误 | P0 | P0 | P1 | clipboard service |
| 导出文件 | P0 | P0 | P1 受限 | storage/share adapter |
| 清理错误 | P0 | P0 | P1 | application service |

待办：

- [x] 页面已接 `supportsManagedFileStorage`。
- [ ] 导出失败时提供复制兜底，不丢错误内容。

## 5. 延期页面功能方法

| 页面/功能 | 首版状态 | 隔离方法 | 后续恢复条件 |
| --- | --- | --- | --- |
| 书源管理 | 延期 | `supportsSourceRuntime=false` 隐藏或占位 | runtime、WebView、调试和同步专题恢复 |
| 在线搜索 | 延期 | 主入口隐藏；搜索页可改本地搜索 | 本地搜索先独立完成，在线搜索随书源恢复 |
| 发现页 | 延期/本地化 | 隐藏或静态本地内容 | 有本地推荐策略或书源运行时恢复 |
| 书源登录/WebView | 延期 | `supportsInteractiveWebView=false` | 多端 WebView 能力矩阵完成 |
| 脚本编辑/调试 | 延期 | `supportsSourceDebugServer=false` | 调试服务跨端安全边界完成 |
| WebDAV 同步 | P1+ | `supportsWebDavSync=false` 默认占位 | 显式 dart-define + 同步矩阵通过 |

延期规则：

- 不能删除已有代码。
- 不能让延期入口进入后再报错。
- 恢复时必须走独立阶段，不和本地阅读闭环混在一起。

## 6. 分阶段执行

### 功能阶段 A：页面能力盘点

目标：每个页面都能回答“哪些功能可用、靠哪个 capability、不可用怎么降级”。

- [x] 建立本文作为逐页面功能方法索引。
- [ ] 为每个页面补齐 capability / service / bridge 归属。
- [ ] 找出页面内残留的平台判断、文件路径操作、直接数据库访问。
- [ ] 标记延期功能入口和恢复条件。

验收：

- 每个 P0 页面都有移动端、桌面端、Web 三列功能状态。
- 新增或修改页面时能直接查到该走哪个能力边界。

### 功能阶段 B：本地阅读主链路

目标：书架、本地书库、详情、阅读器、书签、记录形成 P0 闭环。

- [ ] 书架和本地书库只通过 service 暴露导入、索引、删除状态。
- [ ] 详情页本地编辑、封面、删除、重索引走 application service。
- [ ] 阅读器桌面键盘、鼠标滚轮、窗口变化恢复补齐。
- [ ] 书签和阅读记录跳转失败时统一占位。

验收：

- Android、iOS、macOS、Windows、Linux 可完成导入、阅读、书签、记录恢复。
- Web 不能导入时仍可启动、浏览和显示受限说明。

### 功能阶段 C：个人业务和资源管理

目标：我的、设置、外观、缓存、错误中心在多端可用或明确受限。

- [ ] 设置项按 capability 禁用，避免开启必失败能力。
- [ ] 外观资源统一走 image selection / managed storage。
- [ ] 缓存和错误导出提供复制兜底。
- [ ] Web 启动任务只跑 Web 可承受任务。

验收：

- 不支持本地托管存储的平台不出现文件清理假成功。
- 资源缺失和导出失败都有可恢复提示。

### 功能阶段 D：延期入口隔离

目标：首版不被书源、在线搜索、WebView 登录和调试能力拖住。

- [ ] 书源页、在线搜索、发现、登录、调试全部经过 capability。
- [ ] 启动任务不恢复书源健康状态，不上报书源运行时诊断。
- [ ] 详情和阅读器不出现可点击的在线换源或在线章节入口。

验收：

- 不配置书源、不联网也能完整使用本地阅读。
- 首版路径中不会出现“书源执行失败”类错误。

### 功能阶段 E：页面级验证矩阵

目标：每个页面的功能兼容都有固定验证。

- [ ] `flutter analyze`
- [ ] 页面 capability 单元测试。
- [ ] 路由守卫和 disabled page widget test。
- [ ] 本地阅读 smoke：导入、打开、目录、书签、记录恢复。
- [ ] Web：`flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`。
- [ ] 桌面：至少 macOS run；Windows/Linux 在对应主机补矩阵。

验收记录模板：

```text
页面：
阶段：
影响平台：
不影响平台：
能力边界：
降级方式：
验证命令：
遗留风险：
```

## 7. 当前优先级

1. 先完成 P0 本地阅读主链路：书架、本地书库、详情、阅读器、书签、记录。
2. 再完成个人业务：我的、设置、外观、缓存、错误中心。
3. Web 继续走受限模式：先保证启动、浏览、占位和不白屏。
4. 书源、在线搜索、发现在线内容、WebView 登录和调试继续延期。
5. UI 展示变化只在 UI 展示计划里维护；本文只记录功能方法和能力边界。
