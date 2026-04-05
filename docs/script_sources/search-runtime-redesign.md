# 脚本源搜索运行时重构方案

更新时间：2026-04-05

当前说明：

- 本文只讨论 `flutterreadbook` 当前唯一运行态书源模型：脚本源。
- 旧规则 JSON、Legado 执行链、双轨兼容搜索都不在本文设计范围内。
- 本文目标不是重写搜索业务，而是把现有搜索、换源、自动换源链路升级成适配 JS 脚本源的运行时调度系统。

## 0. 进度总览

用于后续执行时直接打勾追踪阶段进度。

- [x] 阶段 A：搜索职责边界收口
- [x] 阶段 B：SearchService 结构拆分
- [x] 阶段 C：场景策略拆分
- [x] 阶段 D：执行画像基础版
- [x] 阶段 E：资源预算调度器
- [x] 阶段 F：取消链路下沉
- [x] 阶段 G：JS / Browser 运行时受控化
- [x] 阶段 H：运行时复用
- [x] 阶段 I：动态画像与熔断

## 1. 结论先行

当前搜索系统的核心问题，不是“新脚本源字段没有兼容”，而是宿主还在沿用旧规则时代的调度假设：

- 旧规则时代，搜索基本等价于“并发发出多个 HTTP 请求”
- 脚本源时代，搜索已经变成“并发执行多个运行时任务”

这两者的资源模型完全不同。

因此，下一阶段的最优解不是继续围绕“最大并发源数”做微调，而是同时落下三件事：

1. 明确方法职责边界：`search` 只搜，`detail / chapters / content` 后置
2. 引入跨平台统一的运行时调度层：按执行成本和资源预算调度，而不是按源数调度
3. 把 JS 运行时和 browser 运行时从“随手调用”升级成“受控资源”

一句话总结：

- 旧规则时代搜索关注“网络并发”
- 脚本源时代搜索必须关注“运行时调度”

## 2. 现状与问题

当前项目中的搜索和换源主链路已经统一到脚本源运行时：

- 搜索页通过 `SearchService` 批量搜索已启用脚本源
- 阅读页换源通过同一个 `SearchService` 做限定源范围的批量搜索
- 书源执行最终进入脚本运行时，逐源创建 `ctx`，执行 `search / detail / chapters / content`

当前主链文件：

- `lib/features/search/application/search_service.dart`
- `lib/features/search/presentation/search_page.dart`
- `lib/runtime/sources/source_executor.dart`
- `lib/runtime/sources/source_script_compiler.dart`
- `lib/src/js_runtime_native.dart`
- `lib/runtime/host/appread_browser_runtime.dart`

现状不是“逻辑错了”，而是运行时模型已经跟不上脚本源的执行成本。

### 2.1 当前并发模型仍然是旧规则思维

当前 `SearchService` 的核心模型是：

1. 取出所有目标源
2. 开固定数量 worker
3. 每个 worker 从队列中取一个源执行

这套模型默认假设每个源成本接近。但脚本源的真实成本差异很大：

- 有些源只是轻量 HTTP 请求
- 有些源会跑较重的 JS 逻辑
- 有些源在 `search()` 阶段就会触发 `ctx.browser`
- 有些源会在 `init()` 里做额外动作

因此“同时跑 6 个源”和“同时跑 6 个 JS 重源”不是同一个问题。

### 2.2 当前方法职责边界不够明确

旧规则时代大家容易默认：

- 搜索顺手补一些详情
- 搜索顺手试目录
- 搜索顺手做一些正文探测

在脚本源时代，这种做法会把搜索成本按源数放大。

如果搜索阶段跨到 `detail / chapters / content`，会带来：

- 更多 HTTP 请求
- 更多 JS 执行
- 更多 browser / challenge 机会
- 更重的主线程和内存压力

### 2.3 搜索、换源、自动换源共用了同一套策略

当前换源直接复用 `SearchService.search()`。

这会带来两个问题：

- 搜索页追求覆盖和吞吐
- 换源页追求稳定、低干扰、低延迟

这两个场景的目标不同，不应该只靠 `sourceIds` 区分。

### 2.4 崩溃风险已经从“业务错误”变成“运行时错误”

当前风险不再只是：

- 某个源返回字段不全
- 某个源脚本抛异常

还包括：

