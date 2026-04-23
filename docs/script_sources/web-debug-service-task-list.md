# 书源网页调试服务阶段任务清单

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 使用说明

本文用于跟踪“网站调试台直连 App 本地服务”方案的实施进度。

配套文档：

- [书源网页调试台落地方案](./web-debug-service-implementation-plan.md)
- [书源网页调试服务开发文档](./web-debug-service-development-guide.md)

使用原则：

- 每完成一项任务，就直接勾选
- 如果实现偏离方案，先更新方案文档，再勾选任务
- 验收项不应提前勾选

## 2. 阶段总览

- [ ] 阶段 A：本地调试服务启动与连接打通
- [ ] 阶段 B：书源列表增删改查接口打通
- [ ] 阶段 C：单步调试接口打通
- [ ] 阶段 D：完整链路调试打通
- [ ] 阶段 E：网站调试台页面接入完成
- [ ] 阶段 F：联调、测试与文档收口

## 3. 阶段 A：本地调试服务启动与连接打通

目标：

- App 能启动和停止本地调试服务
- 网站页面能通过 `ping` 连上 App
- App 页面能展示当前可访问地址

任务：

- [x] 新增本地调试服务入口模块
- [x] 新增 HTTP 服务启动能力
- [x] 新增 HTTP 服务停止能力
- [x] 服务监听地址固定为 `0.0.0.0`
- [x] 服务端口支持默认值配置
- [x] App 页面能展示当前端口
- [x] App 页面能展示当前局域网 IP 地址
- [x] 新增 `GET /api/debug/ping`
- [x] `ping` 返回基础运行信息
- [x] 支持 `OPTIONS` 预检响应
- [x] 支持基础 `CORS` 响应头

验收：

- [ ] 同网段电脑浏览器能访问 `GET /api/debug/ping`
- [ ] App 内可手动开启服务
- [ ] App 内可手动关闭服务

## 4. 阶段 B：书源列表增删改查接口打通

目标：

- 网站可查看、创建、编辑、启停、删除书源

任务：

- [x] 新增 `GET /api/sources`
- [x] 新增 `GET /api/sources/:id`
- [x] 新增 `POST /api/sources`
- [x] 新增 `PUT /api/sources/:id`
- [x] 新增 `PATCH /api/sources/:id/enabled`
- [x] 新增 `DELETE /api/sources/:id`
- [x] 统一书源列表返回模型
- [x] 统一单书源详情返回模型
- [x] `POST /api/sources` 映射到 `saveScriptSource()`
- [x] `PUT /api/sources/:id` 映射到 `saveScriptSource(id: ...)`
- [x] 启停接口映射到 `setScriptSourceEnabled()`
- [x] 删除接口映射到 `deleteScriptSource()`
- [x] 保存失败时返回统一错误结构
- [x] 书源脚本编译失败时返回可读错误

验收：

- [ ] 网站可加载书源列表
- [ ] 网站可创建新书源
- [ ] 网站可编辑已有书源
- [ ] 网站可启用和停用书源
- [ ] 网站可删除书源

## 5. 阶段 C：单步调试接口打通

目标：

- 网站可单独执行 `search / detail / chapters / content`

任务：

- [x] 新增 `POST /api/debug/search`
- [x] 新增 `POST /api/debug/detail`
- [x] 新增 `POST /api/debug/chapters`
- [x] 新增 `POST /api/debug/content`
- [x] 统一单步调试请求解析
- [x] 统一单步调试响应包装
- [x] `search` 映射到 `SourceRuntimeFacade.search()`
- [x] `detail` 映射到 `SourceRuntimeFacade.detail()`
- [x] `chapters` 映射到 `SourceRuntimeFacade.chapters()`
- [x] `content` 映射到 `SourceRuntimeFacade.content()`
- [x] 返回中统一包含 `step`
- [x] 返回中统一包含 `durationMs`
- [x] 返回中统一包含 `result`
- [x] 返回中统一包含 `logs`
- [x] 返回中统一包含 `traces`
- [x] 缺少必填字段时返回 `validation_error`
- [x] 运行时错误返回统一错误结构

