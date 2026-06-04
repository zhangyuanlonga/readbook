# M2 手搓与不稳定实现候选看板

创建日期：2026-06-04

用途：承接 M2 首轮扫描结果。核心判断是：手搓换成熟，不稳定换成熟；不能替换的必须隔离、测试、中文注释和退出条件。

## 1. 已关闭候选

| 编号 | 类型 | 处理方式 | 状态 |
| --- | --- | --- | --- |
| M2-D001 | 工具稳定性 | green suite local tool 从 `dart run tool/...` 改为 `dart tool/...`，避免 native assets hook 干扰本地 guard | [x] |
| M2-D002 | Storage baseline | 新增 storage baseline 矩阵和同步 guard，所有白名单必须有业务理由、影响平台和退出条件 | [x] |
| M2-D003 | Dependency override | 新增 dependency override 矩阵和同步 guard，所有 override 必须有原因、平台影响和回主线 / 替换条件 | [x] |
| M2-D004 | 高级主题文件策略 | 高级主题页面的 ZIP、manifest、临时目录和批量导入导出协议已下沉到 `AdvancedThemeService`，页面只保留交互职责 | [x] |
| M2-D005 | 超大页面首轮拆分 | reader settings、bookshelf settings、advanced theme editor 各抽一个纯参数 widget，页面保留状态和业务意图分发 | [x] |
| M2-D006 | 平台散点首轮收敛 | 我的页头像选择来源改读 `AppPlatformCapabilities.shouldUseFilePickerForProfileAvatar`，页面不再直接拼桌面平台枚举 | [x] |

## 2. P1 候选

| 编号 | 对应任务 | 候选问题 | 当前实现 | 推荐方向 | 验证入口 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| M2-D007 | M2-07 | 本地解析与平台 IO 混杂，Web 和 Native 路径语义容易互相污染 | TXT / EPUB / PDF / MOBI parser 和 storage service | parser input adapter、任务队列、成熟库评估 | local parser tests、Web build | [ ] |
| M2-D008 | M2-08 | `BookshelfService` 仍包含 legacy migration、Drift、分类、事件广播等过多职责 | `bookshelf_service.dart` | 拆 legacy migration、taxonomy service、event bus | bookshelf service tests | [ ] |

## 3. P2 候选

| 编号 | 对应任务 | 候选问题 | 推荐方向 | 状态 |
| --- | --- | --- | --- | --- |
| M2-D009 | M2-09 | 存量手写模型仍有兼容和维护成本 | 先补兼容测试，再逐项迁移 `freezed` / `json_serializable` | [ ] |
| M2-D010 | M2-09 | SharedPreferences key 和默认值仍然分散 | 扩大 typed key / typed service，保留旧 key 兼容读取 | [ ] |
| M2-D011 | M2-06 | 本地 override / stub 后续仍需回主线或替换 | 依赖矩阵定期复查，优先处理平台构建风险 | [ ] |

## 4. 下一步建议

- [x] M2-04-01 到 M2-04-10 已完成，高级主题页面里的文件策略已下沉。
- [x] M2-05-01 到 M2-05-07 已完成，完成三处低风险 UI 职责拆分。
- [x] M2-06-01 到 M2-06-05 已完成，头像选择平台语义已收敛到 capability。
- [ ] 然后执行 M2-07-01 到 M2-07-06，隔离本地解析与平台 IO。
- [ ] 再执行 M2-08-01 到 M2-08-06，拆 `BookshelfService`。

## 5. 已关闭记录

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D004 |
| 日期 | 2026-06-04 |
| 处理方式 | 隔离 / 补测试 / 补注释：批量包协议、临时目录和 ZIP 处理迁入 `AdvancedThemeService`，页面层删除直接文件策略。 |
| 行为等价 | 单包导入导出、批量包 manifest、缺文件失败计数和旧格式导入保持原语义。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为职责边界调整；跨端文件名和临时目录策略集中到 application 层。 |
| 验证 | `advanced_theme_service_test.dart`、storage guard、baseline guard、docs guard、green suite dry-run。 |
| 后续 | 关闭；若继续治理高级主题，可进入 M2-05 超大页面拆分或后续 temp workspace service。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D005 |
| 日期 | 2026-06-04 |
| 处理方式 | 隔离 / 补注释：抽出 `ReaderTypographySliderRow`、`BookshelfSettingsSwitchTile`、`AdvancedThemeLaunchGallerySelectionCard`。 |
| 行为等价 | 页面仍负责状态、保存、预览和回调；新 widget 只吃参数并渲染 UI。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 为 UI 层职责拆分，无平台插件行为变化。 |
| 验证 | 目标 analyze、reader settings / bookshelf / advanced theme editor 相关 smoke。 |
| 后续 | 首轮关闭；复杂页面仍需后续按 Phase E 继续拆。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D006 |
| 日期 | 2026-06-04 |
| 处理方式 | 收敛 / 补注释：我的页头像选择来源改读 `AppPlatformCapabilities.shouldUseFilePickerForProfileAvatar`。 |
| 行为等价 | Web / 桌面仍直接文件选择，Android / iOS 仍展示动作面板。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 行为保持，平台语义集中到 app capability。 |
| 验证 | presentation 平台散点扫描、目标 analyze、capability 单测、mine/auth 页面相关 smoke、architecture guard。 |
| 后续 | 首轮关闭；剩余 presentation 平台散点进入后续 M3/M4 或专项治理。 |

## 6. 收尾记录模板

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-Dxxx |
| 日期 | YYYY-MM-DD |
| 处理方式 | 替换 / 隔离 / 补测试 / 补注释 / 暂缓 |
| 行为等价 | 旧行为和新行为是否一致 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux |
| 验证 | 命令、结果、未验证原因 |
| 后续 | 是否关闭、降级优先级或进入下一阶段 |
