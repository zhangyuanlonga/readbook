# 书源登录态设计梳理与迁移方案

用途：梳理 `legado-with-MD3-main` 中书源登录态的设计思路，并给当前项目定义一版可落地的“书源登录态子系统”方案，服务于晋江、晴天聚合、云端聚合等高复杂度源的迁移。

## 1. 背景

当前项目已经具备：

- `ctx.http.request`
- `ctx.cookie`
- `ctx.cache`
- `ctx.session`
- `ctx.browser`
- `ctx.crypto`

这些能力足以覆盖大多数“站点直采型”源。

但对 `docs/js/【书源】晋江...json`、`docs/js/安卓阅读书源-晴天聚合...json`、`docs/js/☁️云端聚合...json` 这类“阅读 3.0 高级源”，问题已经不是抓取能力，而是缺少一整套“登录态 + 交互状态 + 源变量”的运行时支撑。

这些源在阅读里并不是简单地“登录一次”，而是把登录态作为整个源能力的入口：

- 登录后目录行为变化
- 登录后正文行为变化
- 登录后发现页可用能力变化
- 登录后收藏/书架/购买等操作可用
- 登录面板本身就是一个“源控制台”

因此，迁移这些源时，必须先梳理阅读 3.0 的登录态设计。

## 2. 阅读 MD3 的设计思路

### 2.1 三层模型

阅读 MD3 中，书源登录态不是单个字段，而是三层结构：

1. `loginUi`
2. `loginUrl`
3. 登录相关持久化状态

其中：

- `loginUi`：描述“登录面板长什么样”
- `loginUrl`：描述“点击确认或按钮后执行什么逻辑”
- 持久化状态：保存 token、header、源变量、登录表单值等

### 2.2 `loginUi` 的职责

源码参考：

- [BaseSource.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/BaseSource.kt:187>)
- [SourceLoginDialog.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/login/SourceLoginDialog.kt:90>)

`loginUi` 在阅读里可以是：

- 直接 JSON
- `@js:` 脚本
- `<js>...</js>` 脚本

执行后得到一组 `RowUi`，再由宿主渲染成：

- 文本框
- 密码框
- 下拉框
- 按钮
- 切换项

它本质上是“源自定义表单 DSL”。

### 2.3 `loginUrl` 的职责

源码参考：

- [BaseSource.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/BaseSource.kt:73>)

`loginUrl` 在阅读里不只是 URL：

- 可以是普通 URL
- 也可以是一段 JS

阅读会把它处理成 `loginJs`，然后默认调用：

```js
if(typeof login=='function'){
    login.apply(this);
}
```

也就是说，`loginUrl` 更准确的语义是：

**登录入口脚本**

而不是简单的网页登录地址。

### 2.4 登录持久化状态

源码参考：

- 登录头：[BaseSource.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/BaseSource.kt:139>)
- 登录表单值：[BaseSource.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/BaseSource.kt:165>)
- 源变量：[BaseSource.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/BaseSource.kt:242>)
- 书级变量：[BaseBook.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/BaseBook.kt:19>)

阅读里与登录直接相关的状态有：

- `loginHeader`
  - 典型内容：token、Cookie、API key
  - 会在请求时自动附加

- `loginInfo`
  - 来自登录表单输入
  - 如账号、密码、验证码、用户自定义配置

- `sourceVariable`
  - 源级自定义变量
  - 常用于发现页筛选、服务端地址、全局开关、排序配置

- `book custom variable`
  - 书级变量
  - 常用于正文行为、章节购买开关、段评参数等

### 2.5 JS 扩展能力

源码参考：

- [JsExtensions.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/JsExtensions.kt:342>)

登录相关脚本在阅读里常用这些宿主交互：

- `toast`
- `longToast`
- `startBrowserAwait`
- `getVerificationCode`

这些能力让书源脚本不仅能“请求网络”，还可以：

- 拉起一个中间浏览器页等待扫码确认
- 弹提示
- 识别验证码图

### 2.6 UI 入口为什么很多

源码参考：

- 书籍详情页：[BookInfoActivity.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/info/BookInfoActivity.kt:244>)
- 阅读页菜单：[ReadMenu.kt](</Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt:436>)

只要源声明了 `loginUrl`，阅读就在多个场景暴露登录入口。

原因不是“登录高频”，而是：

