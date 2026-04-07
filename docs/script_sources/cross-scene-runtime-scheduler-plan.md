# 脚本源跨场景任务调度改进计划

更新时间：2026-04-06

当前说明：

- 本文只讨论 `flutterreadbook` 当前脚本源运行时在多场景并发下的任务调度问题。
- 范围覆盖所有在线书源相关场景：
  - 书架
  - 发现
  - 详情
  - 目录
  - 正文
  - 换源
  - 检测
  - 以及后续任何复用在线书源 runtime 的后台刷新/预取任务
- 本文不讨论旧规则 JSON、Legado 执行链，也不讨论页面 UI 设计细节。

## 0. 结论先行

当前项目已经具备一批“运行时保护能力”，但还缺“跨场景任务调度能力”。

当前已有：

- 执行策略收口：`SourceRuntimeExecutionPolicyService`
- warm state：`SourceRuntimeWarmStateService`
- 资源门控：`SourceRuntimeTaskGateService`
- 容器隔离：request isolated / flow isolated / diagnostic container
- 一部分取消能力：搜索链、部分浏览器链、会话取消句柄

当前缺少：

- 跨场景任务优先级
- 同源 / 同书 / 同场景冲突检测
- 后台任务主动让路
- 进入前台阅读链时取消低优先级后台任务
- 容器“排队 / 复用 / 抢占 / 取消”的统一仲裁
- 针对所有在线书源任务的一致调度口径，而不是哪个页面出问题就在哪个页面单点打补丁

一句话总结：

- 现在系统有“限流”
- 但还没有“业务级任务调度”

## 1. 背景问题

最近暴露出的闪退问题，已经不再只是“单个书源返回错字段”。

更常见的真实场景是：

1. 书架页自动刷新最新章节，后台跑 `detail + chapters`
2. 用户立刻进入阅读页，开始 `content` 或切章
3. 发现页切换书源时，又触发 `discoverCategories + discoverBooks`
4. 详情页和阅读页可能共用同一本书的运行时流程容器

这些链路单独看都合理，但同时发生时会争用同一套脚本运行时资源。

表现包括：

- iOS / JavaScriptCore 原生崩溃
- `flutter_js` bridge 不稳定
- 旧后台任务切页后还继续跑
- 非前台链路和当前阅读链互相干扰

## 2. 当前能力为什么不够

### 2.1 `TaskGate` 解决的是预算，不是业务仲裁

`SourceRuntimeTaskGateService` 当前主要做的是：

- 根据平台给出总预算
- 根据 profile 给任务估算成本
- 在预算内放行任务

它能解决：

- 不让重任务无限并发

但它解决不了：

- 书架后台刷新与阅读前台任务谁该优先
- 后台任务是否应直接取消，而不是等待
- 同一本书的不同场景任务能否共存

### 2.2 容器隔离不等于调度完成

当前已有多种容器：

- request isolated
- reading flow isolated
- diagnostic container

这些容器解决的是：

- session / cookie / cache 隔离

但它们不负责：

- 何时创建
- 与谁冲突
- 谁应该复用
- 谁应该让路
- 谁应该直接被取消

### 2.3 页面级 token 只能挡回写，挡不住运行时继续执行

很多页面现在已有：

- `ticket`
- `requestToken`
- `mounted` 判断

这些只解决：

- 老任务不再回写 UI

但它解决不了：

- 旧任务本身仍在跑 runtime
- 旧任务仍可能占用 request / browser / JS 资源

## 3. 典型冲突场景

### 3.1 书架后台刷新 vs 阅读切章

场景：

- 书架页自动刷新最新章节
- 后台触发 `detail + chapters`
- 用户立刻进入阅读页切章，前台触发 `content`

风险：

- 后台刷新和前台阅读链争用同一 source runtime
- 后台任务本应低优先级，却没有主动让路

### 3.2 发现切源 vs 详情 / 阅读

场景：

- 发现页切换书源，触发 `discoverCategories + discoverBooks`
- 同时某本书的详情 / 阅读链还在执行

风险：

- discover 看似独立，但底层仍在争抢同一平台 JS 运行时资源

### 3.3 检测链 vs 正式业务链

场景：

- 用户正在阅读或搜索
- 同时又去触发单源检测或批量检测

风险：

- 诊断链虽然已有独立容器，但仍会争用全局运行时资源

### 3.4 同一本书多入口重复拉链路

场景：

- 书架点开详情
- 详情页又拉目录
- 阅读页切入后再拉正文
- 书架后台刷新此时又对同一本书拉一次 `detail + chapters`

风险：

- 同一本书链路重复创建多个任务
- 容器层虽有隔离，但调度层没有“同书互斥/复用”意识

## 4. 阶段 1 任务盘点

这一节作为第一阶段的直接执行清单，先把当前在线书源相关任务盘清楚。

### 4.1 字段说明

