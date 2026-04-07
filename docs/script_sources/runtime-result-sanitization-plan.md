# 脚本源返回值安全收口方案

更新时间：2026-04-06

当前说明：

- 本文只讨论脚本源运行时从 JS 返回结果到 Dart 宿主之间的安全收口问题。
- 范围覆盖所有在线书源主链返回值：
  - `search`
  - `discoverCategories`
  - `discoverBooks`
  - `detail`
  - `chapters`
  - `content`
  - 以及以上能力在书架后台刷新、换源、检测等场景中的复用调用
- 本文不讨论旧规则 JSON、Legado 执行链，也不讨论页面级 UI 交互。

## 0. 结论先行

当前项目已经对脚本源返回结果做了“业务模型校验”，但还缺少一层“运行时安全校验”。

这两层不是一回事：

- 业务模型校验：判断返回的对象结构、字段名、字段类型是否符合宿主约定
- 运行时安全校验：判断返回值在 `flutter_js / JavaScriptCore` 里是否能被稳定地序列化并跨桥传回 Dart

当前闪退问题说明：

- 有些源的最终结果模型看起来是对的
- 但返回值内部混入了不安全对象
- 这些对象在 JS -> 原生插件 -> Dart 的字符串化过程中触发 `JavaScriptCore` 原生崩溃
- 一旦崩在原生层，Dart `try/catch` 没机会接住，宿主会直接闪退

一句话总结：

- 现在缺的不是“再多包一层异常处理”
- 而是“在 JS 返回值离开脚本运行时之前，先统一做安全净化”

## 1. 背景问题

当前宿主已经具备：

- `SourceScriptCompileException`
- facade 层统一错误归一化
- 业务模型 decode 校验

但这些能力都建立在一个前提上：

- JS 返回值已经安全回到了 Dart

问题在于，Apple 平台下 `flutter_js` 底层使用 `JavaScriptCore`，当前崩溃栈已经多次落在：

- `JavaScriptCore`
- `JSValueToStringCopy`

这说明问题有一部分并不是“业务返回值 decode 失败”，而是“返回值在被插件转换成字符串时，原生层先崩了”。

## 2. 为什么“模型看起来正确”仍然会闪退

这类问题常见于下面几种情况：

### 2.1 `extra / debug` 混入不可序列化对象

示例：

```js
return {
  title: '书名',
  detailUrl: 'https://a.com/book/1',
  extra: {
    node: doc,
  },
};
```

从业务角度看：

- `title` 正确
- `detailUrl` 正确

但 `extra.node` 不是普通 JSON 数据。

### 2.2 返回值中出现循环引用

示例：

```js
const result = {
  title: '书名',
  detailUrl: 'https://a.com/book/1',
};
result.extra = { self: result };
return result;
```

业务字段看起来没问题，但对象本身不可安全字符串化。

### 2.3 抛出的 error 不是普通 Error

示例：

```js
const error = Object.create(null);
error.message = '规则异常';
throw error;
```

如果桥接层继续对这类 error 做 `String(error)` 或隐式字符串转换，仍可能触发原生风险。

### 2.4 返回值过深、过大、结构过于复杂

示例：

```js
return {
  title: '书名',
  detailUrl: 'https://a.com/book/1',
  debug: {
    hugeHtml: html,
    nested: veryDeepObject,
  },
};
```

即使字段名都合法，数据本身仍可能对 JS runtime 和插件桥接造成压力。

## 3. 当前宿主哪里已经做了校验

当前 `SourceScriptCompiler` 已经对返回值做了业务 decode 校验，例如：

- `search` 必须返回数组
- `discoverCategories` 必须返回数组
- `discoverBooks` 必须返回数组
- `detail` 必须返回对象
- `chapters` 必须返回数组
- `content` 必须返回对象

这些校验是必要的，但它们是在“返回值已经成功进入 Dart”之后做的。

换句话说：

- 它能解决“值不符合规范”
- 不能解决“值还没进 Dart 就把原生 runtime 弄崩”

## 4. 目标

本次方案目标：

- 把脚本源返回值在 JS 侧统一净化成 JSON-safe 数据
- 把“宿主闪退”尽量收敛成“当前源执行失败 + 日志 + 可展示错误”
- 不改变现有业务模型 decode 的职责
- 把这层保护明确视为“所有在线书源能力的统一宿主边界”，而不是只修某个页面

非目标：

- 不放宽书源规范
- 不让宿主接受任意复杂对象
- 不通过页面级 try/catch 掩盖原生 runtime 崩溃

## 5. 设计原则

### 5.1 分两层处理

第一层：运行时安全净化

- 位置：`_SourceScriptRunner.run()`
- 目标：返回值必须先变成 JSON-safe

第二层：业务模型 decode 校验

- 位置：`_decodeBooks / _decodeBook / _decodeChapters / _decodeContent / ...`
- 目标：字段结构必须符合宿主约定

### 5.2 通用安全净化先于业务 decode