- `flutter_js` / JavaScriptCore 主线程压力
- WebView / interactive challenge 并发
- cookie / session / browser 状态竞争

这类问题不会表现成普通单源失败，而会直接影响宿主稳定性。

## 3. 对脚本源方法职责的重新约束

这是本次方案里最重要的一条原则。

### 3.1 搜索只做搜索

`search(ctx, keyword)` 的职责应该明确为：

- 找到书
- 返回可展示的最小 `Book[]`

搜索阶段不主动跨到：

- `detail()`
- `chapters()`
- `content()`

### 3.2 详情、目录、正文各自独立

- `detail(ctx, book)`：补全书籍卡片信息
- `chapters(ctx, book)`：获取目录
- `content(ctx, book, chapter)`：获取正文

这意味着：

- 搜索页不做详情预抓取
- 搜索页不做目录预抓取
- 搜索页不做正文预抓取
- 只有用户真正点进详情页或阅读页时，才进入后续链路

### 3.3 允许的例外

只有一种例外是合理的：

- 站点搜索接口本身已经直接返回完整书籍卡片信息

此时脚本可以直接把这些字段返回到 `Book`，但宿主不应该再主动追加额外详情请求。

### 3.4 为什么这条原则重要

因为这条原则同时解决四个问题：

- 多源搜索耗时被放大
- 多源搜索稳定性下降
- browser / challenge 在搜索阶段被过早触发
- JS 运行时在高并发下被过度放大

一句话：

- 搜索是发现入口，不是预加载入口

## 4. 新脚本源为什么理论上应该更快

“JS 脚本源应该比旧规则快”这件事，在条件满足时是成立的，但前提不是“脚本天生更快”，而是“宿主调度和方法边界足够合理”。

脚本源的理论优势在于：

- 一个源可以把 HTML、JSON、正则、状态机、上下文传递统一在一段脚本里
- 宿主不需要维护大量旧规则兼容分支
- `extra / session / cache / cookie / browser` 能表达更复杂站点
- 运行时能力更完整，作者不用绕很多宿主限制

但如果宿主还是用旧规则时代的调度模型，脚本源反而会更容易变慢：

- 每个源执行成本更高
- 更容易触发 JS 和 browser
- 宿主需要管理更多状态

所以正确结论是：

- 脚本源在“职责清晰 + 运行时受控 + 执行器可复用”时，应该比旧规则更稳、更容易优化，也更有机会更快
- 脚本源在“搜索阶段乱做重活 + 平铺并发”时，通常会比旧规则更重

## 5. 设计目标

本次重构目标：

- 把搜索系统明确为“脚本源运行时调度系统”
- 把并发控制从“源数量”改成“资源预算”
- 把搜索页、手动换源、自动换源拆成三套调度策略
- 让取消能力向下贯通到执行链
- 保持现有 UI 契约和标准结果模型尽量不变

非目标：

- 不恢复旧规则 JSON 运行链
- 不重写书源脚本规范
- 不要求作者在 `v1` 里额外学习复杂 DSL
- 不在第一阶段推翻现有 `SearchExecutionReport`

## 6. 跨平台判断

本方案不能只盯 `macOS`。

### 6.1 问题暴露平台与设计目标平台要分开看

当前崩溃证据来自 `macOS`，但它暴露的是架构问题，而不是单平台特例：

- `iOS / macOS` 同属 Apple 平台，JSCore 风险类型接近
- `Android` 虽然底层运行时实现不同，但脚本执行、Promise、bridge、browser/challenge 仍然会消耗宿主资源
- Flutter 层的搜索体验必须优先按跨平台设计，再按平台施加不同预算

### 6.2 正确的跨平台方案

应该分成两层：

- 通用层：统一运行时调度、预算、取消、报告
- 平台层：根据 Apple / Android / Desktop 的稳定性窗口设置不同预算

也就是说：

- 不是只修 `macOS`
- 而是用 `macOS` 先暴露出来的问题，推动一套全平台正确的调度模型

### 6.3 平台预算建议

建议默认值：

- Android：相对激进
- iOS：中等保守
- macOS：最保守
- Windows / Linux：按桌面中档处理

原因不是产品优先级，而是底层运行时稳定性和宿主资源模型不同。

## 7. 外部经验与宿主判断

