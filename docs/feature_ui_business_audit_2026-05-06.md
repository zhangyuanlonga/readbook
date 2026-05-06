# 功能级 UI / 业务审计记录

更新时间：2026-05-06  
用途：从整体项目与每个功能模块角度，审计因“按开发约束拆分”后可能引入的复杂化、性能拖慢与体验下降问题，作为后续按 feature 收敛的执行底稿。

## 1. 审计口径

本次审计重点看三类问题：

- UI 层是否存在同步 IO、item 级异步、根部过宽订阅、重建面过大
- 业务层是否存在链路过长、首屏阻塞、页面承担过多编排
- 拆分后是否引入“代码没出错但体验变差”的复杂化问题

遵循：

- `docs/development_architecture_guardrails.md`
- 页面只负责渲染、交互分发、订阅状态
- 重 IO / 重查询 / 重解析尽量不进入 build

---

## 2. 总体结论

### 2.1 风险等级

- 高风险：`bookshelf`、`book`、`reader`、`discover`、`search`、`home`
- 中风险：`mine`、`source`、`sync`
- 低风险：`announcement`、`auth`、`error`

### 2.2 已完成的核心治理

- 书架：展示态缓存、预计算、无效 notifier 更新收敛
- 阅读：bootstrap 拆成首屏必须 / 首屏后补
- 详情：首屏预览路径更稳定，supplementary state 后置
- 发现 / 搜索：从 item 级异步展示态改为列表级缓存
- 公共层：全局背景装饰移除同步 `existsSync()`，阅读目录头图改为弹层打开前预解析封面
- 中低频页：同步中心缩小 `profiles/jobs` 订阅范围，公告列表首屏改为并行拉取

### 2.3 已收口的公共残留

- `lib/app/widgets/advanced_theme_backdrop_decoration.dart`
  已移除 build / decoration 组装阶段的同步 `existsSync()`
- `lib/features/reader/presentation/reader_catalog_sheet.dart`
  目录头图已改为调用方预解析封面，不再在弹层内额外订阅主题 / 图集

---

## 3. 按功能审计

### 3.1 `announcement`

UI：

- 页面以列表和详情展示为主，结构清晰
- 未见高频 build 期同步文件探测

业务：

- 主要是拉取公告、阅读状态维护
- 业务链路相对简单
- 列表首屏已改为并行拉取 latest / page / readIds，减少串行等待

结论：

- 风险低
- 当前无需专项性能治理

### 3.2 `auth`

UI：

- 主要是表单、登录态跳转
- 未见高频复杂重建

业务：

- 登录、注册、刷新态链路已相对清晰
- 当前主要风险不在 UI 性能，而在鉴权边界正确性

结论：

- 风险低
- 无明显“复杂化拖慢体验”问题

### 3.3 `error`

UI：

- 错误中心用 `StreamBuilder` 订阅日志
- 列表规模通常有限

业务：

- 主要是日志展示

结论：

- 风险低

### 3.4 `book`

UI：

- 详情页是高频页，之前存在首屏短暂空白问题，已处理
- 当前仍有较多 section 和状态拼装，但首屏链路比之前好

业务：

- `loadDetail` 与 supplementary state 已拆分
- 页面仍承载较多协调逻辑，但已比原先更稳

残留关注：

- 详情页大型文件仍然复杂，维护成本高
- 补充状态后台回填的体验仍建议真机复核

结论：

- 风险高
- 体验风险已显著下降，但复杂度仍偏高

### 3.5 `bookshelf`

UI：

- 书架是最高频入口，已做一轮重点治理
- 展示态、进度、标题、作者、搜索文本都已预计算缓存

业务：

- 书架元数据、标签、分类、进度等聚合逻辑仍然很多
- 但目前已经有较明确的 service / query 分层

残留关注：

- 仍需真机复核滑动流畅度
- 仍需关注切换布局、筛选、搜索时的大量 UI 变更

结论：

- 风险高
- 当前属于“已收口但仍需体感验证”的核心模块

### 3.6 `discover`

UI：

- 已从 item 级 `FutureBuilder` 切到列表级展示态缓存
- 根部图集订阅已缩小

业务：

- 分类、书单、健康状态、调度冲突都在同一页里协调
- 页面逻辑仍然偏重

残留关注：

- 大结果集下展示态批量准备成本仍需观察
- 书单和分类切换的后台刷新节奏仍可继续优化

结论：

- 风险高
- 性能主风险已显著下降，复杂度仍偏高

### 3.7 `home`

UI：

- 继续阅读卡片的封面订阅已下沉到局部
- 页面根部仍 watch 主题，但影响相对可控

业务：

