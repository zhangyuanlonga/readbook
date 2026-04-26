# 开发架构约束

更新时间：2026-04-26  
用途：作为当前项目后续开发的强约束文档，统一目录、依赖、Riverpod、路由、原生桥接、测试和代码评审口径，避免架构继续发散。

## 0. 结论先行

当前项目后续一律按这套口径收口：

- 总体架构：`Feature-first + Application + Riverpod DI`
- Flutter 角色：统一 UI、状态、业务流程、跨端复用
- 原生角色：只做系统入口和平台专属能力适配
- 组合根位置：`app/` 与 feature provider
- 页面职责：只负责渲染、交互分发、订阅状态
- 禁止事项：页面直接 new 仓库 / service，页面直接依赖 `AppDatabase`，页面直接调用 `MethodChannel`

一句话总结：

- **业务统一进 Flutter**
- **依赖统一进 Provider**
- **平台能力统一走 Bridge**
- **页面不再充当组装层**

---

## 1. 适用范围

本约束适用于：

- 新增 feature
- 修改现有 feature
- Flutter 与原生桥接
- 路由扩展
- 本地存储与网络接入
- 测试与 code review

本约束不是“完全推翻当前代码后重建”，而是作为**从当前状态继续演进的唯一口径**。

---

## 2. 目标架构

### 2.1 总体分层

```text
app
  ├─ composition / shell / theme / top-level router
core
  ├─ cross-feature infrastructure
runtime
  ├─ script source runtime and host bridge
domain
  ├─ shared pure models + shared repository contracts
data
  ├─ shared repository implementations + shared datasources
features
  ├─ feature presentation + application + feature-local providers/routes
shared
  ├─ generic reusable widgets/utilities only
```

### 2.2 目录职责

`lib/app/`

- 只放应用级组合根
- 只放全局主题、外壳、顶层导航、启动装配
- 不承载具体 feature 业务流程

`lib/core/`

- 只放跨 feature 基础设施
- 如网络、日志、错误、设备、缓存、认证、系统能力封装
- 不放具体业务页面逻辑

`lib/runtime/`

- 只放脚本源运行时、宿主桥、执行容器
- 不放阅读页 UI 逻辑
- 不放书架、书签、主题之类业务页面状态

`lib/domain/`

- 只放跨 feature 共享的纯 Dart 模型和仓库接口
- 不依赖 Flutter UI、Drift、平台通道
- 只在“确实跨 feature 共享”时新增内容

`lib/data/`

- 只放共享仓库实现、共享 datasource、数据库接入
- 不允许反向依赖 `features/presentation`
- 不放页面编排逻辑

`lib/features/<feature>/`

- 默认是未来新增业务代码的第一落点
- 每个 feature 自己拥有 presentation / application / providers / routes
- 若某个 feature 后续复杂度足够高，可以在 feature 内再细分 `domain/`、`data/`

`lib/shared/`

- 只放真正无业务语义的通用 UI 和工具
- 不能把“暂时没地方放的东西”都堆进来

---

## 3. 推荐目录模板

新增 feature 默认按下面结构：

```text
lib/features/<feature>/
  presentation/
    pages/
    widgets/
    controllers/
  application/
    services/
    coordinators/
    resolvers/
  providers.dart
  routes.dart
```

当 feature 出现跨页面共享模型或接口时，再升级为：

```text
lib/features/<feature>/
  presentation/
  application/
  domain/
  data/
  providers.dart
  routes.dart
```

补充规则：

- 能放 feature 内，就不要先放到全局 `domain/` 或 `data/`
- 只有多个 feature 共享时，才提升为全局模块
- 不再新增“超大综合页面文件”

---

## 4. 依赖方向

### 4.1 允许的依赖

```text
app -> features / core / runtime / shared
features/presentation -> feature/application + app-level UI tokens + shared + domain
features/application -> core + runtime + domain
data -> core + domain
runtime -> core + domain
core -> pure infra only
domain -> pure dart only
```

### 4.2 禁止的依赖

明确禁止：

- `presentation -> data/repositories/*_impl.dart`
- `presentation -> data/datasources/local/app_database.dart`
- `presentation -> MethodChannel/EventChannel`
- `domain -> data`
- `core -> features`
- `runtime -> features/presentation`
- `app -> feature 具体 service 细节编排`

