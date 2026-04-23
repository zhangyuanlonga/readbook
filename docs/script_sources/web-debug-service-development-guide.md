# 书源网页调试服务开发文档

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 目的

本文面向开发者，说明“网站调试台 + App 本地调试服务”这一方案在代码层如何实现、联调、排查问题。

配套落地方案见：

- [书源网页调试台落地方案](./web-debug-service-implementation-plan.md)

## 2. 当前选择

当前方案不是：

- Flutter Web 页面
- App 内嵌前端静态资源
- 远程服务器中转

当前方案是：

- 现有网站新增一个调试台页面
- App 内部启动本地 HTTP 服务
- 网站页面填写 App 地址后，直接请求局域网中的 App

## 3. 前后端职责

### 3.1 网站前端负责

- 提供连接表单
- 展示书源列表
- 展示书源编辑器
- 发起调试请求
- 渲染结果、错误、日志、轨迹

### 3.2 App 负责

- 暴露 HTTP API
- 调用现有 `SourceRuntimeFacade`
- 执行书源
- 返回统一 JSON

网页不负责任何书源执行逻辑。

## 4. 推荐目录

建议 App 侧增加：

```text
lib/features/source/debug_service/
  source_debug_web_service.dart
  source_debug_router.dart
  source_debug_response.dart
  source_debug_request_parser.dart
  source_debug_full_run_service.dart
```

建议网站前端增加：

```text
src/pages/source-debug/
  index.vue
  api.ts
  types.ts
  useSourceDebug.ts
  components/
    debug-connection-card.vue
    source-list-panel.vue
    source-editor-drawer.vue
    debug-step-form.vue
    debug-result-panel.vue
```

## 5. 本地服务建议

### 5.1 监听方式

建议：

- 绑定 `0.0.0.0`
- 端口使用固定默认值，例如 `15421`
- App 页面显示当前实际访问地址

示例：

```text
http://192.168.1.23:15421
```

客户端不能访问 `0.0.0.0`，只能访问真实局域网 IP。

### 5.2 生命周期

建议服务生命周期明确可控：

- 用户手动开启
- 用户手动关闭
- 页面退出或 App 退后台时可选自动关闭

不建议默认常驻。

### 5.3 路由建议

可先用最轻量路由分发：

- 解析 `request.method`
- 解析 `request.uri.path`
- 转到对应 handler

第一版没必要先引入完整服务框架。

## 6. CORS 与预检

既然网站页面会跨域访问 App，本地服务必须支持：

- `OPTIONS`
- `Access-Control-Allow-Origin`
- `Access-Control-Allow-Methods`
- `Access-Control-Allow-Headers`

建议先白名单：

- 线上网站域名
- 本地开发域名，例如 `http://localhost:5173`

如果这层没配，网页会直接在浏览器报错，连不到 API。

## 7. 现有运行时复用建议

### 7.1 书源管理

可直接复用：

- `SourceRuntimeFacade.listScriptSources()`
- `SourceRuntimeFacade.getScriptSourceById()`
- `SourceRuntimeFacade.saveScriptSource()`
- `SourceRuntimeFacade.setScriptSourceEnabled()`
- `SourceRuntimeFacade.deleteScriptSource()`

文件：

- [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)

### 7.2 单步调试

单步接口优先直接调用：

- `search()`
- `detail()`
- `chapters()`
- `content()`

这样第一版最省实现成本。

### 7.3 完整链路调试

`full-run` 建议独立封装一个 service，不要把整段编排直接塞在 route handler 中。

建议执行逻辑：

1. `search`
2. 若结果为空，直接结束
3. 取第一本书跑 `detail`
4. 用增强后的书跑 `chapters`
5. 若章节为空，直接结束
6. 取第一章跑 `content`
7. 聚合返回阶段结果

## 8. 接口实现建议

### 8.1 统一响应包装

建议每个 handler 最终都走同一套响应封装：

- `success(data)`
- `failure(code, message, stage, detail)`

这样前端不需要为每个接口写不同错误解析。

### 8.2 参数解析

建议集中做 JSON 请求解析，避免每个 handler 重复：

- 校验 body 是否为 JSON
- 校验必填字段
- 统一返回 `validation_error`