- `scene`：任务所属场景
- `priority`：建议优先级
- `conflict key`：建议用于冲突判断的 key
- `当前状态`：现在大致处于什么治理状态
- `建议 disposition`：未来接入统一调度后，冲突时优先采用的处理方式

### 4.2 任务表

| 任务 | 入口/场景 | scene | priority | conflict key | 当前状态 | 建议 disposition |
| --- | --- | --- | --- | --- | --- | --- |
| 全局搜索 | 搜索页主动搜索 | `search` | `foregroundInteractive` | `sourceId` | 已有独立搜索调度器与预算 | `run / queue` |
| 手动换源搜索 | 阅读页切换书源时搜索候选 | `search` | `foregroundInteractive` | `sourceId + title` | 已复用搜索链，带取消 token | `run / queue` |
| 自动换源搜索 | 阅读失败后自动找候选源 | `search` | `foregroundInteractive` | `sourceId + title` | 已复用搜索链，预算更保守 | `run / queue` |
| 发现分类加载 | 发现页切源后拉分类 | `discover` | `foregroundInteractive` | `sourceId` | 已有 gate，但无统一场景仲裁 | `run / queue` |
| 发现书单加载 | 发现页切分类/翻页 | `discover` | `foregroundInteractive` | `sourceId + categoryUrl` | 已有 gate，但无统一场景仲裁 | `run / queue` |
| 详情加载 | 详情页主动打开书籍 | `detail` | `foregroundInteractive` | `sourceId + detailUrl` | 走阅读 flow isolated | `run / reuse` |
| 目录加载 | 详情页目录拉取 | `detail` | `foregroundInteractive` | `sourceId + detailUrl` | 走阅读 flow isolated | `reuse / queue` |
| 正文加载 | 阅读页首次打开正文 | `reader` | `foregroundCritical` | `flowKey` | 走阅读 flow isolated | `run / reuse` |
| 切章正文加载 | 阅读页上一章/下一章/目录跳转 | `reader` | `foregroundCritical` | `flowKey` | 已有页面级 request token，无统一场景仲裁 | `reuse / cancel lower priority` |
| 书架后台刷新最新章节 | 书架进入/切回后后台拉 `detail + chapters` | `bookshelfBackground` | `backgroundRefresh` | `sourceId + detailUrl` | 已加页面级取消与独立诊断容器 | `cancel / queue` |
| 书架打开书籍预拉详情 | 从书架打开在线书籍前拉 `detail + chapters` | `detail` | `foregroundInteractive` | `sourceId + detailUrl` | 走正常详情链 | `run / reuse` |
| 单源检测 | 书源页检测单个源 | `sourceCheck` | `diagnostic` | `sourceId` | 已有独立诊断容器 | `queue / cancel` |
| 批量检测 | 书源页批量检测多个源 | `sourceCheck` | `diagnostic` | `sourceId` | 已有独立诊断容器 | `queue / cancel` |
| 浏览器 challenge | 搜索/发现/阅读中触发 challenge | `browserInteractive` | `foregroundCritical` 或 `foregroundInteractive` | `sourceId` | 有浏览器独占队列，但缺跨场景仲裁 | `run / queue` |

### 4.3 第一批必须纳入统一调度的任务

按照当前闪退风险排序，第一批先接入统一调度的任务建议是：

1. 书架后台刷新最新章节
2. 阅读页正文加载 / 切章
3. 详情页 `detail + chapters`
4. 发现页 `discoverCategories + discoverBooks`
5. 单源检测 / 批量检测

原因：

- 这些任务都可能直接触发脚本源 runtime
- 且都已经在真实使用中出现过与前台阅读链冲突的迹象

### 4.4 第一批默认规则

在统一调度服务落地前，先明确默认规则，后续实现时不得偏离：

- `reader` 高于一切后台任务
- `detail` 高于 `bookshelfBackground`
- `discover` 遇到同源 `reader` 时，在保守平台上默认让路
- `sourceCheck` 不抢前台阅读、详情、发现链
- `bookshelfBackground` 不允许和同书 `detail / reader` 共存

## 4. 我们到底缺什么

更准确的名称不是“缺并发控制”，而是：

## 缺跨场景任务调度能力

这个能力至少应回答五个问题：

1. 这个任务属于前台还是后台？
2. 这个任务和哪些 source / book / flowKey 冲突？
3. 冲突时是排队、复用、抢占，还是取消？
4. 页面已经切走后，这个后台任务还值不值得继续跑？
5. 当前平台上，这类任务应采用多保守的策略？

## 5. 设计目标

本次方案目标：

- 在现有 gate / container / health 基础上，补一层任务调度仲裁
- 把“后台任务继续跑”收敛成明确、可控的策略
- 保证前台阅读 / 切章 / 详情 / 切源优先于后台刷新
- 保持平台差异化预算，但统一调度模型
- 明确所有在线书源相关任务都必须接入同一套调度语义

非目标：

- 不推翻现有 `SourceRuntimeTaskGateService`
- 不把所有任务永远强制串行
- 不要求所有页面自己写一套调度逻辑