**登录态会影响整条源链路的行为。**

## 3. 这套设计在样本源中的实际作用

### 3.1 晋江

`docs/js/【书源】晋江...json`

登录体系作用：

- 扫码登录
- 抓包 token 登录
- 账号密码登录
- 手机/邮箱验证码登录
- 书架管理
- 分类/标签/作者列表配置
- 目录登录增强
- VIP 正文
- 购买章节
- 充值入口

结论：

**登录面板本身就是一个源控制台。**

### 3.2 晴天聚合

`docs/js/安卓阅读书源-晴天聚合...json`

登录体系作用：

- 聚合服务登录
- 子源（如番茄）附加 token
- 服务端地址与参数配置
- 正文模式切换
- 发现页行为控制

结论：

**登录态是聚合后端访问能力的一部分。**

### 3.3 云端聚合

`docs/js/☁️云端聚合...json`

登录体系作用：

- 云端服务 API key / token
- 个性化配置
- 收藏/中心页等功能
- 子源行为控制

结论：

**登录态是整个聚合源的基础设施。**

## 4. 对当前项目的影响

如果只是迁移普通网站源，当前项目能力足够。

如果要迁移上述高级源，当前缺口不是：

- HTTP 请求
- Cookie
- MD5 / DES / AES

而是：

1. 源级登录头存储
2. 登录表单值存储
3. 源级变量存储
4. 书级自定义变量存储
5. `loginUi` 渲染机制
6. `loginUrl` 执行动作入口
7. 宿主交互能力：
   - toast
   - browser await
   - verification code

## 5. 我们自己的登录态设计

目标不是 1:1 复刻阅读 MD3，而是：

**做一版足以支撑高级源迁移的最小登录子系统。**

### 5.1 设计原则

1. 只补书源迁移真正需要的能力
2. 继续以我们自己的函数式 JS 规则为主
3. 不把“阅读 JSON 运行时”整套搬进来
4. 状态与 UI 解耦
5. 所有登录相关状态都要可诊断、可清理

### 5.2 数据模型

建议引入以下概念：

#### `SourceLoginState`

- `sourceId`
- `loginHeaderJson`
- `loginInfoJson`
- `sourceVariableJson`
- `updatedAt`

职责：

- 保存源级登录头
- 保存源级表单值
- 保存源级变量

#### `BookCustomState`

- `bookId`
- `sourceId`
- `detailUrl`
- `customVariableJson`
- `updatedAt`

职责：

- 保存书级 `custom` 变量

### 5.3 JS 侧建议 API

建议在现有函数式脚本模型上，补这些宿主 API：

#### Source 级

- `ctx.sourceLogin.getHeader()`
- `ctx.sourceLogin.putHeader(jsonString)`
- `ctx.sourceLogin.removeHeader()`
- `ctx.sourceLogin.getInfo()`
- `ctx.sourceLogin.putInfo(jsonString)`
- `ctx.sourceLogin.removeInfo()`
- `ctx.sourceLogin.getVariable()`
- `ctx.sourceLogin.setVariable(value)`

#### Book 级

- `ctx.bookState.getCustom()`
- `ctx.bookState.setCustom(value)`

#### UI / 交互级

- `ctx.ui.toast(message)`
- `ctx.ui.longToast(message)`
- `ctx.ui.openBrowserAwait({ url, title, refetchAfterSuccess })`
- `ctx.ui.getVerificationCode(imageUrl)`

### 5.4 登录 UI 机制

建议先做“最小版”：

- `loginUi` 先只支持 JSON
- 支持：
  - `text`
  - `password`
  - `select`
  - `button`
- 不先支持复杂 toggle / 动态布局花样

按钮点击时：

- 执行对应 JS action
- action 可访问 `result / book / chapter / ctx.*`

### 5.5 `loginUrl` 机制

建议保留阅读的核心思路：

- `loginUrl` 可以是 JS
- 若存在 JS，则默认执行 `login()`

但不要把它和普通书源 `search/detail/...` 混在一起。

建议作为独立的：

- “登录脚本入口”

## 6. 分阶段实现建议

### 阶段 A：状态层

先补：

- 源级登录头存储
- 源级登录信息存储
- 源级变量存储
- 书级 custom 变量存储

目的：

- 让脚本可以先“有状态”
- 先不做 UI 也能支持手动 token 迁移