- 首页聚合阅读统计、连续阅读、排行等多块内容
- 当前主要是聚合复杂度，不是单点性能爆炸

结论：

- 风险高但可控
- 当前无需优先于书籍主链路处理

### 3.8 `mine`

UI：

- 管理页多、编辑页多、媒体资源页多
- 存在一些 `existsSync()` 与本地文件预览判断

业务：

- 主题、图集、字体、反馈、缓存、会员等职责密集
- 更大的问题是“功能密度高”，不是高频用户主链路性能

结论：

- 风险中
- 更偏维护复杂度风险，不是当前最高优先级

### 3.9 `reader`

UI：

- 已完成 bootstrap 第一轮收口
- 背景读取和正文缓存恢复路径已优化

业务：

- 仍然是全项目最复杂的业务页之一
- 涉及内容模式、分页、滚动、自动阅读、目录、注释、换源等

残留关注：

- 某些 runtime timer / post-frame 逻辑仍多

结论：

- 风险高
- 已缓解首屏问题，但仍是长期复杂度最高模块

### 3.10 `search`

UI：

- 已完成列表级展示态缓存
- 卡片主体已经比之前轻很多

业务：

- 搜索结果渲染、节流、分页、进度展示逻辑较多
- 但结构已明显优于此前 item 级异步版本

残留关注：

- 结果量非常大时分页与展示态准备仍需观察

结论：

- 风险高
- 当前性能主风险已较好控制

### 3.11 `source`

UI：

- `source_page.dart` / `source_page_flow.dart` / `source_login_page.dart` 文件都偏大
- 复杂度高于大多数 feature

业务：

- 登录模式分流、导入、批量检查、调试页、权限控制都集中在此
- 更明显的问题是“页面/流程复杂度高”

结论：

- 风险中
- 后续建议做结构瘦身，但优先级低于书籍主链路

### 3.12 `sync`

UI：

- 页面不是高频入口
- 更偏配置与后台执行反馈
- 已将 `profiles/jobs` 订阅缩到实际子树，后台任务变化不会再带动整页重建

业务：

- 同步域复杂，但当前主要风险在正确性与可维护性

结论：

- 风险中
- 当前不是体验治理优先项

---

## 4. 当前最值得继续处理的残留点

### 4.1 书源页职责仍偏重

文件：

- `lib/features/source/presentation/source_page.dart`
- `lib/features/source/presentation/source_page_flow.dart`
- `lib/features/source/presentation/source_login_page.dart`

问题：

- 登录、导入、批量检查、调试、权限态仍有较多 presentation 侧编排

影响：

- 主要拖慢后续迭代和问题定位
- 次要影响是页面 rebuild 与状态流难继续收窄

建议：

- 继续把导入 / 批量检查 / 登录流程下沉到 application service 或 flow coordinator

### 4.2 首页流式组合仍偏宽

文件：

- `lib/features/home/presentation/home_page.dart`

问题：

- `watchLatestRecords()` 与 `watchDailyRecords()` 仍是嵌套 `StreamBuilder`
- 汇总卡、继续阅读、排行区块共享同一轮大 rebuild

影响：

- 不是当前最重的卡顿点
- 但会放大阅读记录流变化对首页整体刷新的影响

建议：

- 后续可把 summary / continue reading 进一步拆成局部订阅组件

### 4.3 Mine 管理页仍有低频同步路径判断与双层异步

文件：

- `lib/features/mine/presentation/advanced_theme_editor_page.dart`
- `lib/features/mine/presentation/cache_management_page.dart`

问题：

- 主题编辑预览仍有 `existsSync()`
- 缓存管理仍是 `FutureBuilder + StreamBuilder` 双层组合

影响：

- 更偏低频管理页维护成本
- 不是当前优先级最高的用户体感问题

建议：

- 保持低优先级逐步收口，不必与高频阅读链路抢优先级

---

## 5. 审计结论

结论不是“每个功能都有严重问题”，而是：

- 真正会持续影响用户日常体验的高风险功能，仍然主要集中在书籍主链路
- 其他 feature 更多是复杂度偏高、管理页过重、局部低频同步路径判断
- 当前最优策略不是全项目同时大重构，而是：
  - 先把核心主链路性能收口
  - 再清理首页 / 书源这类“体感次高 + 复杂度高”的残留
  - 最后再做中频管理类页面的复杂度瘦身

---

## 6. 建议执行顺序

- [ ] 继续复核 `home_page.dart` 的流式组合重建范围
- [ ] 继续下沉 `source` 的登录 / 导入 / 批量检查流程
- [ ] 真机复核 `bookshelf / book detail / reader / discover / search`
- [ ] 若核心链路体感稳定，再进入 `source / mine` 的结构瘦身
