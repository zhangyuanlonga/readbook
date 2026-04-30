# MD3 登录宿主交互阶段 4 盘点

更新时间：2026-04-30  
用途：作为 `docs/md3_login_feature_execution_plan.md` 阶段 4 的正式产出，固定当前项目登录相关宿主交互的已支持范围、与 MD3 的等价程度、剩余差异和后续边界。

关联文件：

- `lib/runtime/sources/source_contract.dart`
- `lib/runtime/sources/source_script_compiler.dart`
- `lib/features/source/application/source_login_runtime_service.dart`
- `lib/features/source/presentation/source_login_page.dart`
- `test/runtime/sources/source_script_compiler_discover_test.dart`

---

## 1. 结论先行

当前项目登录专题的高频宿主交互已经形成一套稳定集合：

- `toast`
- `longToast`
- `openUrl`
- `alert`
- `confirm`
- `prompt`
- `openBrowserAwait`
- `getVerificationCode`

阶段 4 的最终判断：

- 当前项目已经具备可迁移级别的登录宿主交互基线
- 明确缺失的高频通用能力 `alert` 已补齐
- 所有登录相关宿主交互仍统一经由 `SourceUiContext` 暴露
- 当前剩余差异主要是“行为细节等价性”，不是“能力缺失”

---

## 2. 当前交互能力矩阵

| 能力 | 当前项目 | 阶段 4 判断 |
| --- | --- | --- |
| `toast` | 已支持 | 可直接复用 |
| `longToast` | 已支持 | 可直接复用 |
| `openUrl` | 已支持 | 可直接复用 |
| `alert` | 已支持 | 本阶段新增，补齐高频缺口 |
| `confirm` | 已支持 | 可直接复用 |
| `prompt` | 已支持 | 可直接复用 |
| `openBrowserAwait` | 已支持 | 主链路可复用 |
| `getVerificationCode` | 已支持 | 可直接复用 |

当前桥接入口：

- 宿主交互上下文：`source_contract.dart`
- JS bridge 注册：`source_script_compiler.dart`
- Flutter 侧具体弹窗实现：`source_login_page.dart`

---

## 3. 本阶段新增能力

### 3.1 `ctx.ui.alert(...)`

本阶段新增：

- `SourceUiContext.alert(...)`
- JS bridge `__ctx_ui_alert`
- JS helper `ctx.ui.alert(...)`
- Flutter 登录页内的最小 alert 对话框实现

支持调用形式：

```js
await ctx.ui.alert('提示内容');

await ctx.ui.alert({
  message: '提示内容',
  title: '提示',
  confirmText: '知道了',
});
```

当前默认行为：

- 标题默认：`提示`
- 确认按钮默认：`知道了`

---

## 4. 当前与 MD3 的等价程度

### 4.1 已基本等价

- `toast`
- `longToast`
- `openUrl`
- `confirm`
- `prompt`
- `getVerificationCode`

这些能力在当前项目里已经不是“占位接口”，而是可被登录脚本稳定消费的正式能力。

### 4.2 主语义已等价，但行为细节仍有差异

#### `openBrowserAwait`

当前项目：

- 支持 `url / title / refetchAfterSuccess / html`
- 返回值是统一 payload
- 可配合 cookie 同步与网页登录链路一起工作

与 MD3 的差异：

- 没有完整复刻 MD3 某些浏览器承载形式与页面配置项
- 但对登录专题主链路来说已可用

#### `alert`

当前项目：

- 以标准 `AlertDialog` 呈现
- 只有单确认按钮

与 MD3 的差异：

- 没有复刻 MD3 里其他页面上可能出现的更复杂弹层形式
- 但作为登录脚本的通用提示能力已经足够

---

## 5. 仍保留的差异

这些差异在当前阶段不作为阻塞项：

- `openBrowserAwait` 的承载形式和 MD3 不完全等价
- `alert / confirm / prompt` 的视觉样式仍是 Flutter Material 口径
- 某些脚本里若依赖更重的原生页面配置，当前仍不会 1:1 复刻

阶段 4 的原则是：

- 优先补“能力缺失”
- 不为视觉或平台细节等价而重做整套宿主 UI 基础设施

---

## 6. 当前统一暴露口径

当前登录专题宿主交互继续统一通过 `SourceUiContext` 暴露，不允许绕开：

- 页面层负责提供具体实现
- runtime / compiler 只负责编译和转发
- 登录脚本只依赖 `ctx.ui.*`

这保证了：

- 能力边界清晰
- 实现不散落
- 后续可继续替换 Flutter 侧表现层，而不破坏脚本 API

---

## 7. 阶段 4 完成结论

阶段 4 已完成：

- 梳理当前项目已支持的登录宿主交互集合
- 对照 MD3 明确哪些已等价、哪些只是基础版
- 补齐高频缺失交互 `alert`
- 继续保持所有交互经由 `SourceUiContext` 暴露
- 用 runtime 回归测试固定 `ctx.ui.alert(...)` 链路

阶段 4 的最终结论：

**当前项目的登录宿主交互已经达到 MD3 登录能力迁移所需的最小稳定集合，后续重点应转向真实样本源验证与编写调试体验。**
