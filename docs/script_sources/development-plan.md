# 开发计划

## 1. 当前阶段目标

当前阶段不是追求“功能最全”，而是先把小说聚合底座跑通。

优先目标：
- 跑通一个完整的书源链路
- 落地宿主运行时骨架
- 验证 `init -> search -> detail -> chapters -> content` 的完整流程
- 为后续多源聚合和浏览器验证打基础

当前不优先做：
- 书源市场
- 远程源分发
- 复杂阅读器细节
- Python 解释器嵌入

说明：
- Python 不是当前排除项，只是当前不优先
- 如果后续 JS + 宿主能力已经足够，就不需要引入 Python
- 只有当后续请求/解析/调试能力明确不足时，再单独评估 Python 嵌入

## 2. 技术方向结论

当前技术方向：
- 书源格式：单文件 JS
- 主执行层：宿主 HTTP / HTML 能力
- 兜底执行层：浏览器 / WebView
- 宿主主导：Session、Challenge、Task 调度
- 书源主导：站点适配逻辑和步骤编排

结论：
- 不再以 `flutter_js` 作为未来核心方案
- 更偏向“宿主运行时 + WebView 浏览器能力 + 书源脚本”的架构
- Python 暂不纳入第一阶段里程碑

## 3. 里程碑

## M1: 运行时骨架

目标：
- 定义核心目录结构
- 建立运行时基础模块

交付：
- `RequestEngine`
- `SessionManager`
- `SourceExecutor`
- `CacheManager`
- `SearchAggregator`

验收标准：
- 能加载一个本地书源文件
- 能调用 `search(ctx, keyword)` 并返回标准 `Book[]`

## M2: 单源闭环

目标：
- 跑通一个 demo 书源完整链路

交付：
- `init(ctx, task)`
- `search(ctx, keyword)`
- `detail(ctx, book)`
- `chapters(ctx, book)`
- `content(ctx, book, chapter)`

验收标准：
- 一个 demo 源能够完整跑通从搜索到正文
- `Book / Chapter / Content` 标准对象在 UI 层可直接使用

## M3: 浏览器兜底能力

目标：
- 支持人机验证和真实页面执行

交付：
- `BrowserRuntime`
- `ChallengeManager`
- `ctx.browser.challenge(...)`
- `ctx.browser.eval(...)`

验收标准：
- 某一步遇到 challenge 时能弹出浏览器
- 用户操作结束后可恢复后续任务

## M4: 源调试页

目标：
- 方便开发和调试书源

交付：
- 单源调试页
- 请求日志
- 解析结果面板
- challenge 状态显示

验收标准：
- 能单独选择一个源并调试 `search/detail/chapters/content`

## M5: 多源聚合搜索

目标：
- 支持多个源并发搜索

交付：
- 多源并发调度
- 流式结果更新
- 去重和来源合并
- 源状态展示

验收标准：
- 多个源能够并发搜索
- UI 可以实时展示部分结果和每个源的状态

## 4. 模块拆解

### 4.1 RequestEngine

职责：
- 统一请求入口
- 管理超时、Header、UA、Cookie、Referer
- 统一返回标准响应对象

首版不做：
- 复杂缓存策略
- 高级代理能力

### 4.2 SessionManager

职责：
- 源级 Session 隔离
- 会话数据存取
- 浏览器和 HTTP 会话协同

首版重点：
- `ctx.session.get/set/clear`

### 4.3 SourceExecutor

职责：
- 加载书源
- 创建 `ctx`
- 执行源方法
- 统一错误捕获

首版重点：
- 支持 `init`
- 支持四个核心方法

### 4.4 CacheManager

职责：
- 管理 `search/detail/chapters/content` 的业务缓存
- 降低重复请求成本
- 支持按源、按书、按步骤清理

首版重点：
- 先做内存缓存
- 后续再扩展持久化缓存

### 4.5 SearchAggregator

职责：
- 并发调度多个源
- 聚合结果
- 流式更新 UI

首版重点：
- 先做简单并发
- 先做基础去重

### 4.6 BrowserRuntime

职责：
- 打开站点页面
- 执行浏览器上下文脚本
- 支持登录 / challenge 流程

首版重点：
- 保证 challenge 可手动完成并恢复执行

## 5. 第一阶段任务拆分

### Task A: 建 runtime 目录骨架

新增建议目录：
- `lib/runtime/http/`
- `lib/runtime/session/`
- `lib/runtime/cache/`
- `lib/runtime/sources/`
- `lib/runtime/browser/`
- `lib/runtime/aggregation/`

### Task B: 定义核心模型

先定义：
- `Book`
- `Chapter`
- `Content`
- `SourceTask`
- `SearchJob`

### Task C: 实现 SourceLoader

目标：
- 读取本地源文件
- 解析导出对象
- 做基础 schema 校验

### Task D: 实现 SourceExecutor

目标：
- 执行单个方法
- 注入 `ctx`
- 支持 `init`

### Task E: 实现 CacheManager

目标：
- 支持 `search/detail/chapters/content` 的基础缓存
- 支持 TTL
- 支持按 `source` 清理

### Task F: 实现 demo source

目标：
- 至少准备一个演示源
- 跑通全流程

### Task G: 做调试页

目标：
- 不先做完整产品 UI
- 先做开发者可用的调试面板

## 6. 风险与注意事项

### 6.1 风控与验证码

不要假设所有站点都能靠普通请求搞定。
架构必须支持中途切浏览器。

### 6.2 性能

不要一开始把所有复杂站点都放进浏览器层。
否则多源并发会很差。

### 6.3 规范收敛

当前已经确定：
- 去掉静态 `execution`
- 增加 `init`
- `meta` 以展示信息为主
- 内部 `sourceId/revision` 由宿主管理

后续继续扩展时，优先保持这几个核心约束不变。

## 7. 下一步建议

当前最合适的下一步不是继续讨论抽象概念，而是直接开始编码：

1. 创建 `runtime/` 目录结构
2. 定义核心模型
3. 实现 `RequestEngine`
4. 实现 `SessionManager`
5. 实现 `CacheManager`
6. 实现 `SourceExecutor`
7. 接一个 demo source

如果按这个顺序推进，后面接 UI 和浏览器兜底会顺很多。
