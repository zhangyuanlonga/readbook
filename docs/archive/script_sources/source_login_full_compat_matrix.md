# 书源登录子系统完整兼容矩阵

用途：一次性梳理当前项目与阅读 MD3 登录子系统之间的兼容范围，结合高级样本源：

- `晋江`
- `晴天聚合`
- `云端聚合`

给出：

- 已支持
- 部分支持
- 未支持
- 是否高频
- 建议优先级

状态说明：

- `已支持`：当前项目已具备稳定能力
- `部分支持`：已有基础实现，但与 MD3 仍有明显差异
- `未支持`：当前没有，或只靠源侧绕不过去

---

## 1. UI 字段类型矩阵

| 能力 | MD3 | 当前项目 | 样本使用情况 | 备注 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| `text` | 支持 | 已支持 | 晋江 / 晴天 / 云端 | 常规输入框 | P0 |
| `password` | 支持 | 已支持 | 晋江 / 晴天 / 云端 | 密码、token、密钥 | P0 |
| `select` | 支持 | 已支持 | 晋江 / 晴天 / 云端 | 下拉选项 | P0 |
| `button` | 支持 | 已支持 | 晋江 / 晴天 / 云端 | 按钮动作 | P0 |
| `toggle` | 支持 | 已支持 | 晋江 / 晴天 / 云端 | 当前为基础版，细节未完全等价 | P0 |
| 多行输入 `textarea` | 无专门类型，常靠 text 扩展 | 已支持 | 晴天 / 云端有潜在需求 | 已作为我们自增组件提供 | P1 |
| 纯说明文字 / 分隔组件 | 常用 button 假装 | 已支持 | 三个样本都大量使用 | 已支持 `note / divider` | P1 |

---

## 2. 字段动作语义矩阵

| 能力 | MD3 | 当前项目 | 样本使用情况 | 备注 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| 输入框失焦触发 `action` | 支持 | 已支持 | 云端常见 | `text/password` 已补 | P0 |
| `select` 切换触发 `action` | 支持 | 已支持 | 晴天 / 云端常见 | 已补 | P0 |
| `toggle` 点击触发 `action` | 支持 | 已支持 | 晴天 / 云端常见 | 已补基础语义 | P0 |
| 按钮点击执行 JS | 支持 | 已支持 | 三个样本都有 | 已支持 | P0 |
| 按钮长按执行 JS | 支持 | 已支持 | 样本里存在潜在依赖 | 已支持 | P0 |
| 按钮 action 为绝对 URL | 支持 | 已支持 | 晴天 / 云端常见 | 已补 | P0 |
| action 返回表单 patch | 支持 | 已支持 | 控制台类源高频 | 已补 map/json patch | P0 |
| action 只返回 message | 支持 | 已支持 | 三个样本都有 | 已补 | P0 |

---

## 3. 布局 / 展示语义矩阵

| 能力 | MD3 | 当前项目 | 样本使用情况 | 备注 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| `layout_flexGrow` | 支持 | 部分支持 | 三个样本都有 | 当前主要吃 `basis`，`grow` 影响有限 | P1 |
| `layout_flexBasisPercent` | 支持 | 已支持 | 三个样本都有 | 已用于分栏排布 | P0 |
| `layout_justifySelf` | 支持 | 部分支持 | 三个样本都有 | 已支持左/中/右对齐的基础版 | P1 |
| `viewName` 静态别名 | 支持 | 已支持 | 三个样本都有 | 已支持固定别名 | P0 |
| `viewName` 动态 JS 求值 | 支持 | 已支持 | MD3 常见 | 已支持动态求值并回填标题 | P0 |
| 登录页运行后重绘 UI | 支持 | 部分支持 | 三个样本都依赖 | 当前 submit 后会 reload，但未完全等价 | P1 |

---

## 4. 状态存储矩阵

| 能力 | MD3 | 当前项目 | 样本使用情况 | 备注 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| `loginInfo` | 支持 | 已支持 | 三个样本都有 | 已持久化 | P0 |
| `loginHeader` | 支持 | 已支持 | 晋江 / 云端高频 | 已持久化并自动并入请求 | P0 |
| `sourceVariable` | 支持 | 已支持 | 三个样本都有 | 已持久化 | P0 |
| `book custom variable` | 支持 | 已支持 | 晋江 / 晴天 / 云端 | 已支持 `ctx.bookState.*` | P0 |
| 变量 patch 写法 | 间接支持 | 已支持 | 控制台源高频 | 已支持 `patchInfo / patchVariable / patchCustom` | P0 |
| 通用 `putVariable(key, value)` | 支持 | 已支持 | 云端更常见 | 已支持 key/value 风格写法 | P0 |

