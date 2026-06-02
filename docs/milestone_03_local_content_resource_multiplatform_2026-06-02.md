# 里程碑 03：本地内容与资源能力多端化

创建日期：2026-06-02

状态：待执行

适用平台：Desktop 优先，Web 明确支持/不支持范围，Android / iOS 保持稳定。

核心目标：补齐多端最难的平台能力，让 Web / Desktop 不仅能在线阅读，也能合理处理本地内容、资源、缓存和诊断能力。

## 1. 阶段定位

第三里程碑处理高风险能力：

- Desktop 本地图书导入。
- Web 本地图书上传 / 临时阅读 / 降级策略。
- 本地解析后台化。
- 缓存预算治理。
- 主题、字体、封面、启动图等资源能力。
- 诊断导出、日志、缓存清理等平台 adapter。
- 本地 override 依赖治理。

## 2. 不做项

- [x] 不承诺 Web 拥有原生文件系统同等能力。
- [x] 不一次性支持全部格式全平台完美。
- [x] 不删除用户资产。
- [x] 不把缓存清理放进启动阻塞链路。
- [x] 不绕过现有存储治理规范。
- [x] 不为了本地能力重写在线阅读链路。

## 3. Desktop 本地图书导入

优先级：

1. TXT。
2. EPUB。
3. PDF。
4. MOBI。
5. HTML / Markdown / 其他格式。

任务：

- [ ] Desktop 文件选择通过 `file_selector` 或统一 adapter。
- [ ] 导入入口按 capability 显示。
- [ ] 文件复制进入托管文件目录。
- [ ] 索引过程后台化，不阻塞 UI。
- [ ] 导入任务进入任务队列或明确进度反馈。
- [ ] 导入失败有错误说明和重试方式。
- [ ] 至少一种格式完成：导入 -> 索引 -> 详情 -> 阅读 -> 进度保存。

## 4. Web 本地内容策略

Web 不假装拥有原生路径。

可选策略：

- 上传后临时阅读。
- 上传后写入浏览器可持久存储，需单独评估容量和可靠性。
- 不支持长期托管文件时，展示禁用说明。
- Web 本地图书不与 Native 托管路径混用。

任务：

- [ ] 明确 Web 本地图书支持范围。
- [ ] 明确 Web 上传文件大小限制。
- [ ] 明确刷新、关闭浏览器、清缓存后的行为。
- [ ] Web 不支持的格式有清晰禁用文案。
- [ ] Web 能力不污染 Native 文件路径模型。

## 5. 本地解析与阅读器

- [ ] TXT 解析继续支持编码检测和章节规则。
- [ ] EPUB 解析避免长任务阻塞 UI。
- [ ] PDF 首次提取和分页按需执行。
- [ ] MOBI 解析失败路径可解释。
- [ ] 本地章节索引和正文缓存按存储规范落位。
- [ ] 阅读器按内容模式展示可用能力。
- [ ] 不支持模式不展示不可点击入口。

## 6. 缓存治理落地

关联文档：[缓存治理优化计划](cache_governance_optimization_plan_2026-06-02.md)

任务：

- [ ] 启动首帧后异步触发缓存治理。
- [ ] 6 小时节流，避免频繁扫描。
- [ ] 正文 DB 缓存按条数、体积、TTL 清理。
- [ ] 分页磁盘缓存按条数、体积、TTL 清理。
- [ ] 封面磁盘缓存纳入统一治理。
- [ ] 正文内存缓存改为 LRU + TTL。
- [ ] 手动缓存清理入口说明只删除可重建缓存。
- [ ] 清理失败只记录日志，不影响业务。

## 7. 资源能力多端化

资源范围：

- 封面。
- 阅读器背景。
- 高级主题资源。
- 字体。
- 启动图。
- 底部导航图标。

任务：

- [ ] 资源导入统一走 image / file selection service。
- [ ] Native 资源写入托管文件目录。
- [ ] Web 资源持久化策略单独定义。
- [ ] 资源缺失有占位和恢复路径。
- [ ] 资源导出、导入、删除不影响其他平台。
- [ ] 高级主题资源引用不使用绝对路径直连页面。

## 8. 诊断、日志与清理

- [ ] 诊断导出按平台 adapter 实现。
- [ ] Web 使用下载或复制方式。
- [ ] Desktop 使用保存文件或打开目录方式。
- [ ] 日志恢复失败不影响启动。
- [ ] 缓存清理、诊断导出、文件打开都通过 capability 展示。

## 9. 本地 override 依赖治理

当前需要重点说明的本地 override 类型：

- PDF 引擎 / 文本抽取。
- 字符集检测。
- 翻页组件。
- Web stub。

任务：

- [ ] 建立 override 清单：包名、原因、改动点、影响平台。
- [ ] 判断是否有成熟上游替代。
- [ ] 判断是否影响 Web JS / Web WASM。
- [ ] 为高风险 override 增加最小回归测试。
- [ ] 能回主线的逐步回主线。

## 10. 测试与验收

建议测试：

```bash
flutter test test/features/reader/application/local/txt_local_book_parser_test.dart
flutter test test/features/reader/application/local/epub_local_book_parser_test.dart
flutter test test/features/reader/application/local/pdf_local_book_parser_test.dart
flutter test test/features/reader/application/reader_pagination_cache_service_test.dart
flutter test test/core/cache/app_cache_governance_service_test.dart
```

建议 guard：

```bash
dart run tool/check_storage_governance_guard.dart
flutter analyze
flutter build web --no-pub
```

通过标准：

- [ ] Desktop 至少一种本地图书格式完整闭环。
- [ ] Web 本地内容支持/不支持范围清楚。
- [ ] 缓存不会长期无限膨胀。
- [ ] 用户资产不会被缓存治理误删。
- [ ] 存储 guard 通过。
- [ ] 资源导入、预览、删除在目标平台可解释。

## 11. 风险

- [ ] Web 持久化能力和 Native 文件系统差异很大，不能混用语义。
- [ ] PDF / EPUB / MOBI 解析可能引入长任务卡顿。
- [ ] 字符集检测和本地 override 可能影响 Windows / Linux。
- [ ] 缓存清理如果边界不清，可能误删用户资产。
- [ ] 字体和主题资源跨端路径恢复风险高。

## 12. 执行记录

- [ ] 开始日期：
- [ ] 完成日期：
- [ ] 已验证平台：
- [ ] 未验证平台和原因：
- [ ] 关键改动：
- [ ] 遗留问题：
