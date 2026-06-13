# 项目综合阶段开发任务派发版

**日期**: 2026-06-13  
**来源**: `docs/project-comprehensive-assessment-2026-06-13.md`  
**用途**: 面向开发同学派发阶段任务，避免把综合审计里的长期建议误当作当前发版阻塞项。  
**总原则**: 先稳定核心链路，再做架构治理；先抽边界和组件，再做视觉升级；每阶段都必须有可验证交付物。

---

## 0. 执行原则

- [ ] 不一次性重构多个核心模块，避免 Reader、Mine、Bookshelf 同时不稳定。
- [ ] 不以行数为唯一目标；行数下降必须伴随测试、smoke 和职责边界变清晰。
- [ ] 不为了共享率强行抽公共组件；只有 2 个以上 feature 真实复用时再进入 app/design system。
- [ ] 不把 Hero 数量、共享组件占比、重复率下降百分比作为硬 KPI，改用关键路径覆盖和重复模式清单。
- [ ] 不追求“纯 Dart 移除原生桥接”，正确目标是平台能力 facade 化、边界隔离、可测试。
- [ ] 每个任务完成后必须补充对应测试或明确无法自动化的手测清单。

---

## 1. 当前优先级

| 优先级 | 模块 | 原因 | 当前策略 |
|---|---|---|---|
| 跟踪 | Reader 阅读器 | 当前正在计划三内重构，直接影响阅读核心体验 | 仅跟踪，不外派；其他同学不要并行改 reader 核心 |
| P0 | Design System 基础件 | 多模块重复 UI 逐渐增多 | 先建 tokens/基础组件，不大规模迁移 |
| P1 | Mine 我的 | 私有书源、高级主题、会员、外观路径复杂且近期 bug 多 | Reader 稳定后优先拆分 |
| P1 | Bookshelf 书架 | `bookshelf_page.dart` 超大，用户高频入口 | 先拆卡片/筛选/排序/弹层 |
| P2 | Book/Search | 详情和搜索都有超大页面，但业务链路相对清晰 | 按关键路径逐步拆 |
| P2 | UX 动画/响应式/性能组件 | 提升高级感和跨端体验 | 在核心稳定后做关键路径覆盖 |

---

## 2. Reader 计划三跟踪项（不派发）

**目标**: 当前线程继续按计划三完成阅读器重构收口，派发文档只记录依赖和禁改边界。  
**参考文档**: `docs/features/reader/reader-refactoring-development-plan-3-2026-06-13.md`  
**负责人**: 当前 Reader 重构负责人。  
**派发结论**: 不派发给其他同学，不作为外部可领取任务。

### 当前跟踪项

- [ ] Reader 阶段1收口继续按计划三执行。
- [ ] `reader_page_settings_sheet.dart`、`reader_page.dart`、reader page part 解耦不在本派发文档里拆给其他人。
- [ ] Reader Android 真机 smoke 由当前 Reader 重构负责人统一执行和记录。

### 禁改边界

- [ ] 其他同学不要并行修改 `reader_page.dart`、`reader_page_settings_sheet.dart`、reader page `part` 文件。
- [ ] 其他同学不要并行修改翻页、章节定位、阅读进度、书源切换、设置持久化核心逻辑。
- [ ] 不改 `ReaderSettings` 存储结构，不改翻页动画算法，不改章节定位和阅读进度 payload。

### 对外依赖

- [ ] Design System 可先做 tokens/基础组件，但不要迁移 Reader 页面。
- [ ] Mine/Bookshelf 可并行做页面拆分，但不要改阅读入口协议和 Reader 路由参数。
- [ ] 如其他任务必须触碰 Reader，先同步当前 Reader 重构负责人再排期。

---

## 3. Phase 1：Design System 基础件

**目标**: 建立最小可用设计系统，让后续 Mine/Bookshelf/Search 拆分有统一组件可用。  
**建议周期**: 1-2 周  
**负责人建议**: UI/Flutter 基础组件同学负责，业务同学配合迁移。

### 任务 1：设计令牌

- [ ] 新建或整理 `lib/design_system/tokens/`。
- [ ] 定义 spacing、radius、duration、elevation、breakpoints。
- [ ] 明确与现有 `app/theme/`、`app/layout/` 的关系，不重复造两套主题。
- [ ] 提供迁移说明：旧组件如何引用 token。

### 任务 2：基础组件

- [ ] 统一 Button：primary、secondary、danger、ghost、text、icon。
- [ ] 统一 Input/TextField：搜索、表单、只读、错误态。
- [ ] 统一 BottomSheet/Dialog frame：安全区、最大宽度、标题栏、操作区。
- [ ] 统一 Loading/Empty/Error state：列表页、详情页、局部卡片。
- [ ] 统一 Card/ListTile：普通卡片、可点击卡片、选择态、危险操作态。

