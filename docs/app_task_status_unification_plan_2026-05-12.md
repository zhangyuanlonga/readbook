# 导入与重索引任务态统一计划

更新时间：2026-05-12

## 目标

本地导入、外部导入、重建索引、图集导入、主题导入、字体导入、书源导入、缓存清理和日志导出，后续统一使用同一套任务状态语义，页面只关心“任务类型、进度、结果、展示方式”，不再每个页面维护一套局部状态和样式。

## 当前基线

- [x] 新增 `AppTaskStatusData`，统一 `kind / title / message / progress / detail / presentation / result` 字段。
- [x] 保留 `ImportExportTaskStatus` 旧 API，避免一次性改动现有导入导出页面。
- [x] 增加 `ImportExportTaskStatus.fromAppTaskStatus` 与 `toAppTaskStatusData`，允许旧导入导出任务逐步迁移到统一模型。
- [x] 增加模型转换测试，避免后续枚举映射漂移。

## 任务分类

| 任务类型 | 状态 |
| --- | --- |
| 本地图书导入 | 已有任务态，待迁移到统一模型 |
| 外部文件导入 | 已有任务态，待迁移到统一模型 |
| 本地图书重索引 | 有业务状态，待接入统一展示 |
| 图集导入 | 有局部状态，待接入统一展示 |
| 高级主题导入/导出 | 有导入导出任务态，待迁移到统一模型 |
| 字体导入 | 有导入任务态，待迁移到统一模型 |
| 书源导入 | 首版排除在线书源，后续恢复时必须直接接入统一模型 |
| 缓存清理/日志导出 | 有局部执行状态，待迁移到统一模型 |

## 后续阶段

### T1：本地书籍链路

- [ ] 将本地图书导入和外部文件导入的 `ImportExportTaskStatus` 创建点改为 `AppTaskStatusData`。
- [ ] 将 `LocalBookIndexService` 的索引中、成功、失败状态映射到 `AppTaskStatusKind.localBookReindex`。
- [ ] 详情页、书架页、阅读入口只消费统一任务状态，不直接拼接索引文案。

### T2：资源导入链路

- [ ] 图集导入、启动图导入、底栏图标导入使用 `AppTaskStatusKind.galleryImport`。
- [ ] 字体导入使用 `AppTaskStatusKind.fontImport`。
- [ ] 高级主题导入/导出使用 `AppTaskStatusKind.themeImport`。
- [ ] 统一失败、取消、成功后的 snackbar 和任务面板文案。

### T3：全局任务展示

- [ ] 形成 `AppTaskStatusSurface`，移动端使用底部任务面板，桌面/Web 使用居中或右侧任务面板。
- [ ] 支持单任务覆盖和多任务队列两种 presentation。
- [ ] 重索引、导入、缓存清理不得同时各自弹独立 UI。

## 开发约束

- 新增任务状态不得再新增 feature 私有枚举，除非它只在纯业务层使用且能映射到 `AppTaskStatusData`。
- 任务进度不确定时 `progress=null`，不要伪造百分比。
- 资源导入、重索引等耗时任务必须至少暴露 running / success / failure。
- 桌面/Web 不使用移动端专属底部弹层作为唯一展示方式。
