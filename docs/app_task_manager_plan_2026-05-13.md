# A5 任务管理层

更新时间：2026-05-13

## 0. 目标

`AppTaskStatusData` 继续作为 UI 状态模型；真正的导入、重索引、资源扫描、同步等耗时任务进入 `AppTaskManager` 管理，支持任务 id、通道、优先级、取消、重试和恢复标识。

## 1. 当前代码入口

- `lib/app/tasks/app_task_manager.dart`
- `lib/app/widgets/app_task_status.dart`
- `lib/features/bookshelf/presentation/local_library_page.dart`

## 2. 已完成

- [x] 新增 `AppTaskManager`。
- [x] 新增任务优先级：`immediate`、`userInitiated`、`background`。
- [x] 新增任务通道：reader、localBookImport、localBookIndex、resourceImport、resourceScan、sync、maintenance、other。
- [x] 支持 `startTask`、`updateTask`、`cancelTask`、`removeTask`、`clearFinished`。
- [x] 支持 `recoveryKey`，为后续中断恢复保留字段。
- [x] 新增 `appTaskManagerProvider`。
- [x] 本地图书导入接入 `AppTaskManager`，任务 kind 使用 `localBookImport`。
- [x] 本地书库重索引接入 `AppTaskManager`，任务 kind 使用 `localBookReindex`。

## 3. 当前边界

- 当前任务管理层先管理状态，不负责实际调度 isolate、队列执行或持久化。
- `AppTaskPriority.immediate` 用于阅读打开、正文加载等用户即时路径；导入/扫描不得阻塞它。
- `AppTaskPriority.background` 用于资源扫描、缓存维护。
- 真正的持久化恢复需要在后续阶段接入存储。

## 4. 后续迁移

- [ ] 外部导入接入 `AppTaskManager`。
- [ ] 图集、字体、主题导入接入 `resourceImport`。
- [ ] 缓存扫描、图库 metadata 扫描接入 `resourceScan`。
- [ ] 设计任务队列 UI：移动端任务面板，桌面/Web 右侧或居中任务面板。
- [ ] 明确哪些任务可恢复，哪些任务只展示“上次中断”。
