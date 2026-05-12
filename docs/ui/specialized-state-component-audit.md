# 专题状态组件审计

更新时间：2026-05-07

## 目的

通用缺省态体系已经覆盖了大部分列表页：

- `AppEmptyStateCard`
- `AppStatusStateCard`

下一阶段不建议继续把所有状态都塞进通用卡片，而是为以下 3 类高差异场景抽专题组件：

1. `membership`
2. `discover`
3. `reader`

这些页面的状态不只是“空/错”，还包含权限、能力、引导、操作上下文和专题语义。

## 1. Membership

### 当前现状

代表文件：

- `lib/features/mine/presentation/membership_center_page.dart`

已有状态特征：

- 会员未开通但可激活
- 试用中 / 正式会员 / 未登录
- 许可证设备为空
- 加载失败、激活失败、试用领取状态

典型位置：

- 会员摘要说明
- 许可证激活卡
- 设备管理卡中的空设备记录

### 为什么不适合直接用通用缺省态

- 会员状态是“权益状态”，不是普通列表空态
- 需要强调权益来源、设备上限、许可证输入、试用状态
- 同一块区域往往既要展示状态，又要给下一步动作

### 建议组件

建议抽：

- `MembershipStatusCard`
- `MembershipDeviceStateCard`

建议能力：

- 支持 `active / inactive / trial / error`
- 支持内嵌说明字段
- 支持主按钮和次按钮
- 支持设备席位摘要

### 推荐优先级

- P1

## 2. Discover

### 当前现状

代表文件：

- `lib/features/discover/presentation/discover_page.dart`

已有状态特征：

- 正在加载发现书源
- 没有支持发现的书源
- 书源存在但没有分类
- 分类存在但没有可点击项
- 当前分类暂无书籍
- 接口加载失败，但页面还保留可切换结构

### 为什么不适合直接用通用缺省态

- Discover 是多阶段流：书源 -> 分类 -> 书籍
- 同一页面不同区域可能同时处于不同状态
- 当前已经有 `RuntimeFeedbackCard` 体系，盲目替换会出现两套反馈语言冲突

### 建议组件

建议不要新起完全独立体系，而是：

- 基于现有 `RuntimeFeedbackCard`
- 补一层 `DiscoverStateCard` 包装

建议统一的状态语义：

- `loading`
- `info`
- `empty`
- `error`

建议接管的内容：

- 标题
- 说明文案
- 推荐动作按钮
- 能力计数摘要

### 推荐优先级

- P1

## 3. Reader

### 当前现状

代表文件：

- `lib/features/reader/presentation/reader_viewport_builder.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`
- `lib/features/reader/presentation/reader_text_scroll_view.dart`
- `lib/features/reader/presentation/reader_manga_view.dart`

已有状态特征：

- 正文加载失败
- 暂无正文
- 当前章节暂无漫画内容
- 当前章节暂无可分页内容
- 本地内容可复制诊断信息
- 可切换书源 / 可重试 / 可下拉刷新

### 为什么不适合直接用通用缺省态

- Reader 状态与正文区域布局、阅读交互、换源按钮强绑定
- 状态卡可能出现在正文容器内部，不一定是“页面卡片”
- 不同内容模式（正文 / 分页 / 漫画）共用一套交互语义，但视觉容器不同

### 建议组件

建议抽：

- `ReaderContentStateCard`

建议输入：

- `title`
- `message`
- `icon`
- `actions`
- `mode`：`empty / error / loading / diagnostic`

建议目标：

- 保留 ReaderBodyRegion 的承载方式
- 统一动作按钮排序和间距
- 统一图标和标题层级

### 推荐优先级

- P1

## 推荐推进顺序

1. `DiscoverStateCard`
原因：当前已有 `RuntimeFeedbackCard`，补包装最轻，收益高。

2. `MembershipStatusCard`
原因：业务状态复杂，但都集中在一个页面，收口快。

3. `ReaderContentStateCard`
原因：价值很高，但需要谨慎，不宜在没有交互回归的情况下大改。

## 组件边界规则

- 通用列表页状态：
  用 `AppEmptyStateCard` / `AppStatusStateCard`

- 专题页面状态：
  用“专题包装组件”，底层仍复用通用体系或现有反馈体系

- 不建议：
  让 `AppEmptyStateCard` 继续无限膨胀成会员/发现/阅读万能组件

## 结论

当前项目的缺省态体系已经完成“通用列表页”统一。

下一阶段最合理的路线不是继续扩通用卡片，而是进入“专题状态组件化”：

- Membership：权益状态
- Discover：多阶段反馈
- Reader：内容区域状态