### 4.3 一条判断规则

如果一个类里同时出现下面两类内容，就说明它大概率越界了：

- UI 控件 / 生命周期
- 仓库实现 / 数据库 / 平台桥 / 网络细节

---

## 5. Riverpod 与依赖注入约束

### 5.1 强制规则

- 所有仓库、service、coordinator、facade 的创建都必须进入 Provider 或组合根
- 页面只能 `read/watch/listen` provider，不能自己 `new` 具体基础设施
- Provider 尽量返回抽象接口或稳定服务对象，不向页面暴露底层实现细节
- 新代码禁止继续新增 `xxx.instance` 风格单例，已有单例视为待收敛技术债

### 5.2 页面允许做什么

页面允许：

- 订阅状态
- 分发用户交互
- 管理局部 UI 状态
- 管理短生命周期 controller

页面不允许：

- 创建 `RepositoryImpl`
- 创建 `AppDatabase.instance`
- 直接拼装复杂业务依赖图
- 直接处理平台通道

### 5.3 Provider 落点

- feature 内依赖：优先放 `lib/features/<feature>/providers.dart`
- 应用级依赖：放 `lib/app/` 下的组合根 provider
- 真正跨 feature 的基础设施 provider：放 `core/` 或专门的 app composition 文件

---

## 6. 页面、Controller、Service 三层职责

### 6.1 Presentation

负责：

- 页面布局
- UI 状态展示
- 用户交互入口
- 调用 application 层能力

不负责：

- 业务编排细节
- 仓库装配
- 数据持久化细节
- 平台桥接细节

### 6.2 Application

负责：

- 用例编排
- feature 内状态协调
- 页面之间共用的业务流程
- 外部依赖整合

不负责：

- 原始 SQL / Drift 表定义
- Widget 渲染细节

### 6.3 Data / Runtime / Core

负责：

- 数据访问
- 平台或运行时能力实现
- 持久化
- 网络与宿主桥

不负责：

- 页面行为决策
- feature UI 流程

---

## 7. 路由约束

### 7.1 目标口径

每个 feature 自己维护自己的路由定义。

推荐形式：

- `lib/features/<feature>/routes.dart`
- `lib/app/router.dart` 只负责组装

### 7.2 app/router.dart 允许保留的内容

- 顶层 `GoRouter`
- shell route
- 全局 navigator key
- feature route 聚合

### 7.3 app/router.dart 禁止继续增长的内容

- 具体 feature 的业务判断
- 大量 query/path 参数解析细节
- 直接导入所有页面并长期集中维护

### 7.4 约束规则

- 新增页面时，优先往 feature 自己的 `routes.dart` 加
- 路由参数解析优先放 feature 本地
- 跨 feature 跳转只依赖 route contract，不依赖页面构造细节

---

## 8. 启动与生命周期约束

### 8.1 app 层职责

`App` 只能承担：

- MaterialApp / theme / router
- 全局外壳
- 顶层 composition

### 8.2 需要拆出的内容

以下内容不得继续直接堆在 `App` 根 widget：

- 启动任务编排
- 更新检查
- 公告拉取
- 心跳与埋点访问
- 外部导入订阅
- 数据库预热
- 登录刷新流程

### 8.3 推荐收口方式

- `bootstrap()`：一次性初始化
- `startup coordinator provider`：启动任务
- `lifecycle coordinator provider`：前后台生命周期
- `bridge listener provider`：外部导入、音量键等桥接事件

---

## 9. 原生边界约束

### 9.1 原生层允许承载的内容

- 系统入口
- 文件导入 / Intent / URL open
- 平台专属 SDK
- 音量键、通知、后台服务等系统级能力
- Flutter 插件暂时无法稳定覆盖的能力

### 9.2 原生层禁止承载的内容

- 阅读业务规则
- 书架业务规则
- 搜索编排
- 文本解析业务决策
- 主题业务逻辑

### 9.3 Flutter 侧桥接规则

- `MethodChannel/EventChannel` 只能出现在 bridge 文件
- bridge 文件只能位于 `core/` 或 feature `application/`
- 页面不得直接调用平台通道
- 原生层返回的数据必须是稳定协议对象，而不是零散字段

---

## 10. 数据层约束

### 10.1 数据库

