# 书源验证样本清单

这份清单用于验证当前平台是否已经能稳定承接不同类型的真实书源。  
它不追求一次性覆盖所有源，而是优先挑出一批“最能暴露问题”的样本。

当前样本来源目录：

- `/Users/zhangyuanlong/Downloads/read`

本轮主验证库优先选自：

- `/Users/zhangyuanlong/Downloads/read/shareBookSource (1).json`

原因：

- 体量适中，便于人工筛选和逐个验证
- 同时覆盖：
  - 普通 HTML 源
  - `GBK / GB2312` 编码源
  - `webView` 源
  - `jsLib` 源
  - POST 搜索源
  - 少量登录/复杂源

---

## 1. 验证目标

这批样本主要用于验证当前平台的这些核心能力：

- `init / search / detail / chapters / content` 主链路
- `ctx.http.request(...)`
- `charset`
- `bodyType`
- `execution: 'browser' / webView: true`
- `cookie / session / cache`
- `ctx.crypto`
- Debug 工作台能否看清失败原因

---

## 2. 样本分组

### 2.1 第一组：基础 HTML 源

这组用来验证最基础的小说源链路是否稳定。

#### `❤️红牛小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：低
- 特征：
  - 普通 HTML
  - 无 `webView`
  - 无 `jsLib`
  - 有自定义 `header`
- 主要验证：
  - 搜索
  - 详情
  - 目录
  - 正文
  - 基础字段映射

#### `💠 七零一七`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：低
- 特征：
  - 普通 GET 搜索
  - 无 `webView`
  - 无 `jsLib`
- 主要验证：
  - 最基础 HTTP + HTML 链路

#### `🐣求书网`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：低到中
- 特征：
  - 带 POST 搜索痕迹
  - 无 `webView`
  - 无 `jsLib`
- 主要验证：
  - 普通源里的表单搜索兼容性

#### `大白小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：中
- 特征：
  - 搜索 URL 需要先从首页取 form action
  - 带少量动态拼装逻辑
- 主要验证：
  - helper 写法
  - 基础 JS 处理能力

---

### 2.2 第二组：老编码源

这组重点验证：

- `charset`
- POST 搜索
- 老站兼容性

#### `🎀果露小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：很高
- 复杂度：中
- 特征：
  - `charset: GBK`
  - POST 搜索
  - 带 header
  - `concurrentRate: 1/5000`
- 主要验证：
  - `charset`
  - `bodyType=form`
  - 节流

#### `👑 果露小说88aaa`

- 来源文件：`shareBookSource (1).json`
- 优先级：很高
- 复杂度：中
- 特征：
  - `charset: GBK`
  - POST 搜索
  - 带 header
- 主要验证：
  - 同类 GBK 源的兼容稳定性

#### `速速中文`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：中
- 特征：
  - `charset: gbk`
  - POST 搜索
- 主要验证：
  - 老站表单搜索
  - 目录和正文是否仍能稳定拿到

#### `📃999书吧`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：中
- 特征：
  - `charset: gbk`
  - POST 搜索
- 主要验证：
  - 当前 `bodyType + charset` 组合是否已经够稳

---

### 2.3 第三组：浏览器执行源

这组重点验证：

- `execution: 'browser'`
- `webView: true`
- 浏览器环境下的搜索/页面解析

#### `❤️年代小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：中
- 特征：
  - 含 `webView`
- 主要验证：
  - 当前请求级浏览器执行意图是否够用

#### `笔趣阁`

- 来源文件：`shareBookSource (1).json`
- 优先级：很高
- 复杂度：中到高
- 特征：
  - `webView: true`
  - `charset: gbk`
  - 自定义 UA
- 主要验证：
  - 浏览器执行 + 老编码 联合场景

#### `🎉 西瓜小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：高
- 复杂度：中
- 特征：
  - 搜索请求显式带 `webView: true`
- 主要验证：
  - 简单浏览器型源的搜索链路

#### `🎉 小书本网`

- 来源文件：`shareBookSource (1).json`
- 优先级：很高
- 复杂度：高
- 特征：
  - 搜索逻辑里直接解析页面 form action
  - 带登录特征
- 主要验证：
  - 浏览器 + 动态拼装搜索 URL
  - 登录相关链路

---

### 2.4 第四组：`jsLib` / 中复杂源

这组重点验证：

- 复杂 helper
- 更高阶的 JS 逻辑
- 签名/编码/多步骤处理

#### `完本小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：中高
- 复杂度：中
- 特征：
  - 带 `jsLib`
- 主要验证：
  - 旧源辅助库迁移能力

#### `❤️绿柠小说`

- 来源文件：`shareBookSource (1).json`
- 优先级：中高
- 复杂度：中到高
- 特征：
  - `jsLib`
  - POST 搜索
- 主要验证：
  - `jsLib + bodyType`

#### `❤️国学書库`

- 来源文件：`shareBookSource (1).json`
- 优先级：中
- 复杂度：中
- 特征：
  - `jsLib`
- 主要验证：
  - 中等复杂度 helper 迁移

#### `🎉 聚合书库`

- 来源文件：`shareBookSource (1).json`
- 优先级：很高
- 复杂度：高
- 特征：
  - `webView`
  - `jsLib`
  - 登录特征
- 主要验证：
  - 当前平台对中高复杂源的承接能力上限

---

## 3. 推荐验证顺序

建议不要乱序测试，按下面顺序推进：

1. 第一组：基础 HTML 源
2. 第二组：老编码源
3. 第三组：浏览器执行源
4. 第四组：`jsLib` / 中复杂源

原因：

- 先确认主链路稳
- 再确认编码和表单
- 再压浏览器能力
- 最后再压复杂 helper

---

## 4. 暂缓样本

### `bbq.json`

- 类型：复杂起点源
- 特征：
  - 签名
  - 多接口
  - 浏览器/登录
  - 购买/正文等复杂链路
- 建议用途：
  - 作为复杂小说源专项样本
- 当前建议：
  - 暂缓到前面 16 个样本跑通后再回头处理

### `3000 书源.json`

- 类型：超大合集
- 建议用途：
  - 作为后续回归样本库
- 当前建议：
  - 不适合作为第一批人工转译和排错对象

### `manhua.json`

- 类型：漫画源
- 建议用途：
  - 后续漫画源专项验证
- 当前建议：
  - 先等小说主线稳定后再处理

---

## 5. 当前批次的最终建议

如果你现在只想高效推进，不要一下子全试，直接先做这 16 个：

- `❤️红牛小说`
- `💠 七零一七`
- `🐣求书网`
- `大白小说`
- `🎀果露小说`
- `👑 果露小说88aaa`
- `速速中文`
- `📃999书吧`
- `❤️年代小说`
- `笔趣阁`
- `🎉 西瓜小说`
- `🎉 小书本网`
- `完本小说`
- `❤️绿柠小说`
- `❤️国学書库`
- `🎉 聚合书库`

这批已经足够覆盖你们当前最关键的实现能力。
