# MD3 `loginUi` 阶段 1 现状盘点

更新时间：2026-04-30  
用途：作为 `docs/md3_login_feature_execution_plan.md` 阶段 1 的正式产出，固定当前项目 `loginUi` 能力边界、与 MD3 的差异、可直接复用部分、后续阶段缺口。

关联文件：

- `lib/runtime/sources/source_script_compiler.dart`
- `lib/features/source/application/source_login_runtime_service.dart`
- `lib/features/source/presentation/source_login_page.dart`
- `test/features/source/presentation/source_login_page_test.dart`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/login/SourceLoginDialog.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/assets/web/help/md/ruleHelp.md`

---

## 1. 结论先行

当前项目已经具备一版可工作的 Flutter `loginUi` 动态表单骨架，不需要在阶段 1 重做。

阶段 1 的最终判断：

- `loginUi` 主体能力已具备
- 当前最大缺口不是 `loginUi`，而是纯 `loginUrl` 网页登录模式
- `loginUi` 剩余差距主要集中在：
  - 视觉与交互细节等价性
  - 更完整的布局语义
  - MD3 风格的运行时 UI 重绘与数据回推

因此后续优先级应保持为：

1. 先做阶段 2：纯 `loginUrl` 网页登录模式
2. 再做阶段 3：`loginCheckJs`
3. 最后再做 `loginUi` 细节补齐

---

## 2. 当前项目 `loginUi` 入口形态

当前项目运行时会把以下能力都视为“支持登录”：

- `login`
- `loginUi`
- `loginUrl`

对应源码：

- `supportsLogin`：`source_script_compiler.dart:150-153`
- `loginUi` 运行入口：`source_script_compiler.dart:154-167`
- `loginAction` / `loginUrl` 运行入口：`source_script_compiler.dart:168-178`
- `loginUrl` 作为脚本或原始值执行：`source_script_compiler.dart:1373-1387`

当前项目的 `loginUi` 可以来自：

- 直接数组结果
- JSON 字符串
- `loginUi` 函数
- `loginUi` 脚本属性

当前 MD3 的成熟模式是：

- 有 `loginUi` 时走 `SourceLoginDialog`
- 无 `loginUi` 时直接走 `WebViewLoginFragment`

对应源码：

- `SourceLoginActivity.kt:27-34`
- `WebViewLoginFragment.kt:146-149`

阶段 1 判断：

- 当前项目 `loginUi` 本身不是空白状态
- 当前项目的真正缺口是“`supportsLogin` 为 true，但没有 `loginUi` 时仍落回空面板错误”

---

## 3. UI 字段类型矩阵

| 能力 | MD3 | 当前项目 | 阶段 1 结论 |
| --- | --- | --- | --- |
| `text` | 支持 | 已支持 | 可直接复用 |
| `password` | 支持 | 已支持 | 可直接复用 |
| `select` | 支持 | 已支持 | 可直接复用 |
| `button` | 支持 | 已支持 | 可直接复用 |
| `toggle` | 支持 | 已支持 | 语义已通，交互样式不等价 |
| `textarea` | 无专门类型，常靠 `text` 扩展 | 已支持 | 为项目自增能力，不是 MD3 阻塞项 |
| `note` | MD3 常用按钮伪装说明项 | 已支持 | 为项目自增能力，可保留 |
| `divider` | MD3 无独立原生类型 | 已支持 | 为项目自增能力，可保留 |

当前项目字段解析入口：

- 字段类型定义：`source_login_runtime_service.dart:10-19`
- 字段解析：`source_login_runtime_service.dart:262-349`
- 页面渲染：`source_login_page.dart:617-679`

阶段 1 判断：

- `text/password/select/button/toggle` 已形成最小稳定集合
- `textarea/note/divider` 不需要回退删除，可以作为当前项目对 MD3 的增强保留

---

## 4. 字段动作语义矩阵

| 能力 | MD3 | 当前项目 | 阶段 1 结论 |
| --- | --- | --- | --- |
| 输入框失焦触发 `action` | 支持 | 已支持 | 主语义可复用 |
| `select` 切换触发 `action` | 支持 | 已支持 | 主语义可复用 |
| `toggle` 触发 `action` | 支持 | 已支持 | 主语义可复用，表现形式不同 |
| 按钮点击执行 JS | 支持 | 已支持 | 可直接复用 |
| 按钮长按执行 JS | 支持 | 已支持 | 可直接复用 |
| 按钮 action 为绝对 URL | 支持 | 已支持 | 行为可用，但打开方式与 MD3 不完全一致 |
| action 返回 message | 支持 | 已支持 | 可直接复用 |
| action 返回 form patch | 支持 | 已支持 | 可直接复用 |

当前项目关键实现：

- `submit()`：`source_login_runtime_service.dart:174-233`
- 绝对 URL action：`source_login_runtime_service.dart:188-196`
- 输入框失焦提交：`source_login_page.dart:972-1000`
- `select` 触发 action：`source_login_page.dart:651-674`
- `toggle` 触发 action：`source_login_page.dart:848-937`
- 按钮点击 / 长按：`source_login_page.dart:939-970`

与 MD3 的主要差异：

- MD3 文本输入 action 更偏“字段级 JS 回调 + 根据返回值决定是否接受改动”
- 当前项目更偏“字段变更后统一 submit，再通过 patch/message 回推”
- MD3 的绝对 URL 按钮更偏直接打开 URL
- 当前项目的绝对 URL action 统一走 `openBrowserAwait`

阶段 1 判断：

- 主动作语义已能支撑多数 MD3 风格登录控制台
- 不需要在本阶段重做 action 模型
- “绝对 URL 的打开方式是否要和 MD3 更严格等价”属于后续微调项，不阻塞阶段 2

---

## 5. 布局与展示语义矩阵

| 能力 | MD3 | 当前项目 | 阶段 1 结论 |
| --- | --- | --- | --- |
| `layout_flexBasisPercent` | 支持 | 已支持 | 当前最稳定可复用布局语义 |
| `layout_flexGrow` | 支持 | 仅解析未真正参与布局 | 部分支持 |
| `layout_justifySelf` | 支持 | 已支持基础左/中/右 | 部分支持 |
| `viewName` 静态文本 | 支持 | 已支持 | 可直接复用 |
| `viewName` 动态 JS | 支持 | 已支持 | 可直接复用 |
| 登录页运行后重绘 UI | 支持 | 仅在 submit 后 reload | 部分支持 |

当前项目关键实现：

- 样式解析：`source_login_runtime_service.dart:420-464`
- 宽度计算：`source_login_page.dart:748-759`
- 对齐计算：`source_login_page.dart:761-772`
- 动态标签解析：`source_login_runtime_service.dart:352-418`

当前明确缺口：

- `layout_flexGrow` 已解析但当前布局宽度计算未真正消费
- MD3 文档里还存在 `layout_flexShrink / layout_alignSelf / layout_wrapBefore`
  - 当前项目未接入
- 当前项目 `toggle` 使用分段按钮式布局
  - MD3 是“文本 + 当前值”循环切换样式
- 当前项目 `text/password` 更偏 Material 输入框
  - MD3 更偏 hint 驱动的输入项样式

阶段 1 判断：

- 当前布局语义足够支撑绝大多数样本源的基础排布
- 不需要在阶段 1 为了样式等价重做登录页布局系统

---

## 6. 状态与页面生命周期差异

这一部分是当前项目和 MD3 差异最明显的区域之一。

### 6.1 当前项目已具备

- 表单加载时读取持久化 `loginInfo`
- action 后回填 patch
- submit 后重新加载 `presentation`
- 支持浏览器回调、验证码、toast、confirm、prompt

### 6.2 当前项目与 MD3 的关键差异

#### 差异 A：未提交编辑的持久化时机不同

MD3：

- 用户关闭面板时，如果有变更，会把 `loginInfo` 保存回去

当前项目：

- 只有 submit / action 执行时才会稳定回写
- 单纯输入后直接关闭页面，不保证保存

#### 差异 B：缺少 MD3 式的 UI 主动回推接口

MD3：

- `upLoginData(data)`
- `reLoginView()`

可以在脚本运行过程中主动要求宿主更新 UI 或整页重绘。

当前项目：

- 主要依赖 action 返回 `message / patch / reload`
- 没有显式的“脚本主动要求 UI 刷新”接口

#### 差异 C：缺少 MD3 登录页工具菜单

MD3 工具栏支持：

- 查看登录头
- 清空登录头
- 查看日志

当前项目：

- `SourceLoginPage` 只有确认动作
- 登录专题工具能力应放到后续阶段 5 处理

阶段 1 判断：

- 这些差异真实存在
- 但它们不构成当前阶段必须返工 `loginUi` 页面主体的理由
- 更适合作为阶段 4 / 阶段 5 的补强目标

---

## 7. 当前可直接复用的 `loginUi` 能力

后续阶段可直接复用，不建议重做：

- `SourceLoginRuntimeService` 的字段解析与 action 主链路
- `SourceLoginPage` 的动态字段渲染框架
- `SourceUiContext` 驱动的宿主交互桥
- `formPatch + message + reload` 的表单更新闭环
- `viewName` 静态 / 动态标签解析机制
- `text/password/select/button/toggle` 基础字段集

这意味着：

- 阶段 2 不需要推翻现有 `SourceLoginPage`
- 阶段 3 不需要重新设计 `loginUi` 编译入口
- 阶段 4 主要是补宿主能力和行为细节

---

## 8. 当前明确不需要在阶段 1 重做的区域

- 不重写 `SourceLoginPage` 为 Android 式对话框 UI
- 不删掉 `textarea / note / divider`
- 不为了 `toggle` 视觉等价而现在重做交互模型
- 不现在引入整套结构化编辑器
- 不把 `loginUi` 的所有细节差距提前到阶段 2 前解决

阶段 1 的原则是：

- 先冻结边界
- 不做风格性返工
- 把真实阻塞项留给更高优先级阶段

---

## 9. 当前明确留到后续阶段的缺口

### 阶段 2

- 纯 `loginUrl` 网页登录模式补齐

### 阶段 3

- `loginCheckJs` 正式运行时落点

### 阶段 4

- 宿主交互等价性校正
- 更完整布局语义
- 更细的 `toggle` 行为 / 视觉等价
- `startBrowserAwait(html)` 语义校正

### 阶段 5

- 登录页工具菜单
- 登录态查看 / 清理
- `loginUi` 预览与登录调试体验

---

## 10. 测试现状

当前已有测试：

- `test/features/source/presentation/source_login_page_test.dart`

当前覆盖到的点：

- `text`
- `password`
- `select`
- `toggle`
- `button`
- 表单 submit

当前未覆盖的高价值点：

- `textarea`
- `note`
- `divider`
- 动态 `viewName`
- 输入框失焦 action
- 按钮长按
- 绝对 URL action
- action patch 回填

阶段 1 判断：

- 当前 `loginUi` 不是“完全没测”
- 但后续阶段仍需补更细的 widget / runtime 测试

---

## 11. 阶段 1 完成结论

阶段 1 已完成以下目标：

- 明确了当前 `loginUi` 支持矩阵
- 明确了当前 `action` 支持矩阵
- 明确了当前布局语义支持矩阵
- 明确了 `viewName` 与动态标签现状
- 明确了当前登录页与 MD3 对话框交互的主要差异
- 明确了哪些能力可以直接复用
- 明确了哪些区域本阶段不需要重做
- 明确了需要留到后续阶段处理的缺口

阶段 1 的最终结论只有一句话：

**当前项目的 `loginUi` 已经具备继续演进的骨架，不需要重做；下一步应直接进入纯 `loginUrl` 网页登录模式补齐。**