## 6. 推荐模型

建议新增统一调度概念：

- `scene`
- `priority`
- `conflict key`
- `disposition`

### 6.1 scene

建议至少区分：

- `bookshelfBackground`
- `discover`
- `detail`
- `reader`
- `search`
- `sourceCheck`

### 6.2 priority

建议按业务意义分级：

- `foregroundCritical`
  - 正在阅读正文
  - 切章
  - 用户主动打开详情
- `foregroundInteractive`
  - 发现切源
  - 搜索
  - 手动换源
- `backgroundRefresh`
  - 书架自动刷新最新章节
  - 被动预取
- `diagnostic`
  - 检测链

### 6.3 conflict key

建议按不同粒度建 key：

- `sourceId`
- `sourceId + detailUrl`
- `flowKey`

用途：

- 判断是不是同一本书
- 判断是不是同一阅读流程
- 判断是不是同一 source 的高风险资源冲突

### 6.4 disposition

任务冲突时，不应该一律等待。

建议支持四种结果：

- `run`
- `queue`
- `reuse`
- `cancel`

## 7. 推荐仲裁规则

### 7.1 后台刷新默认让路

规则：

- `bookshelfBackground` 遇到 `reader / detail / discover` 前台任务时
- 默认取消，不排队

原因：

- 后台刷新不是用户当前主路径

### 7.2 同一本书的前台链路优先复用或独占

规则：

- 同一 `sourceId + detailUrl` 的详情 / 目录 / 正文链
- 应优先复用已有阅读 flow
- 或在无法复用时阻止后台刷新再开新链

### 7.3 检测链永远低于正式业务链

规则：

- `sourceCheck` 碰到 `reader / detail / discover / search`
- 默认排队或取消，不抢前台资源

### 7.4 discover 不能和阅读链无限制共振

规则：

- `discover` 遇到同源 `reader`
- 平台保守模式下应串行
- 至少 iOS 上应优先保证阅读链

## 8. 与现有模块的关系

### 8.1 `SourceRuntimeTaskGateService`

继续保留，负责：

- 平台预算
- profile cost
- 全局资源门控

不负责：

- 场景优先级仲裁
- 业务取消策略

### 8.2 `SourceRuntimeExecutionPolicyService`

继续保留，负责：

- 决定 request isolated / flow isolated / shared
- 决定 `serializeStartup`
- 决定 `markWarmOnSuccess`

不负责：

- 是否允许当前任务启动
- 是否需要取消后台任务

### 8.3 新增调度层

建议新增：

- `SourceRuntimeSchedulerService`

职责：

- 接收任务描述
- 根据 scene / priority / conflict key 决定 run/queue/reuse/cancel
- 再把可执行任务交给现有 gate 和 facade

## 9. 分阶段落地建议

### 阶段 A：先补后台刷新取消

- [ ] 书架后台刷新离开 `/bookshelf` 时取消
- [ ] 打开阅读 / 详情前取消后台刷新
- [ ] 后台刷新链统一接入 cancellation handle
- [ ] 盘点所有在线书源后台任务，明确哪些属于低优先级可取消任务

验收：

- 书架自动刷新不再和阅读切章长期重叠

### 阶段 B：建立场景优先级

- [ ] 定义 scene 与 priority
- [ ] 在 discover / detail / reader / bookshelfBackground 上统一接入

验收：

- 前台任务永远优先于后台刷新

### 阶段 C：建立 conflict key

- [ ] 为任务附带 `sourceId`
- [ ] 为书籍链附带 `detailUrl` / `flowKey`
- [ ] 同书任务冲突时优先复用或取消低优先级任务

验收：

- 同一本书不再被后台链重复拉起多条流程

### 阶段 D：统一仲裁入口

- [ ] 新增调度服务
- [ ] 页面与业务服务不再自己散落判断“该不该取消”
- [ ] 新增任务必须声明 scene / priority / conflict key，不能绕过调度层直接裸跑在线书源

验收：

- 书架 / 发现 / 详情 / 阅读 / 检测 统一走一套仲裁逻辑

## 10. 验收标准

- [ ] 书架自动刷新期间进入阅读，不再触发宿主闪退
- [ ] 发现切源期间进入详情或阅读，不再出现明显 runtime 互撞
- [ ] 同书详情 / 目录 / 正文链不会被后台刷新重复打断
- [ ] 检测链不会抢占前台阅读链
- [ ] iOS 与 Android 共用同一调度模型，但平台预算仍可不同
- [ ] 所有在线书源任务都能明确归类为前台、后台、诊断或可取消任务

## 11. 最终判断

当前问题不能简单归类为：

- 某个源写得不正规
- 某个页面少了 mounted 判断
- 某个平台单独不稳定

更准确的判断是：

- 宿主已有运行时门控能力
- 但缺跨场景任务调度能力

一句话总结：

- 现在系统知道“最多能跑多少”
- 但还不知道“谁该先跑、谁该让路、谁该取消、谁该复用”
