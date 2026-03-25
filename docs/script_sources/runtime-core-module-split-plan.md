# 脚本源运行时代码拆分与接入清单

更新时间：2026-03-25

这份文档用于说明：

- 当前仓库里哪些脚本源相关模块已经落地
- 哪些模块属于运行时核心
- 哪些模块属于宿主适配层
- 哪些模块还只是临时接线，不适合继续堆逻辑

这份文档是 `flutterreadbook` 当前仓库里的“代码级接入清单”。

---

## 1. 当前目录判断

脚本源相关代码现在可以分成 4 类。

### 1.1 运行时核心

已经落在：

- [lib/runtime](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime)
- [lib/src/js_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src/js_runtime.dart)
- [lib/src/js_runtime_native.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src/js_runtime_native.dart)
- [lib/src/js_runtime_stub.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src/js_runtime_stub.dart)

这一层应继续保持“可独立演进”的内核形态。

### 1.2 宿主适配层

当前主要在：

- [script_source_runtime_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/script_source_runtime_service.dart)
- [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)
- [appread_browser_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/host/appread_browser_runtime.dart)

这一层负责把当前 App 的数据库、WebView、页面服务接到 runtime。

### 1.3 宿主持久化层

当前主要在：

- [script_source.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/script_source.dart)
- [script_source_repository.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/repositories/script_source_repository.dart)
- [script_source_repository_impl.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/repositories/script_source_repository_impl.dart)
- [app_database.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart)

这一层负责保存源码和宿主元信息，不直接负责执行。

### 1.4 页面接线层

当前主要在：