顺序应为：

1. JS 执行函数
2. JS 侧净化返回值
3. JS 侧转成安全字符串
4. Dart 侧 decode
5. Dart 侧业务模型校验

### 5.3 不把复杂对象直接交给插件

长期约束：

- 不让 `flutter_js` 对“任意 JS 对象”做 `stringResult`
- 应尽量只让插件返回“已经是纯字符串的安全结果”

## 6. 建议方案

### 6.1 在 JS 侧新增统一 sanitize

在脚本运行 bootstrap 内增加类似：

```js
function sanitizeForHost(value, depth, seen) {
  // 只允许 null / bool / number / string / plain object / array
  // 限深度
  // 限字段数
  // 遇到循环引用时丢弃或替换为占位值
}
```

规则建议：

- 基础类型直接保留
- `undefined / function / symbol / bigint` 直接转 `null`
- 数组逐项净化
- 普通对象逐字段净化
- 非 plain object 统一转 `null` 或字符串占位
- 遇到循环引用时写入 `null`
- 达到最大深度时停止展开

### 6.2 在 JS 侧先编码，再回 Dart

当前不建议把任意对象直接作为 `runSnippet()` 的返回值交给插件。

建议改成：

```js
const raw = await __fn.apply(__source, [__ctx, ...__args]);
const safe = sanitizeForHost(raw, 0, new WeakSet());
return JSON.stringify({ ok: true, value: safe });
```

错误路径也改成显式编码：

```js
catch (error) {
  return JSON.stringify({
    ok: false,
    error: safeErrorMessage(error),
  });
}
```

这样 Dart 侧拿到的永远是宿主可控字符串，而不是复杂 JS 值。

### 6.3 错误消息不再依赖危险字符串转换

当前高风险写法包括：

- `String(error)`
- `String(value)`
- 对未知对象直接做隐式字符串化

建议统一成保守策略：

- 优先取 `error.message`
- 再取 `error.name`
- 都拿不到时返回固定文本：
  - `"[non-serializable error]"`
  - `"[non-serializable value]"`

### 6.4 对 `extra / debug` 做额外保守处理

建议：

- 默认允许 `extra / debug`
- 但内部值同样必须走 sanitize
- 如有必要，再追加字段数和尺寸上限

因为这些字段最容易出现“业务不依赖，但运行时会被拖崩”的情况。

## 7. 覆盖范围

本方案应统一覆盖所有在线书源能力，以及这些能力在不同业务场景下的调用：

- `search`
- `discoverCategories`
- `discoverBooks`
- `detail`
- `chapters`
- `content`

对应业务场景包括但不限于：

- 搜索页
- 阅读页切章 / 正文加载
- 详情页目录拉取
- 发现页切源 / 分类 / 书单
- 书架页后台刷新最新章节
- 手动换源 / 自动换源
- 单源检测 / 批量检测

原因不是它们页面不同，而是它们共享同一条“脚本返回值过桥”风险边界。

## 8. 推荐实施顺序

### 阶段 A：返回值安全净化

- [ ] 在 bootstrap 内新增 `sanitizeForHost`
- [ ] 在 `_SourceScriptRunner.run()` 的 JS 包装层统一使用 sanitize
- [ ] 插件只接收最终安全字符串

验收：

- 返回循环引用对象不再导致宿主闪退
- 返回 DOM/句柄对象不再导致宿主闪退
- 错误对象不标准时也能稳定回到 Dart

### 阶段 B：错误结构统一

- [ ] JS 侧统一输出 `{ ok, value, error }`
- [ ] Dart 侧统一解析
- [ ] 失败统一映射为 `SourceScriptCompileException / AppException`

验收：

- 所有 step 都能产出稳定错误文本
- 不再依赖插件的隐式 `stringResult` 语义区分错误

### 阶段 C：日志补强

- [ ] 记录 sanitize 是否发生截断
- [ ] 记录循环引用是否被裁剪
- [ ] 记录字段大小/深度裁剪次数

验收：

- 出问题时能知道是“业务字段错误”还是“返回值被安全净化裁剪”

## 9. 验收标准

- [ ] 书源返回值含循环引用时，宿主不闪退，只报错
- [ ] 书源返回值含 DOM/句柄对象时，宿主不闪退，只报错
- [ ] 书源抛出非标准 error 对象时，宿主不闪退，只报错
- [ ] 所有在线书源相关链路都走同一套安全净化
- [ ] 业务 decode 继续保持当前职责，不被运行时净化逻辑污染

## 10. 最终判断

当前项目要实现“坏源失败，但 App 不闪退”，不能只依赖：

- 业务模型规范
- Dart `try/catch`

因为原生崩溃发生在这些能力之前。

真正有效的方向是：

- 先把 JS 返回值统一收敛成安全可序列化数据
- 再让 Dart 去做业务模型校验和错误展示

一句话总结：

- 规范解决“返回结构对不对”
- 返回值安全净化解决“宿主会不会被返回值带崩”
