# 脚本源运行时接入方案

更新时间：2026-03-25

这份文档用于说明：

- `flutterreadbook` 中脚本源 / 新规则运行时的定位
- 当前已经接入到什么程度
- 后续还需要接哪些业务链路
- 哪些边界应该保持稳定

这份文档是当前仓库里脚本源接入的主说明文档。

---

## 1. 当前定位

在 `flutterreadbook` 里，脚本源运行时的角色不是替换整个产品壳，而是：

- 作为新的书源执行内核
- 承载脚本源规范、`ctx.*` API 和后续新规则演进
- 与当前产品 UI、路由、书架、阅读页并存接线

当前仓库的产品层继续负责：

- 页面
- 路由
- 用户交互
- 阅读流程
- 本地持久化

脚本源运行时负责：

- 源码编译
- 源注册
- 搜索 / 详情 / 目录 / 正文执行
- `ctx.http / ctx.html / ctx.browser / ctx.session / ctx.cache / ctx.crypto`
- 标准结果对象

一句话：

- `flutterreadbook` 仍然是宿主 App
- `lib/runtime/` 是新规则内核

---

## 2. 当前状态

截至目前，脚本源接入已经完成以下部分：

### 2.1 运行时内核已嵌入

已迁入当前仓库：

- [lib/runtime](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime)
- [lib/src/js_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src/js_runtime.dart)
- [lib/src/js_runtime_native.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src/js_runtime_native.dart)
- [lib/src/js_runtime_stub.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/src/js_runtime_stub.dart)

### 2.2 宿主桥接已完成

当前仓库已经用现有实现承接了运行时抽象：

- HTTP 走当前网络层
- 浏览器能力通过 [appread_browser_runtime.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/host/appread_browser_runtime.dart) 对接现有 WebView / 交互验证能力

### 2.3 脚本源宿主持久化已完成

已新增独立宿主模型和存储，不复用旧规则 `sources` 表：

- [script_source.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/script_source.dart)
- [script_source_repository.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/repositories/script_source_repository.dart)
- [script_source_repository_impl.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/repositories/script_source_repository_impl.dart)
- [app_database.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart)

### 2.4 应用门面已完成

统一入口在：

- [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)

它负责：

- 保存脚本源码
- 编译注册到 runtime
- 重载已保存脚本源
- 启停时同步 runtime 注册状态
- 对上层提供 `search / detail / chapters / content`

### 2.5 三条业务链已接入 fallback

当前已完成最小接线：

- 搜索链：
  [search_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart)
- 详情链：
  [book_detail_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart)
- 正文链：
  [chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

当前策略是：

- 旧规则 source 仍优先走原有链路
- 当 `sourceId` 不属于旧规则仓库时，回退到脚本源 runtime

### 2.6 书源页入口已接入

`书源` 页已经分成双 Tab：

- 规则源
- 脚本源

位置在：

- [source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)

脚本源 Tab 目前支持：

- 新增
- 编辑
- 启用 / 停用
- 删除
- 手动重载

---

## 3. 当前还没完成的部分

虽然底层链路已经贯通，但还没到“完全替代旧规则”的阶段。

还没完成的主要内容：

### 3.1 页面级完整业务闭环

当前还需要继续验证真实用户流程：

1. 在脚本源 Tab 新建脚本源
2. 在搜索页搜索
3. 打开详情页
4. 进入阅读页

目前底层链已通，但这一整条用户路径还未作为正式产品流程完整打磨。

### 3.2 脚本源编辑体验

当前是最小可用版本，还缺：

- 更好的编译失败提示
- 更清晰的元信息预览
- 脚本导入 / 文件导入
- 调试与 trace 入口

### 3.3 旧规则与新规则的统一呈现

当前仅完成“同页双 Tab 管理”和底层 fallback。

还没做：

- 搜索结果中更明确地区分来源类型
- 详情页 / 阅读页中对脚本源的显式标识
- 面向用户的统一错误提示

### 3.4 旧规则兼容层

当前并没有把旧 Legado 规则转进新 runtime。

当前状态是：

- 旧规则继续走旧链
- 脚本源走新链

这是一种并行接入，不是统一执行内核。

---

## 4. 当前推荐架构

建议把当前仓库理解成 4 层：

### 4.1 产品壳层

位置主要在：

- `lib/features/**/presentation`
- `lib/app/`

职责：

- 页面
- 路由
- 交互

### 4.2 业务服务层

位置主要在：

- `lib/features/**/application`

职责：

- 阅读业务流程
- 页面状态协调
- 对接旧规则链和新 runtime 门面

### 4.3 脚本源门面层

位置：

- [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)
- [script_source_runtime_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/script_source_runtime_service.dart)

职责：

- 宿主持久化与 runtime 的衔接
- 注册、重载、执行转发

### 4.4 规则运行时内核层

位置：

- [lib/runtime](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime)

职责：

- 编译
- 执行
- 标准对象
- `ctx.*`
- 会话 / 缓存 / 浏览器 / 请求抽象

---

## 5. 现阶段原则

当前阶段建议坚持这几个原则：

### 5.1 先不改现有业务模型

当前仓库现有：

- `Book`
- `BookDetail`
- `Chapter`

脚本源返回结果先通过 adapter 适配，不先推动全量模型重构。

### 5.2 先跑通新源，再谈旧源统一

优先级应是：

1. 脚本源可保存
2. 脚本源可执行
3. 脚本源可被用户使用
4. 再评估旧规则兼容层

### 5.3 新功能优先落脚本源运行时

如果后续有新的规则能力，应优先加在：

- `lib/runtime/`
- `ctx.*`

而不是继续扩旧规则字段模型。

### 5.4 旧规则当前视为存量链路

旧规则目前的定位是：

- 兼容链路
- 存量能力
- 过渡方案

不应继续作为未来主线扩展中心。

---

## 6. 后续推荐顺序

建议按这个顺序继续推进：

### 第一阶段：完善脚本源产品闭环

- 搜索页真实联调
- 详情页真实联调
- 阅读页真实联调
- 修复脚本源流程中的页面级问题

### 第二阶段：完善脚本源管理能力

- 文件导入
- 编辑器优化
- 编译错误提示
- 重载与状态提示

### 第三阶段：补调试能力

- trace 查看
- runtime 快照
- 脚本执行错误定位

### 第四阶段：评估旧规则兼容方案

可选方向：

1. 长期双链并存
2. 旧规则转译到新 runtime
3. 旧规则冻结，仅保留维护

---

## 7. 一句话结论

在 `flutterreadbook` 中，脚本源运行时已经不是概念验证，而是：

- 已嵌入
- 已可持久化
- 已接入搜索 / 详情 / 正文主链
- 已有书源页入口

当前还差的是：

- 页面级完整用户闭环
- 更成熟的管理和调试体验

一句话总结：

- runtime 已经进来了
- 产品层还在继续接
- 旧规则还没统一进新内核