### 任务 3：基础文档和测试

- [ ] 为每个基础组件补 widget smoke test。
- [ ] 新建 design system 使用说明，包含“什么时候放 app/design system，什么时候留在 feature”。
- [ ] 选 1 个低风险页面做试点迁移，不要全项目一次性替换。

### 验收

- [ ] 基础组件可在 Mine/Bookshelf 两个模块复用。
- [ ] 至少覆盖 Button、Sheet、Empty/Error/Loading 三类组件。
- [ ] 不强求共享组件占比，改为记录“已消除重复 UI 模式清单”。

---

## 4. Phase 2：Mine 我的模块治理

**目标**: 降低 Mine 模块复杂度，优先稳定私有书源、高级主题、会员/外观相关链路。  
**建议周期**: 2 周起，按子模块拆票。  
**负责人建议**: 1 人主导架构拆分，1 人负责 UI 组件迁移和测试。

### 子阶段 A：私有书源页面

- [ ] 梳理 `private_book_sources_page.dart` 当前职责：列表、分组、搜索、导入导出、检测状态、权限/登录态。
- [ ] 抽出列表 item、筛选/分组 header、空态/错误态、底部操作 sheet。
- [ ] 抽出 source/group view model 或 presenter，避免 UI 直接拼状态。
- [ ] 补齐未登录态、检测失败标签、私人/共享标签、分组名称展示测试。
- [ ] 检查导入导出是否挂到私人源，不应误写共享池。

### 子阶段 B：高级主题

- [ ] 拆 `advanced_theme_service.dart`：导入解析、资源索引、校验、应用、预览分开。
- [ ] 拆 `advanced_theme_editor_page.dart`：资源列表、整体预览、底栏图集、封面/启动图集、背景图分别成组件。
- [ ] 修正资源标签：默认/当前主题/高级主题引用资源要有清晰标识。
- [ ] 处理会员到期恢复默认主题、高级主题 loading 卡住等回归点。
- [ ] 补测试：主题包解析、资源缩略图构建、会员状态变更、应用/撤销。

### 子阶段 C：会员/外观/我的页

- [ ] 统一会员入口 bottom sheet 安全区和底部导航遮挡策略。
- [ ] 外观页面标题、底部菜单默认项、字体设置入口等 UI 细节收口。
- [ ] 将 Mine 页面重复卡片/section 迁移到 Design System 或 Mine 内部组件。

### 验收

- [ ] `flutter analyze` 通过。
- [ ] 私有书源和高级主题至少覆盖核心 presenter/service tests。
- [ ] Android 真机 smoke：未登录、登录、会员有效、会员过期、导入主题、应用主题、私有书源增删改查。
- [ ] 不改 Go/Rust 权限边界：书源生态归 Rust，用户/会员/额度归 Go。

---

## 5. Phase 3：Bookshelf 书架治理

**目标**: 拆分书架 God Class，降低删除/更多弹窗/列表渲染等高频入口风险。  
**建议周期**: 1-2 周  
**负责人建议**: 熟悉书架交互的同学负责，Reader 同学只参与阅读入口联调。

### 任务

- [ ] 梳理 `bookshelf_page.dart` 职责：书籍列表、分组/排序、更多操作、删除确认、导入、本地书籍状态。
- [ ] 抽书籍卡片组件：移动端更多按钮可改为竖向 more icon，保留桌面适配。
- [ ] 抽书籍更多 bottom sheet，并统一安全区，解决被底部导航遮挡的问题。
- [ ] 抽排序/筛选/分组 header presenter。
- [ ] 本地书籍详情页检查：避免不必要网络请求，优先走本地缓存/本地 repository。
- [ ] 列表懒加载和图片加载策略检查，避免大量书籍时一次性构建。

### 验收

- [ ] 删除书籍、更多操作、进入详情、进入阅读器不回归。
- [ ] Android/iOS 底部弹窗不被底部导航栏遮挡。
- [ ] 大量书籍列表滚动无明显卡顿。
- [ ] 相关组件有 widget smoke test。

---

## 6. Phase 4：Book/Search 关键链路治理

**目标**: 让详情和搜索链路更稳定，减少大页面继续扩张。  
**建议周期**: 1-2 周，可穿插进行。

### Book 详情

- [ ] 拆 `book_detail_page.dart`：头图/信息、目录、书源状态、操作区、错误态。
- [ ] 本地书籍详情页优先本地数据，避免每次进入都走不必要请求。
- [ ] 统一详情页错误/空态/loading，接 Design System。
- [ ] 补测试：本地书、在线书、目录失败、书源切换入口。