---

## 5. 宿主交互矩阵

| 能力 | MD3 | 当前项目 | 样本使用情况 | 备注 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| `toast` | 支持 | 已支持 | 三个样本都有 | 已补 | P0 |
| `longToast` | 支持 | 已支持 | 三个样本都有 | 已补 | P0 |
| `startBrowserAwait(url,title,refetchAfterSuccess)` | 支持 | 已支持 | 三个样本都有 | 已补基础版 | P0 |
| `startBrowserAwait(..., html)` | 支持 | 部分支持 | 晋江 / 晴天会用 | 当前兼容 `data:text/html`，未显式开放 html 参数 | P1 |
| `getVerificationCode` | 支持 | 已支持 | 晋江常用 | 已补手动输入版 | P0 |
| `openUrl` | 支持 | 已支持 | 晴天 / 云端常见 | 已显式提供 `ctx.ui.openUrl(...)` | P0 |
| `confirm` | 常见 | 已支持 | 清空设置、退出登录常用 | 已支持 `ctx.ui.confirm(...)` | P0 |
| `prompt` | 常见 | 已支持 | 临时输入场景常见 | 已支持 `ctx.ui.prompt(...)` | P0 |
| `alert` | 常见 | 未支持 | 提示类按钮常见 | 建议补 | P2 |

---

## 6. 样本源高频依赖交集

### 晋江

高频依赖：

- `button`
- `toggle`
- `password`
- `text`
- `select`
- `getLoginInfoMap`
- `getLoginHeader / putLoginHeader`
- `source.getVariable / setVariable`
- `book.getVariable('custom')`
- `startBrowserAwait`
- `getVerificationCode`
- `toast / longToast`

当前结论：

- 手动 token 链路已可用
- 扫码 / 账号密码 / 验证码链路仍依赖更完整 UI 交互

### 晴天聚合

高频依赖：

- 大量 `button`
- `select`
- `toggle`
- `source.getVariable / setVariable`
- `getLoginInfoMap`
- `startBrowserAwait`
- 控制台式布局样式

当前结论：

- 主链路登录/搜索/发现/详情/目录/正文已能起步
- 控制台按钮群和联动设置仍有缺口

### 云端聚合

高频依赖：

- `text/password/select/button/toggle`
- `getLoginInfoMap`
- `getLoginHeader / putLoginHeader`
- `source.getVariable / setVariable`
- `book.getVariable / putVariable`
- `startBrowserAwait`
- `toast / longToast`
- `viewName`

当前结论：

- 它对“动态登录控制台”要求最高
- 是最能检验登录子系统是否完整的样本

---

## 7. 当前项目总体结论

### 已完成的核心骨架

当前已经具备：

- 源登录态持久化
- 书级 custom 持久化
- 登录页最小闭环
- `text/password/select/button/toggle`
- 字段 action
- URL action
- action patch 回填
- `toast / longToast / openBrowserAwait / getVerificationCode`
- 控制台式基础布局

这意味着：

**高级源迁移已经不再缺“登录子系统骨架”。**

### 仍值得继续补的高频通用能力

按优先级建议：

#### P1

- `startBrowserAwait(html)` 显式参数化
- `label / note / divider` 这类静态展示组件

#### P2

- `textarea`
- `ctx.ui.alert(...)`
- 更完整的 `toggle` 视觉和行为等价
- 更细的布局样式语义

---

## 8. 是否可以“一次性整理完毕”

可以。

就“兼容范围梳理”这件事来说，现在已经具备完整条件：

- 有 MD3 源码可对照
- 有晋江 / 晴天 / 云端聚合三个高级样本
- 当前项目已有一版登录子系统实现

所以后续不需要再反复靠聊天回忆：

- 哪些能力已支持
- 哪些只是部分支持
- 哪些仍然缺
- 哪些优先补最值

都可以以这份文档为基准继续推进。

---

## 9. 后续实施建议

- 第 1 步：补 `viewName` 动态求值
- 第 2 步：补 `ctx.ui.confirm / prompt / openUrl`
- 第 3 步：补 `patchInfo / patchVariable / patchCustom`
- 第 4 步：拿 `云端聚合` 做登录控制台完整性验证