验收：

- [ ] 网站可执行 `search`
- [ ] 网站可执行 `detail`
- [ ] 网站可执行 `chapters`
- [ ] 网站可执行 `content`
- [ ] 单步失败时页面可正确展示错误

## 6. 阶段 D：完整链路调试打通

目标：

- 网站可一键跑完整链路，用于检测书源是否可用

任务：

- [ ] 新增 `source_debug_full_run_service.dart`
- [x] 新增 `POST /api/debug/full-run`
- [x] 固定执行顺序 `search -> detail -> chapters -> content`
- [x] `search` 为空时能提前结束
- [x] `chapters` 为空时能提前结束
- [x] 返回中包含总耗时 `durationMs`
- [x] 返回中包含阶段列表 `stages`
- [x] 返回中包含各阶段输出 `outputs`
- [x] 返回中包含总日志 `logs`
- [x] 返回中包含总轨迹 `traces`
- [x] 各阶段摘要信息可直接给前端展示

验收：

- [ ] 网站可执行一键完整调试
- [ ] 页面可展示每个阶段成功或失败
- [ ] 任一阶段失败时页面能保留前序阶段结果

## 7. 阶段 E：网站调试台页面接入完成

目标：

- 用户可在现有网站中直接使用调试台完成主要调试工作流

任务：

- [x] 新增调试台页面路由
- [x] 新增连接区
- [x] 新增书源列表区
- [x] 新增书源编辑器
- [x] 新增步骤切换区
- [x] 新增参数输入区
- [x] 新增结果区
- [x] 新增错误区
- [x] 新增日志区
- [x] 新增轨迹区
- [x] 新增正文预览区
- [x] 支持连接测试
- [x] 支持刷新书源列表
- [x] 支持运行当前步骤
- [x] 支持一键完整调试
- [x] 支持把 `search` 结果带入 `detail`
- [x] 支持把 `detail` 结果带入 `chapters`
- [x] 支持把 `chapters` 结果带入 `content`
- [x] 支持复制结果 JSON
- [x] 支持复制错误信息

验收：

- [ ] 用户可从网站进入调试台页面
- [ ] 用户可完成书源 CRUD
- [ ] 用户可完成单步调试
- [ ] 用户可完成完整链路调试

## 8. 阶段 F：联调、测试与文档收口

目标：

- 方案可稳定演示
- 核心接口有测试
- 文档与实际实现保持一致

任务：

- [ ] 为本地服务补充基础测试
- [ ] 为 `ping` 接口补充测试
- [ ] 为书源 CRUD 接口补充测试
- [ ] 为单步调试接口补充测试
- [ ] 为 `full-run` 接口补充测试
- [ ] 验证网站到 App 的跨域访问
- [ ] 验证局域网地址连接流程
- [ ] 验证编译失败场景
- [ ] 验证空搜索结果场景
- [ ] 验证目录为空场景
- [ ] 更新落地方案中的实际文件落点
- [ ] 更新开发文档中的接口实现映射
- [ ] 在索引文档中保留任务清单入口

验收：

- [ ] 主要链路具备最小测试覆盖
- [ ] 文档与实现一致
- [ ] 可以稳定演示从连接到完整调试的全流程

## 9. 建议执行顺序

建议严格按下面顺序推进：

1. 阶段 A
2. 阶段 B
3. 阶段 C
4. 阶段 D
5. 阶段 E
6. 阶段 F

不要先做网页复杂交互，再回头补 App 服务接口。

## 10. 里程碑判断

可以把下面几个时间点当作阶段性里程碑：

- [ ] M1：网页能连上 App
- [ ] M2：网页能管理书源
- [ ] M3：网页能单步调试
- [ ] M4：网页能一键完整调试
- [ ] M5：网页调试台可稳定演示
