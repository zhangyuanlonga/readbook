# 书源网页调试台落地方案

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 结论

本方案采用：

- 现有网站前端新增“书源调试台”页面
- App 内启动本地 Web 服务，监听 `0.0.0.0:<port>`
- 用户在网页中填写 App 地址
- 网页直接调用 App 的本地调试 API

本轮明确不做：

- Flutter Web 版书源页
- App 内托管独立前端构建产物
- 复杂鉴权与账号体系
- 跨公网远程调试
- 多会话并行调试

这是一个“局域网内、简单直接、先把链路跑通”的方案。

## 2. 目标

围绕“书源列表高频调试”和“用户检测书源是否可用”两个场景，第一版必须覆盖：

- 书源列表增删改查
- 单源调试 `search / detail / chapters / content`
- 一键完整链路调试 `full-run`
- 网页可直接看到：
  - 结构化结果
  - 错误信息
  - 日志
  - 请求轨迹

## 3. 为什么选这条路

当前项目的书源执行能力已经集中在宿主运行时中，不适合把执行链搬到网页里重写。

现有可复用能力：

- 统一执行入口：
  [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)
- 调试型隔离容器：
  [source_runtime_diagnostic_execution_container.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_diagnostic_execution_container.dart)
- 书源页现有调试入口：
  [source_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/source_page.dart)

所以本轮不新造第二套书源执行器，而是在 App 内现有运行时外再包一层本地 HTTP API。

## 4. 目标架构

```mermaid
flowchart LR
    A["线上网站\n书源调试台页面"] --> B["局域网地址输入\nhttp://192.168.x.x:15421"]
    B --> C["App 本地 Web 服务\n0.0.0.0:15421"]
    C --> D["Debug API Router"]
    D --> E["SourceRuntimeFacade"]
    E --> F["ScriptSourceRuntimeService"]
    F --> G["SourceRuntimeDiagnosticExecutionContainer / SourceExecutor"]
    G --> H["HTTP / HTML / Browser / Cookie / Cache / Session"]
```

说明：

- 网页只做控制台和结果展示
- App 继续作为唯一执行宿主
- 网页不直接运行书源脚本

## 5. 交互流程

### 5.1 启动流程

1. 用户在 App 内打开“网页调试”
2. App 启动本地服务并显示：
   - 当前端口
   - 当前局域网地址
3. 用户在电脑浏览器中打开网站调试台
4. 在网页中填写 App 地址
5. 网页调用 `GET /api/debug/ping`
6. 连接成功后加载书源列表

### 5.2 单步调试流程

1. 选择书源
2. 选择步骤：`search / detail / chapters / content`
3. 输入当前步骤参数
4. 调用对应 API
5. 展示结果、错误、日志、轨迹
6. 用户可将结果带入下一步

### 5.3 完整检测流程

1. 选择书源
2. 输入关键词
3. 点击“一键完整调试”
4. App 内部按 `search -> detail -> chapters -> content` 顺序执行
5. 网页展示各阶段结果与总状态

## 6. 接口范围

本轮接口分两组。

### 6.1 书源管理接口

- `GET /api/debug/ping`
- `GET /api/sources`
- `GET /api/sources/:id`
- `POST /api/sources`
- `PUT /api/sources/:id`
- `PATCH /api/sources/:id/enabled`
- `DELETE /api/sources/:id`

### 6.2 调试接口

- `POST /api/debug/search`
- `POST /api/debug/detail`
- `POST /api/debug/chapters`
- `POST /api/debug/content`
- `POST /api/debug/full-run`

### 6.3 跨域支持

虽然本轮不做鉴权，但服务端仍必须支持：

- `OPTIONS` 预检
- `CORS`

建议白名单先只放调试网站域名与开发环境域名。

## 7. 返回结构

建议所有接口统一返回：

```json
{
  "ok": true,
  "data": {},
  "error": null,
  "meta": {
    "requestId": "req_xxx",
    "timestamp": "2026-04-23T12:00:00.000Z"
  }
}
```