### 8.3 模型转换

网页调试接口建议直接使用当前运行时结果模型的 JSON 兼容结构：

- `Book`
- `Chapter`
- `Content`

文件：

- [source_result_models.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_result_models.dart)

这样前后端字段语义与当前宿主运行时保持一致。

## 9. 前端页面建议

### 9.1 页面状态

建议至少维护这些状态：

- `appBaseUrl`
- `connectionStatus`
- `sources`
- `selectedSourceId`
- `selectedStep`
- `keyword`
- `selectedBook`
- `selectedChapter`
- `lastSearchResult`
- `lastDetailResult`
- `lastChaptersResult`
- `lastContentResult`
- `currentError`
- `currentLogs`
- `currentTraces`

### 9.2 建议组件拆分

`debug-connection-card`

- App 地址输入
- 连接测试按钮
- 连接状态显示

`source-list-panel`

- 书源列表
- 启用/停用
- 删除
- 打开编辑

`source-editor-drawer`

- 新建书源
- 编辑源码
- 保存

`debug-step-form`

- 步骤切换
- 输入参数
- 运行当前步骤
- 一键完整调试

`debug-result-panel`

- 结果
- 错误
- 日志
- 轨迹

## 9.3 页面交互建议

推荐工作流：

1. 输入 App 地址并连接
2. 加载书源列表
3. 选中书源
4. 执行 `search`
5. 在搜索结果中点击“带入详情”
6. 执行 `detail`
7. 再带入 `chapters`
8. 再带入 `content`

不要强迫用户每一步手填 JSON。

## 10. 开发联调建议

### 10.1 本地联调

开发阶段建议：

- 网站前端本地 dev server
- App 在真机或模拟器上启动调试服务
- 前端直接填写局域网地址进行调试

如果网站前端本地需要允许跨域，仍然要依赖 App 本地服务的 CORS 配置。

### 10.2 调试顺序

建议按这个顺序排查：

1. `ping` 通不通
2. `sources` 能否加载
3. `search` 能否返回
4. `detail`
5. `chapters`
6. `content`
7. `full-run`

不要一开始就直接排查完整链路，否则定位慢。

## 11. 错误排查指南

### 11.1 浏览器报跨域错误

优先检查：

- 是否处理了 `OPTIONS`
- `Access-Control-Allow-Origin` 是否返回正确
- 方法和 Header 是否被允许

### 11.2 网页连不上 App

优先检查：

- App 是否真的已启动服务
- 页面填写的是不是实际局域网地址
- 电脑和手机是否在同一网络
- 路由器是否开启 AP 隔离
- 系统防火墙是否阻止端口

### 11.3 `search` 正常但后续步骤失败

优先检查：

- 前端是否正确传回 `book`
- `detail` 后返回的 `tocUrl/detailUrl` 是否被更新
- 前端是否继续使用了旧 `book`

### 11.4 `full-run` 与单步结果不一致

优先检查：

- `full-run` 内部是否复用了上一阶段的结果
- 阶段间是否错误丢失了增强后的 `book`
- 第一章选择逻辑是否固定一致

## 12. 建议测试清单

最少覆盖：

- `ping` 成功
- `sources` 返回列表
- 新建书源成功
- 更新书源成功
- 启停成功
- 删除成功
- `search` 成功
- `detail` 成功
- `chapters` 成功
- `content` 成功
- `full-run` 在任一步失败时能正确返回阶段信息

如果补测试，建议新增：

- `test/features/source/debug_service/source_debug_web_service_test.dart`
- `test/features/source/debug_service/source_debug_full_run_service_test.dart`

## 13. 后续演进方向

第一版先不做，但后续可以扩展：

- 简单 token 鉴权
- 更完整的结构化 `logs / traces`
- 调试 session
- WebSocket 实时输出
- 前端历史记录
- 局域网设备发现

这些都不是第一版阻塞项。

## 14. 当前开发原则

请始终坚持：

- 网页只做调试台，不做书源执行宿主
- App 是唯一在线书源执行宿主
- 先把最小链路做通，再补体验
- 不要因为未来可能演进，就把第一版设计得过重
