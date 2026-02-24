# Legado 全规则兼容总计划

## 目标

以 `docs/reference/legado_source_rule_2024-02-27.html` 为兼容基线，逐步将项目从“常用规则子集 + 兼容补丁”升级为“接近 Legado 全规则能力”。

## 当前基线（2026-02）

- 已具备：`html/json/regex` 主执行链，含 legacy 选择器兼容、链接后处理、script-only 轻量 fallback。
- 已落地（本轮）：
  - P0-A：正文请求 URL 后处理 + 非法 URL 兜底。
  - P0-B：search/toc 字段级 script-only 规则兼容。
- 仍缺失：`@put/@get` 变量链路、XPath 原生能力、完整 JS 运行时（`java.ajax/eval/md5/AES/java.get/java.put` 等）。

## 兼容范围拆解

### 1) 规则语法层

- JSoup 风格规则（class/tag/id/text/children、位置、排除、倒序）。
- JSONPath + 模板拼接 + 规则链式处理。
- 正则替换与捕获组。
- XPath 规则（含 `//.../@href`、`/text()`、常见谓词）。
- `@put/@get` 上下文变量读写。

### 2) 业务链路层

- 搜索：`searchUrl`、`ruleSearch`（list/name/url 等）。
- 发现：`ruleExplore`。
- 详情：`ruleBookInfo`。
- 目录：`ruleToc`。
- 正文：`ruleContent`、`nextContentUrl`。

### 3) 脚本运行层

- 字段级 `@js:` / `<js>` 常见表达式。
- 复杂动态脚本执行（含 Legado Java Bridge 语义）。

## 分阶段实施

## Phase 0：规范冻结与验收基线（1 天）

- 固化外部规范快照，避免目标漂移。
- 固化诊断基线：保留当前全量诊断 JSON，定义“按失败类型聚合”的对比口径。
- 产出：本计划 + 兼容清单模板。

验收：团队对“目标文档版本”和“统计口径”达成一致。

## Phase 1：高收益规则兼容扩展（3-5 天）

- 完成 `@put/@get` 变量链路（search/detail/toc/content 统一上下文）。
- 扩展 script-only 轻量执行子集（优先 URL 生成、JSON 提取、字符串拼接）。
- 将发现页 `ruleExplore` 接入与 search/toc 同等级 fallback。

验收：
- `search validation 缺规则`、`search ruleMatchEmpty` 在批量诊断中显著下降。
- 新增单测覆盖 `@put/@get` 串联场景。

## Phase 2：XPath 兼容层（4-6 天）

- 先做高频 XPath 映射到现有引擎（低风险高收益）。
- 对映射失败场景补 `xpath:` executor（最小可用集）。
- 打通 search/toc/content 三链路 XPath 规则执行。

验收：
- XPath 典型失败源样本可解析。
- `ruleMatchEmpty` 的 XPath 子集占比下降。

## Phase 3：JS 运行时最小闭环（7-10 天）

- 引入受限 JS Runtime（可开关）。
- 支持高频桥接 API：
  - `java.ajax`（受限网络策略）
  - `java.md5Encode`
  - 常见加解密（先 MD5，再逐步补 AES 子集）
  - `java.get/java.put`、`java.setContent/getElement` 最小实现
- 增加超时、调用次数、域名白名单等安全约束。

验收：
- `searchUrl 动态 JS` 失败类型明显下降。
- 默认关闭/开启两种模式均可稳定运行。

## Phase 4：全链路一致性与导出修源闭环（3-5 天）

- 将诊断错误类型与“建议修复动作”绑定，支持按失败类型聚合导出。
- 增加跨阶段失败串联（search 成功但 detail/toc/content 失败可追踪）。
- 统一错误码定义，便于批量修源。

验收：
- 同一源的多阶段失败可一键追溯。
- 导出报告可直接用于修源分工。

## Phase 5：全量验收与长期维护（持续）

- 每次大改后执行一次全量诊断（3722+）。
- 维护“未兼容能力清单”，持续清零。
- 建立回归样本集（失败源 + 已修复源）。

验收：
- 关键失败类型持续下降。
- 新增兼容不回归已有链路。

## 优先级（重新排序）

1. `@put/@get`（高收益、低到中风险）
2. XPath 高频兼容（高收益、中风险）
3. JS Runtime 最小闭环（最高收益、高风险）
4. 发现页与全链路一致性补齐（中收益、中风险）

## 执行策略

- 小步快跑：每个 Phase 先跑代表样本，再决定是否触发全量。
- 不频繁跑 2 小时全量：只在阶段完成点跑一次。
- 每阶段都保持“代码改动 + 单测 + 诊断对比报告”三件套。

## 近期执行顺序（从下一步开始）

1. 开始 Phase 1：先实现 `@put/@get`。
2. 同步补发现页 `ruleExplore` 的 script-only fallback。
3. 阶段性跑一轮中样本诊断，确认收益后进入 Phase 2。