结合公开资料和当前崩溃表现，可以得出几个对设计有价值的判断：

- `flutter_js` 在不同平台底层实现不同，Apple 端使用 `JavaScriptCore`，Android 使用 `QuickJS`，这意味着跨平台调度不能简单等同处理。
- `flutter_js` 的执行模型对 Flutter 宿主来说是同步/主线程敏感资源，而不是普通网络请求。
- 社区和运行时常见建议基本一致：重脚本执行、browser/challenge、cookie/session 同步都应被视作受控资源，而不是任由多源并发放大。

这些判断并不要求我们换掉脚本源方案，反而说明：

- 书源规范本身没问题
- 问题出在宿主对新运行时模型的资源管理还不够完整

## 8. 新架构概览

建议将现有链路拆成六层。

### 8.1 SearchService

职责：

- 面向 UI 提供统一搜索入口
- 创建搜索会话
- 组织 planner、scheduler、runner、assembler

边界：

- 不直接决定具体并发策略
- 不直接执行脚本源

### 8.2 SearchPlanner

职责：

- 根据场景生成搜索计划
- 决定要搜索哪些源
- 给每个源附带执行画像和优先级
- 生成不同场景的默认策略

建议支持的场景：

- `globalSearch`
- `switchSource`
- `autoSwitchSource`

### 8.3 SearchScheduler

职责：

- 按资源预算调度任务
- 控制不同执行画像的同时运行数量
- 支持暂停、恢复、取消
- 维护任务状态机

这层是本次重构的核心。

### 8.4 ScriptSourceSearchRunner

职责：

- 执行单个脚本源的 `search()` 任务
- 负责单源超时、异常转换、可取消执行
- 只返回标准 `Book[]`

边界：

- 不负责多源聚合
- 不负责 UI 进度节流
- 不负责顺手补详情、目录、正文

### 8.5 SearchReportAssembler

职责：

- 增量汇总单源结果
- 维护成功数、失败数、来源名映射
- 输出渐进式报告和最终报告
- 负责去重和可选聚合

### 8.6 SearchRuntimeProfileService

职责：

- 维护源级执行画像
- 记录耗时、browser 命中率、challenge 率、失败率
- 给后续调度提供动态权重

## 9. 执行画像

脚本源不需要暴露“旧规则类型”，但宿主必须知道搜索任务的资源画像。

建议新增：

```dart
enum SearchExecutionProfile {
  httpLight,
  jsHeavy,
  browserCapable,
  browserHeavy,
}
```

### 9.1 画像来源

第一阶段不要求作者手写声明，优先使用宿主推断：

- manifest 能力声明
- 历史运行数据
- 运行时是否触发过 browser API
- 单源平均耗时、平均失败率、平均 challenge 率

第二阶段可选支持作者提供提示字段，例如：

```js
meta: {
  name: '示例书源',
  capabilities: ['novel'],
  runtimeHints: {
    searchProfile: 'httpLight'
  }
}
```

这只是 hint，不是硬约束。最终仍由宿主决定真实调度成本。

## 10. 资源预算模型

当前应该放弃“最大并发源数”作为核心调度单位，改用 budget token。

示例：

- `httpLight` 占用 1 token
- `jsHeavy` 占用 2 token
- `browserCapable` 占用 3 token
- `browserHeavy` 占用 4 token

场景预算示例：

- 全局搜索：Android 6，iOS 4，macOS 3，Windows/Linux 5
- 手动换源：Android 3，iOS 2，macOS 2，Windows/Linux 3
- 自动换源：Android 2，iOS 1，macOS 1，Windows/Linux 2

调度规则：

1. 任务提交前先计算 cost
2. 当前空闲 budget 足够时再启动
3. 任务结束、失败或取消后归还 budget
4. 高优先级任务可插队，但不能突破总 budget

这样系统关心的是“当前能承载多少运行时负载”，而不是“正在跑几个源”。

## 11. 取消模型

取消必须从 UI 层下沉到执行层。

建议引入统一取消上下文：

```dart
class SearchRunCancellation {
  bool get isCancelled;
  Future<void> get whenCancelled;
}
```

并向下传到：

- `SearchScheduler`
- `ScriptSourceSearchRunner`
- `RequestEngine`
- `BrowserRuntime`
- 需要长耗时等待的 JS host bridge

目标行为：