- Drift 表定义只允许位于 data 层
- 页面不得直接访问 `AppDatabase`
- application 层如果需要数据，只依赖仓库或查询 service

### 10.2 Repository

- `domain` 中定义接口
- `data` 中实现接口
- 页面只能拿到接口或 provider 暴露出的稳定能力

### 10.3 共享实体

以下条件同时满足，才允许把模型放入全局 `domain/entities`：

- 至少两个 feature 使用
- 不依赖 UI
- 不依赖存储实现
- 语义稳定

否则优先放 feature 内部。

---

## 11. 安全与仓库卫生约束

强制规则：

<!-- - 禁止提交 keystore、签名配置、密钥、token、私有证书 -->
- 禁止提交 `ios/build`、`android/.gradle`、临时构建物
- `.gitignore` 已覆盖的不应再被 Git 跟踪
- 若已经泄漏，必须先旋转密钥，再清理仓库

---

## 12. 测试约束

### 12.1 必测项

新增或修改业务流程时，至少覆盖以下之一：

- application service test
- provider test
- widget test
- route smoke test

### 12.2 特殊要求

以下改动必须补测试：

- 路由编排
- 阅读器行为
- 平台桥接协议
- Drift 仓库实现
- 启动流程与生命周期协调器

### 12.3 禁止口径

- 只改大逻辑不补测试
- 只靠手点验证复杂回归

---

## 13. Code Review 检查清单

每个 PR 必须检查下面问题：

1. 页面里有没有直接 `new RepositoryImpl` 或 `AppDatabase.instance`
2. 页面里有没有直接调用 `MethodChannel`
3. 新增代码是不是默认先放进 feature 内，而不是先污染全局
4. `app/` 有没有新增具体业务编排
5. `router.dart` 有没有继续堆 feature 细节
6. 原生层有没有新增业务逻辑，而不是能力适配
7. 新 service 是否已 provider 化
8. 新模型放到全局 `domain` 是否真的跨 feature 共享
9. 是否补了对应层级的测试
10. 是否引入了新的静态单例或隐藏依赖

只要第 1、2、4、6、10 任一项回答为“有”，默认不通过。

---

## 14. 当前项目的明确整改方向

### 14.1 第一优先级

- 清理仓库中的签名文件与敏感配置
- 停止页面直接构造数据层实现

### 14.2 第二优先级

- 拆薄 `lib/features/reader/presentation/reader_page.dart`
- 把阅读器依赖图收口到 provider
- 让 `reader_page.dart` 只保留页面壳与交互绑定

### 14.3 第三优先级

- 拆分 `lib/app/app.dart` 中的启动与生命周期编排
- 将 `lib/app/router.dart` 重构为 feature route 聚合器

### 14.4 第四优先级

- 新增业务优先走 feature 内聚结构
- 全局 `domain/data` 只继续承载共享稳定能力

---

## 15. 落地执行规则

后续开发按以下顺序判断：

1. 这段代码是不是某个 feature 私有能力  
如果是，先放 feature 内。

2. 这段代码是不是页面渲染逻辑  
如果是，放 presentation。

3. 这段代码是不是业务编排  
如果是，放 application。

4. 这段代码是不是数据访问或平台实现  
如果是，放 data / core / runtime / bridge。

5. 这段代码是否跨多个 feature 共享且语义稳定  
如果是，再考虑提升到全局 `domain` 或 `core`。

---

## 16. 一票否决项

出现以下情况时，必须拦截：

- 新页面直接依赖 `AppDatabase`
- 新页面直接依赖 `RepositoryImpl`
- 新页面直接使用平台通道
- 新业务逻辑继续堆入 `App` 根 widget
- 新 feature 路由仍全部堆进一个总文件且带具体业务逻辑
- 新增原生代码承载 Flutter 本可统一处理的业务规则
- 再次提交签名密钥或构建产物

---

## 17. 文档联动

本文件是“开发约束”的唯一基线。

关联文档：

- `docs/engineering_guide.md`：工程总览
- `docs/cross_platform_boundary_refactor_plan.md`：跨端与原生边界
- `docs/archive/reader_page_decomposition_plan_2026-04-26.md`：阅读器历史拆解执行文档

如果这些文档与本文件冲突，以本文件为准，并同步修正文档。
