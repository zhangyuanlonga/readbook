# M2 手搓与不稳定实现候选看板

创建日期：2026-06-04

用途：承接 M2 首轮扫描结果。核心判断是：手搓换成熟，不稳定换成熟；不能替换的必须隔离、测试、中文注释和退出条件。

## 1. 已关闭候选

| 编号 | 类型 | 处理方式 | 状态 |
| --- | --- | --- | --- |
| M2-D001 | 工具稳定性 | green suite local tool 从 `dart run tool/...` 改为 `dart tool/...`，避免 native assets hook 干扰本地 guard | [x] |
| M2-D002 | Storage baseline | 新增 storage baseline 矩阵和同步 guard，所有白名单必须有业务理由、影响平台和退出条件 | [x] |
| M2-D003 | Dependency override | 新增 dependency override 矩阵和同步 guard，所有 override 必须有原因、平台影响和回主线 / 替换条件 | [x] |

## 2. P1 候选

| 编号 | 对应任务 | 候选问题 | 当前实现 | 推荐方向 | 验证入口 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| M2-D004 | M2-04 | 高级主题列表页面直接处理临时目录、ZIP、manifest 和批量导入导出 | `advanced_theme_list_page.dart` | 文件策略下沉到 application service，页面只保留交互和进度 | `advanced_theme_service_test.dart`、storage guard、页面 smoke | [ ] |
| M2-D005 | M2-05 | 阅读器、书架、高级主题等超大页面仍有大量职责 | 多个 3000-6000 行页面 | 等价抽 widget / controller / coordinator，业务态继续进 provider | reader / bookshelf / theme smoke tests | [ ] |
| M2-D006 | M2-06 | presentation 层平台判断散点仍然偏多 | 页面内 `kIsWeb` / `Platform` / `defaultTargetPlatform` | 收敛到 capability / adapter / conditional import | architecture guard、Web build | [ ] |
| M2-D007 | M2-07 | 本地解析与平台 IO 混杂，Web 和 Native 路径语义容易互相污染 | TXT / EPUB / PDF / MOBI parser 和 storage service | parser input adapter、任务队列、成熟库评估 | local parser tests、Web build | [ ] |
| M2-D008 | M2-08 | `BookshelfService` 仍包含 legacy migration、Drift、分类、事件广播等过多职责 | `bookshelf_service.dart` | 拆 legacy migration、taxonomy service、event bus | bookshelf service tests | [ ] |

## 3. P2 候选

| 编号 | 对应任务 | 候选问题 | 推荐方向 | 状态 |
| --- | --- | --- | --- | --- |
| M2-D009 | M2-09 | 存量手写模型仍有兼容和维护成本 | 先补兼容测试，再逐项迁移 `freezed` / `json_serializable` | [ ] |
| M2-D010 | M2-09 | SharedPreferences key 和默认值仍然分散 | 扩大 typed key / typed service，保留旧 key 兼容读取 | [ ] |
| M2-D011 | M2-06 | 本地 override / stub 后续仍需回主线或替换 | 依赖矩阵定期复查，优先处理平台构建风险 | [ ] |

## 4. 下一步建议

- [ ] 优先执行 M2-04-01 到 M2-04-10，先把高级主题页面里的文件策略下沉。
- [ ] 然后执行 M2-06-01 到 M2-06-05，减少 presentation 层平台散点。
- [ ] 再执行 M2-08-01 到 M2-08-06，拆 `BookshelfService`。

## 5. 收尾记录模板

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-Dxxx |
| 日期 | YYYY-MM-DD |
| 处理方式 | 替换 / 隔离 / 补测试 / 补注释 / 暂缓 |
| 行为等价 | 旧行为和新行为是否一致 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux |
| 验证 | 命令、结果、未验证原因 |
| 后续 | 是否关闭、降级优先级或进入下一阶段 |