- 新任务不再启动
- 在途 HTTP 请求尽快中断
- challenge / WebView 任务尽快关闭或失效
- 已失效结果不再回灌 UI

## 12. 运行时层面的最优解

这是本次方案里最需要拍板的部分。

### 12.1 不是简单压低并发

“把最大并发从 8 改成 2”只能止血，不能从根上解决问题。

因为它没有解决：

- 搜索阶段职责过重
- JS 与 browser 成本不均
- 同一个源重复创建运行时
- 搜索、换源、自动换源的策略目标不同

### 12.2 最优解

最优解是三件事一起成立：

1. 搜索阶段只执行 `search()`
2. 调度器按执行画像和预算做资源调度
3. JS / browser 运行时做受控串行或复用

这比单纯压并发更优，因为它既保稳定，也保未来性能空间。

### 12.3 为什么这是最优解

因为它同时满足：

- 对新脚本源友好
- 对 Flutter 多平台友好
- 对作者心智负担小
- 对宿主后续优化留足空间

而且它不需要回退到旧规则时代的架构。

## 13. 当前代码与问题映射

### 13.1 当前可复用部分

- `SearchExecutionReport`
- `SourceSearchFailure`
- 搜索结果聚合和排序逻辑
- 搜索页的进度节流和渲染节流

### 13.2 当前已经暴露的宿主瓶颈

- `SearchService` 仍然以“固定 worker 并发”驱动搜索
- `_SourceScriptRunner` 每次调用都创建新的 JS runtime
- browser 执行链已经需要被视作串行资源

### 13.3 需要拆出的新模块

- `lib/features/search/application/search_planner.dart`
- `lib/features/search/application/search_scheduler.dart`
- `lib/features/search/application/search_session.dart`
- `lib/features/search/application/script_source_search_runner.dart`
- `lib/features/search/application/search_report_assembler.dart`
- `lib/features/search/application/search_runtime_profile_service.dart`

## 14. 分阶段落地

### 阶段一：职责边界收口

目标：

- 明确搜索阶段只执行 `search()`
- 禁止宿主在搜索阶段顺手补 `detail / chapters / content`
- 把手动换源、自动换源的后续补全逻辑放到真正需要时再触发

验收：

- 搜索结果页仍可正常展示
- 多源搜索平均请求数下降
- 搜索阶段 browser/challenge 命中率下降

### 阶段二：结构拆分，不改 UI 契约

目标：

- 把当前 `SearchService` 的逻辑拆到 planner、scheduler、runner、assembler
- 保持 `search()` 方法签名和 `SearchExecutionReport` 不变
- 继续复用现有搜索页和换源页 UI

验收：

- 搜索页功能不回退
- 换源页功能不回退
- 分析和测试通过

### 阶段三：场景策略拆分

目标：

- 搜索页使用 `globalSearch` 策略
- 换源页使用 `switchSource` 策略
- 自动换源使用 `autoSwitchSource` 策略

验收：

- 手动换源的资源占用低于全局搜索
- 自动换源不会弹出需要用户交互的 challenge

### 阶段四：真正的预算调度

目标：

- 按 `httpLight / jsHeavy / browserCapable / browserHeavy` 分类调度
- 预算按平台和场景生效
- browser 型任务进入严格受控队列

验收：

- 多源搜索在移动端和桌面端都稳定
- 高风险源不会长期挤占轻量源吞吐

### 阶段五：运行时复用

目标：

- 从“每次调用新建 JS runtime”演进到“按 sourceId 复用执行器”
- 把公共 bootstrap、bridge 注册、脚本预热前置

验收：

- 重复搜索、详情、目录、正文调用的运行时开销下降
- Apple 端主线程抖动降低

### 阶段六：动态画像与熔断

目标：

- 基于历史运行数据回写画像
- 对高风险源自动收紧预算
- 对连续失败源做短时熔断

验收：

- 高频重源不会长期拖累整体搜索
- 宿主稳定性显著提升

## 15. 当前最值得先做的实现顺序

如果现在开始动代码，建议不要先碰 UI。

推荐顺序：

1. 落定“搜索只搜”的宿主原则
2. 从 `SearchService` 中拆出 `ScriptSourceSearchRunner`
3. 从 `SearchService` 中拆出 `SearchReportAssembler`
4. 新增 `SearchPlanner`，先只支持 `globalSearch` 和 `switchSource`
5. 再引入预算调度器
6. 最后做 runtime 复用