失败时：

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "runtime_error",
    "message": "搜索无结果",
    "stage": "search",
    "detail": "可选"
  },
  "meta": {
    "requestId": "req_xxx",
    "timestamp": "2026-04-23T12:00:00.000Z"
  }
}
```

调试接口的 `data` 中建议统一包含：

- `result`
- `durationMs`
- `logs`
- `traces`

## 8. App 端实现建议

### 8.1 模块落点

建议新增一组轻量模块，不污染现有页面逻辑：

- `lib/features/source/debug_service/source_debug_web_service.dart`
- `lib/features/source/debug_service/source_debug_router.dart`
- `lib/features/source/debug_service/source_debug_response.dart`
- `lib/features/source/debug_service/source_debug_request_parser.dart`
- `lib/features/source/debug_service/source_debug_full_run_service.dart`

页面侧如需控制开关，可新增：

- `lib/features/source/presentation/source_debug_service_panel.dart`

### 8.2 运行时映射

接口与现有宿主能力的映射建议如下：

- `GET /api/sources`
  - `SourceRuntimeFacade.listScriptSources()`
- `GET /api/sources/:id`
  - `SourceRuntimeFacade.getScriptSourceById()`
- `POST /api/sources`
  - `SourceRuntimeFacade.saveScriptSource()`
- `PUT /api/sources/:id`
  - `SourceRuntimeFacade.saveScriptSource(id: ...)`
- `PATCH /api/sources/:id/enabled`
  - `SourceRuntimeFacade.setScriptSourceEnabled()`
- `DELETE /api/sources/:id`
  - `SourceRuntimeFacade.deleteScriptSource()`
- `POST /api/debug/search`
  - `SourceRuntimeFacade.search()`
- `POST /api/debug/detail`
  - `SourceRuntimeFacade.detail()`
- `POST /api/debug/chapters`
  - `SourceRuntimeFacade.chapters()`
- `POST /api/debug/content`
  - `SourceRuntimeFacade.content()`

`full-run` 建议单独封装，不直接塞到页面层。

### 8.3 `full-run` 的执行语义

建议顺序固定：

1. `search`
2. 取第一本书进入 `detail`
3. 取增强后的书进入 `chapters`
4. 取第一章进入 `content`

返回时同时输出：

- 每一步是否成功
- 每一步耗时
- 每一步摘要
- 每一步原始结果
- 全链路日志与轨迹

### 8.4 日志与轨迹

当前项目已有调试页输出“日志 / debug traces”的方向，但网页调试 API 不能继续依赖页面拼接命令字符串。

本轮建议：

- API 返回结果时允许先返回空 `logs / traces`
- 只要接口结构稳定，前端就能先接起来
- 第二阶段再补齐结构化采集

不要为了第一版把当前本地调试页整页搬成 HTTP 接口。

## 9. 前端页面建议

网站中的“书源调试台”第一页建议分成 5 个区块：

1. 连接区
   - App 地址
   - 连接测试
   - 连接状态
2. 书源区
   - 书源列表
   - 启用/停用
   - 新建/编辑/删除
3. 调试区
   - 步骤切换
   - 参数输入
   - 运行当前步骤
   - 一键完整调试
4. 结果区
   - 结果
   - 错误
   - 日志
   - 请求轨迹
5. 预览区
   - 书籍卡片
   - 章节列表
   - 正文预览

## 10. 安全边界

本轮不做鉴权，但仍建议收住这些边界：

- 服务默认关闭
- 用户手动开启后才监听端口
- 服务只开放调试相关接口
- App 退到后台或用户手动关闭时允许停止服务
- 页面显式提示“当前正开放局域网调试”

本方案接受以下事实：

- 局域网内知道地址的人理论上可以访问这些接口
- 这是第一版为了提升调试效率做的取舍

## 11. 分阶段落地

### 阶段 A：先把服务跑起来

目标：

- App 能启动本地服务
- 网页能 `ping`
- 能获取书源列表

交付：

- `GET /api/debug/ping`
- `GET /api/sources`
- App 内的启动/停止入口

### 阶段 B：补齐书源管理

目标：

- 网页可完成新增、编辑、启停、删除

交付：

- `GET /api/sources/:id`
- `POST /api/sources`
- `PUT /api/sources/:id`
- `PATCH /api/sources/:id/enabled`
- `DELETE /api/sources/:id`

### 阶段 C：补齐单步调试

目标：

- 网页能跑 `search / detail / chapters / content`

交付：

- 4 个单步调试接口
- 前端单步调试 UI

### 阶段 D：补齐完整链路

目标：

- 网页能一键检测书源是否可用

交付：

- `POST /api/debug/full-run`
- 阶段化结果展示

## 12. 验收标准

满足以下条件即可认为第一版完成：

- 用户能在网站中输入 App 地址并连接成功
- 用户能看到局域网内 App 当前书源列表
- 用户能新增、编辑、启停、删除书源
- 用户能单步执行 `search / detail / chapters / content`
- 用户能执行“一键完整调试”
- 页面能展示结果和错误

## 13. 当前方案的明确取舍

本方案刻意选择：

- 简单直接
- 同网段直连
- 网站已有前端继续加页面
- App 只做本地调试 API

本轮不追求：

- 复杂安全模型
- 通用远程调试平台
- 完整调试工作台引擎抽象

先把“用户真的能在网页上调试书源”做成，再决定是否继续演进到更复杂的会话模型或中转架构。