### 阶段 B：最小登录 UI

补：

- `loginUi` JSON 渲染
- `button` action 执行
- `toast`

目的：

- 支撑晋江、云端聚合这类源的登录面板

### 阶段 C：高级交互

补：

- `openBrowserAwait`
- `getVerificationCode`
- 更完整的 loginUi 动态执行能力

目的：

- 支持扫码登录、验证码登录

## 7. 当前建议优先级

对于当前项目，推荐顺序：

1. 阶段 A：状态层
2. 阶段 B：最小登录 UI
3. 用晋江做第一个样本验证
4. 再评估是否补阶段 C

理由：

- 晋江 / 晴天 / 云端三者的共同依赖先解决
- 风险最小
- 迁移收益最大

## 8. 非目标

本方案不包含：

- 完整复刻阅读 3.0 全部脚本 API
- 兼容所有 `java.*`
- 兼容所有 `loginUi` 高级布局语法
- 一次性支持所有高级购买/评论动作

这些可以后续按样本源需要补。

## 9. 结论

阅读 MD3 的登录态设计不是“网页登录入口”，而是一个：

**源级状态 + 表单 UI + 脚本动作 + 宿主交互 的组合子系统。**

对当前项目来说，最合理的路线不是完全照搬，而是：

1. 参考它的状态设计
2. 保留我们自己的函数式 JS 模型
3. 做一版最小但够用的登录子系统

只要先补齐：

- 源级登录头
- 登录信息
- 源变量
- 书级 custom 变量
- 最小登录面板

就已经能明显降低晋江、晴天聚合、云端聚合这类源的迁移难度。

## 10. 阶段任务

### 阶段 A：状态层

- [x] 定义 `SourceLoginState` 数据结构
- [x] 定义 `BookCustomState` 数据结构
- [x] 选择状态持久化方案（本地库 / SharedPreferences / 组合方式）
- [x] 实现源级登录头读写接口
- [x] 实现源级登录信息读写接口
- [x] 实现源级变量读写接口
- [x] 实现书级 `custom` 变量读写接口
- [x] 为状态层补最小单元测试
- [x] 为状态清理（删除书源 / 清空登录态）补回收逻辑

### 阶段 B：脚本运行时桥接

- [x] 设计 `ctx.sourceLogin.*` API 形态
- [x] 设计 `ctx.bookState.*` API 形态
- [x] 在脚本运行时注入源级登录态桥接
- [x] 在脚本运行时注入书级变量桥接
- [x] 兼容 `loginHeader` 自动并入请求头的策略
- [x] 为桥接层补运行时测试

### 阶段 C：最小登录 UI

- [x] 定义 `loginUi` 的最小支持字段范围
- [x] 实现登录表单页面或弹层容器
- [x] 支持 `text` 表单项
- [x] 支持 `password` 表单项
- [x] 支持 `select` 表单项
- [x] 支持 `button` 表单项
- [x] 实现表单值与 `loginInfo` 的双向同步
- [x] 实现确认动作触发 `loginUrl` / `login()` 的入口
- [x] 为最小登录 UI 补交互测试

### 阶段 D：宿主交互能力

- [x] 设计 `ctx.ui.toast(message)` 能力
- [x] 设计 `ctx.ui.longToast(message)` 能力
- [x] 设计 `ctx.ui.openBrowserAwait(...)` 能力
- [x] 评估 `ctx.ui.getVerificationCode(imageUrl)` 能力边界
- [x] 为宿主交互能力补错误兜底与降级提示

### 阶段 E：样本验证

- [ ] 用晋江源验证手动 token 登录链路
- [ ] 用晋江源验证登录后目录增强链路
- [ ] 用晋江源验证登录后 VIP 正文读取链路
- [ ] 用晋江源验证 `sourceVariable` / `book custom variable` 基础语义
- [ ] 用晴天聚合验证 `loginUi + loginUrl` 的动态交互能力
- [ ] 用云端聚合验证 `loginHeader / loginInfoMap` 的读写链路

### 阶段 F：清理与文档

- [ ] 补一份“脚本登录态 API 使用说明”
- [ ] 补一份“阅读 JSON 迁移到登录态能力”的映射说明
- [ ] 补一份“如何清理异常登录态缓存”的开发说明
- [ ] 根据实现结果回填本设计文档中的已完成项