这样做的收益：

- 风险最低
- 改动边界清晰
- 能先止住搜索阶段职责膨胀
- 后续再引入预算调度器时不会推翻前一步

## 16. 最终结论

当前项目的搜索设计已经不该再围绕“书源数量并发”展开，而应该围绕“脚本源运行时负载”展开。

正确的演进方向不是回到旧规则时代的通用抽象，而是明确承认：

- 这是脚本源专用搜索系统
- 搜索页、换源页、自动换源是三种不同调度场景
- 搜索阶段只负责 `search()`
- 调度器关心的是资源预算，不是任务个数
- JS runtime 与 browser runtime 都是受控资源

后续如果继续推进实现，应以本文为准，逐步把现有 `SearchService` 拆成可维护、可扩展、跨平台稳定的脚本源搜索运行时。

## 17. 阶段任务清单

以下清单用于直接推进实现。所有任务都按“可打勾、可验收”的粒度拆分。

### 阶段 A：搜索职责边界收口

- [x] 审计搜索链路，确认宿主搜索阶段只调用 `search()`，不主动追加 `detail / chapters / content`
- [x] 审计换源链路，确认换源搜索阶段只做候选发现，不在搜索阶段补抓详情和目录
- [x] 审计自动换源链路，确认自动换源不会在搜索阶段触发额外详情/正文探测
- [x] 为“搜索只搜”的宿主约束补文档说明到作者手册或运行时文档
- [x] 补测试：搜索结果页只依赖 `Book` 最小字段即可正常渲染
- [x] 补测试：搜索阶段不因宿主侧追加详情请求而放大请求数

验收：

- [x] 搜索结果仍可正常展示
- [x] 换源候选仍可正常产出
- [x] 搜索阶段总请求数相对现状下降或不增加

### 阶段 B：SearchService 结构拆分

- [x] 新增 `lib/features/search/application/script_source_search_runner.dart`
- [x] 从 `SearchService` 中抽出单源执行逻辑到 `ScriptSourceSearchRunner`
- [x] 新增 `lib/features/search/application/search_report_assembler.dart`
- [x] 从 `SearchService` 中抽出报告聚合逻辑到 `SearchReportAssembler`
- [x] 新增 `lib/features/search/application/search_planner.dart`
- [x] 把源筛选、场景计划、优先级计算迁入 `SearchPlanner`
- [x] `SearchService` 收口为会话组织者，不再同时承担调度、单源执行、聚合三类职责
- [x] 补测试：拆分后 `SearchExecutionReport` 对外结构保持不变

验收：

- [x] `SearchService.search()` 方法签名保持不变
- [x] 搜索页 UI 无需改动即可继续工作
- [x] 现有搜索测试通过

### 阶段 C：场景策略拆分

- [x] 为 `SearchPlanner` 增加 `globalSearch` 场景
- [x] 为 `SearchPlanner` 增加 `switchSource` 场景
- [x] 为 `SearchPlanner` 增加 `autoSwitchSource` 场景
- [x] 搜索页接入 `globalSearch` 计划
- [x] 手动换源接入 `switchSource` 计划
- [x] 自动换源接入 `autoSwitchSource` 计划
- [x] 自动换源策略中禁用需要用户交互的 challenge 流程
- [x] 补测试：同一批源在不同场景下会生成不同计划

验收：

- [x] 全局搜索覆盖率不回退
- [x] 手动换源资源占用低于全局搜索
- [x] 自动换源不弹用户交互验证

### 阶段 D：执行画像基础版

- [x] 新增 `lib/features/search/application/search_runtime_profile_service.dart`
- [x] 定义 `SearchExecutionProfile` 枚举
- [x] 第一版实现宿主侧画像推断，不要求脚本源提供任何新字段
- [x] 推断依据至少包含：browser 命中、平均耗时、平均失败率
- [x] 为搜索结果和运行日志补充 profile 可观测信息
- [x] 补测试：轻量源、重源、browser 源能被正确分类

验收：

- [x] 不修改现有脚本源写法也能完成分类
- [x] profile 结果可被调度器消费

### 阶段 E：资源预算调度器