### Search 搜索

- [ ] 检查搜索防抖/取消/并发控制。
- [ ] 搜索结果 item、失败标签、书源范围选择迁移成组件。
- [ ] 搜索范围页面改成懒加载列表，显示私人/共享、分组名、检测失败标签。
- [ ] 补测试：搜索取消、失败源展示、范围筛选、登录态。

### 验收

- [ ] 搜索和详情核心链路无回归。
- [ ] 搜索范围不会一次性加载所有源。
- [ ] 失败源不隐藏，只展示明确失败标签。

---

## 7. Phase 5：UX 动画、响应式、性能组件

**目标**: 在核心稳定后提升产品质感，不追求堆动画数量。  
**建议周期**: 1-2 周起，按关键路径拆票。

### Hero 和页面转场

- [ ] 覆盖关键路径：书架封面到详情、搜索结果到详情、详情到阅读器。
- [ ] 统一 hero tag 生成规则，避免本地书/在线书/tag 冲突。
- [ ] 只在 3-5 条关键路径做高质量动画，不追求 50+ 处数量。

### 响应式

- [ ] 整理 breakpoints，与现有 `AppAdaptiveMetrics` 兼容。
- [ ] 明确 mobile/tablet/desktop 的 sheet 最大宽度、列表列数、详情页布局。
- [ ] 补桌面窗口尺寸变化 smoke。

### 性能组件

- [ ] 统一图片加载占位、错误态、缓存策略。
- [ ] 建立 Skeleton/Loading 基础组件。
- [ ] 检查长列表是否使用懒加载或分页。

### 验收

- [ ] 关键路径动画不会造成 jank。
- [ ] 平板/桌面布局不出现明显拉伸或遮挡。
- [ ] 图片和长列表加载体验一致。

---

## 8. 派发建议

### 可并行任务

- [ ] Design System tokens/基础组件可与当前 Reader 收口并行，但不要迁移 Reader 页面或改 Reader 核心文件。
- [ ] Mine 私有书源和高级主题可以拆成两组，但需统一登录/会员/权限边界。
- [ ] Bookshelf 卡片/弹窗拆分可与 Mine 并行，但不要同时改阅读入口协议。

### 不建议并行任务

- [ ] Reader 核心翻页、书源切换、阅读进度、设置页核心不要多人同时改。
- [ ] 派发任务不要修改 `lib/features/reader/presentation/reader_page.dart` 和 reader page `part` 文件。
- [ ] 高级主题 service 和高级主题 editor 不要分离到完全无沟通的两个人，资源模型要统一。
- [ ] Design System 基础组件未稳定前，不要让所有 feature 同时迁移。

---

## 9. 每阶段通用 Definition of Done

- [ ] `flutter analyze` 通过。
- [ ] 相关单元/widget tests 通过。
- [ ] 关键路径真机 smoke 记录完成，Android 必测，iOS/桌面按影响面补测。
- [ ] 文档更新：任务完成项打勾，未完成项保留未勾选并说明原因。
- [ ] 不留无用旧接口、死代码、未使用组件。
- [ ] 不把本阶段之外的大重构混入 PR。

---

## 10. 推荐排期

### Week 1

- [ ] 当前 Reader 负责人按计划三完成 Reader 阶段1收口，其他人不领取 Reader 任务。
- [ ] 建立 Design System tokens 和最小基础组件。
- [ ] Reader Android 真机完整 smoke 由当前 Reader 负责人执行。

### Week 2

- [ ] 启动 Mine 私有书源和高级主题拆分。
- [ ] Design System 试点迁移到 Mine/Bookshelf 的一个低风险页面。

### Week 3

- [ ] Bookshelf 书籍卡片、更多弹窗、删除弹窗拆分。
- [ ] Book/Search 做关键链路梳理和低风险组件拆分。

### Week 4+

- [ ] 根据回归情况继续 Mine/Bookshelf 深拆。
- [ ] 做 Hero 关键路径、响应式、性能组件。

---

## 11. 风险提示

- [ ] 当前综合评估里的部分行数是旧快照，执行前以 `wc -l` 和实际文件为准。
- [ ] Mine 和 Bookshelf 都是高频入口，大拆前必须先补 smoke 清单。
- [ ] 设计系统收益很大，但过早全量迁移会制造更大风险。
- [ ] UI/UX 动画应先覆盖关键路径，过多动画会增加维护和性能风险。
- [ ] 平台桥接不能简单移除，应先 facade 化再考虑替换实现。