- [source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)
- [search_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart)
- [book_detail_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart)
- [chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

这层已经有最小接线，但还不适合继续直接堆大量 runtime 逻辑。

---

## 2. 已经落地的核心模块

下面这些模块已经真正进入当前仓库，且已经被接入或验证。

## 2.1 聚合与执行调度

目录：

- [aggregation](../../lib/runtime/aggregation)

文件：

- [aggregation_models.dart](../../lib/runtime/aggregation/aggregation_models.dart)
- [dedupe_service.dart](../../lib/runtime/aggregation/dedupe_service.dart)
- [search_aggregator.dart](../../lib/runtime/aggregation/search_aggregator.dart)

当前状态：

- 已迁入
- 还未作为宿主主入口大规模使用

判断：

- 属于可继续保留的内核模块

## 2.2 浏览器运行时抽象

目录：

- [browser](../../lib/runtime/browser)

文件：

- [browser_runtime.dart](../../lib/runtime/browser/browser_runtime.dart)
- [browser_session.dart](../../lib/runtime/browser/browser_session.dart)
- [challenge_manager.dart](../../lib/runtime/browser/challenge_manager.dart)
- [interactive_browser_runtime.dart](../../lib/runtime/browser/interactive_browser_runtime.dart)

当前状态：

- runtime 抽象已迁入
- 实际宿主承接使用的是 [appread_browser_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/host/appread_browser_runtime.dart)

判断：

- 抽象层应保留
- `InteractiveBrowserRuntime` 目前仍偏开发工具，不是产品层直接依赖

## 2.3 缓存与会话

目录：

- [cache](../../lib/runtime/cache)
- [session](../../lib/runtime/session)

文件：

- [cache_key_builder.dart](../../lib/runtime/cache/cache_key_builder.dart)
- [cache_manager.dart](../../lib/runtime/cache/cache_manager.dart)
- [cache_policy.dart](../../lib/runtime/cache/cache_policy.dart)
- [session_manager.dart](../../lib/runtime/session/session_manager.dart)
- [source_session.dart](../../lib/runtime/session/source_session.dart)

当前状态：

- 已迁入
- 已在脚本源执行链中使用

判断：

- 属于当前新链主干

## 2.4 编码、加解密与 HTML 解析

目录：

- [crypto](../../lib/runtime/crypto)
- [html](../../lib/runtime/html)

文件：

- [source_crypto.dart](../../lib/runtime/crypto/source_crypto.dart)
- [html_helpers.dart](../../lib/runtime/html/html_helpers.dart)
- [html_runtime.dart](../../lib/runtime/html/html_runtime.dart)

当前状态：

- 已迁入
- 已作为 runtime 的正式能力层

判断：

- 属于长期保留模块

## 2.5 HTTP 层

目录：

- [http](../../lib/runtime/http)

文件：

- [challenge_detector.dart](../../lib/runtime/http/challenge_detector.dart)
- [http_models.dart](../../lib/runtime/http/http_models.dart)
- [request_engine.dart](../../lib/runtime/http/request_engine.dart)

当前状态：

- 已迁入
- 已作为 runtime 的请求抽象使用

判断：

- 属于长期保留模块

## 2.6 书源核心

目录：

- [sources](../../lib/runtime/sources)

关键文件：

- [source_contract.dart](../../lib/runtime/sources/source_contract.dart)
- [source_executor.dart](../../lib/runtime/sources/source_executor.dart)
- [source_loader.dart](../../lib/runtime/sources/source_loader.dart)
- [source_manifest.dart](../../lib/runtime/sources/source_manifest.dart)
- [source_registry.dart](../../lib/runtime/sources/source_registry.dart)
- [source_result_models.dart](../../lib/runtime/sources/source_result_models.dart)
- [source_script_compiler.dart](../../lib/runtime/sources/source_script_compiler.dart)
- [source_script_template.dart](../../lib/runtime/sources/source_script_template.dart)

当前状态：

- 已迁入
- 已通过 facade 和 service 接入到当前业务链

判断：

- 这是当前脚本源新链的核心主干

---

## 3. 已落地的宿主接线模块

这些模块不属于 runtime 核心，但在 `flutterreadbook` 当前阶段非常关键。

## 3.1 宿主浏览器桥接

文件：

- [appread_browser_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/host/appread_browser_runtime.dart)

作用：

- 用当前仓库已有的 WebView 承接 runtime `BrowserRuntime`
- 复用现有交互验证能力

判断：

- 当前必须保留
- 后续如果浏览器能力继续升级，应优先改这里，而不是绕过 runtime 抽象

## 3.2 运行时 service

文件：

- [script_source_runtime_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/script_source_runtime_service.dart)

作用：

- runtime 容器组装
- 编译注册
- 执行转发

判断：

- 目前是宿主和 runtime 之间的最小桥梁
- 后续可以继续保留，但不应演化成新的“大而全业务 service”

## 3.3 应用门面

文件：

- [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)

作用：

- 管理脚本源宿主持久化
- 重载 / 启停 / 删除
- 为搜索 / 详情 / 正文提供统一调用入口

判断：

- 这是当前最重要的宿主接入面

---

## 4. 已落地的业务接线点

## 4.1 搜索链

文件：

- [search_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart)

当前做法：

- 旧规则 source 继续走旧链
- 已注册脚本源作为额外搜索目标加入

判断：

- 已完成最小接线
- 还需要继续做页面级完整联调

## 4.2 详情链

文件：

- [book_detail_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart)

当前做法：

- 先查旧规则 source
- 查不到时，回退到脚本源 runtime `detail + chapters`

判断：

- 已完成最小接线
- 还需要继续做真实用户路径验证

## 4.3 正文链

文件：

- [chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

当前做法：

- 先查旧规则 source
- 查不到时，回退到脚本源 runtime `content`

判断：

- 已完成最小接线
- 图片正文和缓存行为还需要进一步产品化验证

## 4.4 书源页入口

文件：

- [source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)

当前做法：

- 同页双 Tab
- `规则源` / `脚本源`

判断：

- 已完成最小管理入口
- 编辑体验还未优化

---

## 5. 当前不建议继续扩的模块

下面这些模块当前不建议继续作为核心方向扩写。

## 5.1 `source_workbench_controller.dart`

文件：

- [source_workbench_controller.dart](../../lib/runtime/source_workbench_controller.dart)

原因：

- 它仍然混合了 runtime 容器职责和调试壳职责
- 在当前仓库里不是产品层正式入口

结论：

- 保留作开发工具参考
- 不建议把业务继续往这里集中

## 5.2 `persisted_source_loader.dart` 与 `source_file_store.dart`

文件：

- [persisted_source_loader.dart](../../lib/runtime/sources/persisted_source_loader.dart)
- [source_file_store.dart](../../lib/runtime/sources/source_file_store.dart)

原因：

- 当前仓库已经落了独立宿主持久化：
  `script_sources`
- 这两个文件更适合作为 runtime 内部的文件存储实现参考

结论：

- 可以保留
- 不应再作为当前仓库脚本源主存储入口

## 5.3 内置演示源与模板以外的演示壳

当前仓库中不存在以下旧演示壳文件：

- `app_shell.dart`
- `js_playground_app.dart`
- `playground_state.dart`

结论：

- 这类演示壳内容不再是当前仓库接入重点

---

## 6. 当前推荐结构

建议在 `flutterreadbook` 中继续保持下面这层结构：

## 6.1 `runtime_core`

对应：

- [lib/runtime](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime)
- [lib/src/js_runtime*.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src)

职责：

- 规则内核

## 6.2 `runtime_host_adapters`

对应：

- [appread_browser_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/host/appread_browser_runtime.dart)
- [script_source_runtime_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/script_source_runtime_service.dart)
- [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)

职责：

- 宿主接线

## 6.3 `runtime_storage`

对应：

- `script_sources` 表
- script source repository

职责：

- 保存脚本源码和宿主元数据

## 6.4 `product_entry_points`

对应：

- [source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)
- [search_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart)
- [book_detail_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart)
- [chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

职责：

- 面向产品链路的最小接入

---

## 7. 后续推荐顺序

### 阶段 1：完成页面级完整联调

- 脚本源创建
- 搜索
- 详情
- 阅读页

### 阶段 2：完善脚本源管理

- 文件导入
- 错误提示
- 编辑体验

### 阶段 3：补 trace / 调试入口

- 编译错误定位
- runtime 快照
- 执行 trace

### 阶段 4：评估旧规则统一方案

- 双链并存
- 或兼容层转入 runtime

---

## 8. 一句话总结

当前仓库已经不再是“只有 runtime 代码迁进来”的阶段，而是：

- runtime core 已落地
- 宿主持久化已落地
- 搜索 / 详情 / 正文已接线
- 书源页已有脚本源入口

接下来真正要做的，不是继续搬代码，而是：

- 把现有接线打磨成稳定的产品流程