- [x] 新增 `lib/features/search/application/search_scheduler.dart`
- [x] 将当前固定 worker 并发从 `SearchService` 中移除
- [x] 改为按 `budget token` 调度，而不是按“最大并发源数”调度
- [x] 实现 `httpLight / jsHeavy / browserCapable / browserHeavy` 的 cost 映射
- [x] 为 Android / iOS / macOS / Windows / Linux 提供默认预算配置
- [x] 为全局搜索 / 手动换源 / 自动换源提供不同预算配置
- [x] browser 型任务进入受控队列，不再与普通任务同权并发
- [x] 补测试：预算不足时任务排队，预算归还后继续执行
- [x] 补测试：browser 型任务不会与同类重任务无上限并发

验收：

- [x] 多源搜索在移动端和桌面端都能稳定跑完
- [x] 高风险源不会长期挤占轻量源吞吐
- [x] 两三千源场景下仍能持续产出渐进结果

### 阶段 F：取消链路下沉

- [x] 新增统一取消上下文，例如 `SearchRunCancellation`
- [x] `SearchScheduler` 支持停止派发和清理待运行任务
- [x] `ScriptSourceSearchRunner` 支持关键节点检查取消
- [x] `RequestEngine` 支持在可行范围内尽快中止请求
- [x] `BrowserRuntime` 支持任务失效，不再回灌已取消结果
- [x] JS host bridge 的长等待点支持响应取消
- [x] 搜索页切换关键词、筛选条件、内容模式时旧任务立即失效
- [x] 补测试：连续触发搜索不会造成旧任务长时间滞留

验收：

- [x] 取消后不会再有旧结果污染当前 UI
- [x] 后台遗留任务数量显著下降

### 阶段 G：JS / Browser 运行时受控化

- [x] 保持 browser 执行链串行或受控限流
- [x] 保持 JS runtime 执行链串行或受控限流
- [x] 明确区分“普通 HTTP 任务”和“运行时重任务”
- [x] 为 Apple 平台设置更保守的默认策略
- [x] 为 Android 设置相对更激进但仍受控的默认策略
- [x] 补测试：多源并发搜索不会同时放大 JS runtime 与 browser runtime

验收：

- [x] macOS / iOS 上多源搜索稳定性提升
- [x] Android 上吞吐不因保守策略明显回退

### 阶段 H：运行时复用

- [x] 评估并实现按 `sourceId` 复用脚本执行器的方案
- [x] 将公共 bootstrap 和 bridge 注册前置
- [x] 避免重复创建 JS runtime 的高频成本
- [x] 为 runtime 复用补生命周期管理
- [x] 补测试：复用执行器后结果不串源、不串 session、不串 cookie

验收：

- [x] 搜索、详情、目录、正文的重复调用开销下降
- [x] Apple 端主线程压力下降

### 阶段 I：动态画像与熔断

- [x] 基于历史执行结果回写源级画像
- [x] 为高失败率、高 challenge 率、高 browser 命中率源自动收紧预算
- [x] 为连续失败源增加短时熔断
- [x] 为熔断状态提供可观测日志
- [x] 补测试：连续失败源不会持续拖慢整体搜索

验收：

- [x] 高频重源不会长期拖累整体吞吐
- [x] 搜索稳定性持续提升

## 18. 推荐执行顺序

如果立即开始执行，建议按下面顺序推进：

1. [x] 先做阶段 A：把“搜索只搜”边界收口
2. [x] 再做阶段 B：拆 `Runner / Assembler / Planner`
3. [x] 再做阶段 C：把搜索、换源、自动换源分成三套计划
4. [x] 再做阶段 D + E：引入画像和预算调度
5. [x] 再做阶段 F + G：把取消、JS、browser 资源真正控住
6. [x] 最后做阶段 H + I：运行时复用、动态画像、熔断

## 19. 当前最优起步批次

如果下一步要直接开工，第一批建议只做这些：

- [x] 阶段 A 全部完成
- [x] 阶段 B 全部完成
- [x] 阶段 C 先完成 `globalSearch` 和 `switchSource`

这批做完后再进入：

- [x] 阶段 D
- [x] 阶段 E

原因：

- [x] 风险最低
- [x] 改动边界清晰
- [x] 能先止住搜索阶段职责膨胀
- [x] 后续预算调度器接入时不需要推翻前面代码
