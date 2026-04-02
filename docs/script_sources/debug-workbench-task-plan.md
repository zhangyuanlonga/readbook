# 脚本源调试工作台任务拆分

更新时间：2026-04-01
适用范围：`flutterreadbook`

## 1. 背景

当前项目已经完成以下前提：

- 在线书源唯一运行态模型为脚本源。
- 搜索、发现、详情、目录、正文主链已经接入脚本源 runtime。
- 官方模板、规范文档、运行时代码口径已基本对齐。
- 全量 `flutter test` 当前可通过。

但现有调试页仍偏“串行演示页”，不够支撑真实联调工作流。

当前页面：

- [script_source_debug_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/script_source_debug_page.dart)

当前能力：

- 固定按 `search -> detail -> chapters -> content` 顺序跑一遍
- 只支持关键词输入
- 能看到阶段结果、日志和调试轨迹

当前不足：

- 不能单独调某一步
- 不能把上一步结果显式带入下一步
- 不能直接编辑或修正 `book / chapter / category` 输入
- 不能区分“结果 / 错误 / 请求轨迹 / UI 预览”
- 不适合作为测试网站联调工作台

## 2. 目标

做一个“脚本源调试工作台”，让开发者能围绕一个测试网站高频执行这条循环：

1. 改脚本
2. 选择步骤
3. 运行
4. 看请求/错误/返回结果
5. 必要时把结果带入下一步
6. 重复调试直到搜索、详情、目录、正文链路稳定

## 3. 非目标

本轮不做：

- 书源市场
- 远程分发
- 云端同步
- 历史调试记录持久化
- 断点调试器
- 多源同时调试

## 4. 目标页面结构

工作台建议保持单页，但内部拆为 4 个区块。

### 4.1 源代码区

职责：

- 展示当前脚本源码
- 支持只读预览或跳回编辑页
- 展示当前调试目标源名

首版建议：

- 继续从编辑页跳转进入
- 调试页内不重新做完整代码编辑器
- 仅显示当前源码摘要和“返回编辑”入口

### 4.2 调试命令区

职责：

- 选择执行步骤
- 填写该步骤所需参数
- 控制是否复用当前 session / cache / 上一步结果

首版步骤：

- `search`
- `detail`
- `chapters`
- `content`

第二批可追加：

- `discoverCategories`
- `discoverBooks`

首版输入建议：

- `search`：关键词
- `detail`：从最近 `search` 结果选书，或粘贴 `book` JSON
- `chapters`：从最近 `detail` 结果选书，或粘贴 `book` JSON
- `content`：从最近 `chapters` 结果选章节，或粘贴 `book + chapter` JSON

### 4.3 结果区

职责：

- 展示结构化结果
- 展示运行错误
- 展示运行日志
- 展示请求/浏览器轨迹

建议 tab：

- `结果`
- `错误`
- `日志`
- `请求轨迹`

### 4.4 快速预览区

职责：

- 用接近真实 UI 的方式展示当前步骤结果

首版建议：

- `Book[]`：卡片列表预览
- `Chapter[]`：章节列表预览
- `Content`：正文预览

## 5. 交互流

目标交互：

1. 编辑页点“调试”
2. 打开调试工作台
3. 默认定位到 `search`
4. 输入关键词并运行
5. 结果区展示 `Book[]`
6. 点击“带入详情”
7. 自动切到 `detail`
8. 成功后再“带入目录”
9. 再“带入正文”

交互原则：

- 不强迫用户每一步都重新手填 JSON
- 用户可以覆盖自动带入的数据
- 每一步执行结果都要保留在当前页面，便于对照

## 6. 状态模型

建议页面内维护一个调试上下文对象：

```dart
class ScriptDebugWorkbenchState {
  final String sourceCode;
  final DebugStep selectedStep;
  final String keyword;
  final Map<String, Object?>? selectedBook;
  final Map<String, Object?>? selectedChapter;
  final Map<String, Object?>? selectedCategory;
  final List<Map<String, Object?>> recentSearchBooks;
  final Map<String, Object?>? recentDetailBook;
  final List<Map<String, Object?>> recentChapters;
  final Map<String, Object?>? recentContent;
  final List<DebugRunRecord> records;
  final bool keepSessionBetweenRuns;
  final bool keepCacheBetweenRuns;
}
```

说明：

- `records` 用于保存每次运行的结果、错误、日志、轨迹
- `recentSearchBooks / recentDetailBook / recentChapters` 用于跨步骤带入
- `keepSessionBetweenRuns` 用于联调登录态、验证码、Cookie 站点

## 7. 文件落点

建议优先在现有文件基础上演进，不新起复杂层级。

### 7.1 页面层

- [script_source_debug_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/presentation/script_source_debug_page.dart)

职责：

- 承载工作台 UI
- 管理表单、tabs、预览和上下文切换

### 7.2 调试执行层

- [source_script_compiler.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_script_compiler.dart)

职责：

- 继续承载 `SourceScriptDebugService`
- 增加针对单步调试的结构化执行入口

建议新增：

- `evaluateSearch(...)`
- `evaluateDetail(...)`
- `evaluateChapters(...)`
- `evaluateContent(...)`

或者统一为：

- `evaluateStep({ step, keyword, book, chapter, category, ... })`

### 7.3 结果模型

建议新增独立调试模型文件：

- `lib/features/source/presentation/script_debug_models.dart`

可选新增控制器：

- `lib/features/source/application/script_debug_workbench_controller.dart`

如果首版保持轻量，也可先不拆 controller，先在页面内完成。

## 8. 分阶段任务

## 阶段 A：把现有调试页改成“单步执行页”

目标：

- 不再固定跑四步串行流水
- 用户能显式选择执行 `search / detail / chapters / content`

任务：

- [ ] 增加步骤切换 UI
- [ ] 增加分步骤输入区
- [ ] 增加“运行当前步骤”按钮
- [ ] 保留现有日志/轨迹展示能力

验收：

- 可以只运行 `search`
- 可以只运行 `detail`
- 不运行前置步骤时，页面能明确提示缺少输入

## 阶段 B：打通跨步骤带入

目标：

- 搜索结果能直接带入详情
- 详情结果能直接带入目录
- 目录结果能直接带入正文

任务：

- [ ] 把最近一次 `search` 结果保存到工作台状态
- [ ] 支持从结果列表选择一本书作为 `detail` 输入
- [ ] 支持从章节列表选择章节作为 `content` 输入
- [ ] 支持用户手动编辑已带入对象

验收：

- 调试一条真实站点链路时，不需要手写大段 JSON

## 阶段 C：拆出结果视图 tabs

目标：

- 结果、错误、日志、轨迹清晰分区

任务：

- [ ] 结果 tab：结构化 JSON 展示
- [ ] 错误 tab：单独高亮错误信息
- [ ] 日志 tab：展示 `ctx.log`
- [ ] 请求轨迹 tab：展示 `ctx.http` / `ctx.browser` 调用轨迹

验收：

- 一次运行的请求、日志和错误不再混在一个大块文本里

## 阶段 D：增加 UI 预览

目标：

- 不只看 JSON，还能快速看“像不像最终 UI”

任务：

- [ ] `Book[]` 卡片预览
- [ ] `Chapter[]` 列表预览
- [ ] `Content` 正文预览

验收：

- 调试内容页时，能直接看到最终文本/图片呈现效果

## 阶段 E：支持 discover 调试

目标：

- 让发现链路也进入工作台

任务：

- [ ] 新增 `discoverCategories`
- [ ] 新增 `discoverBooks`
- [ ] 支持分类对象选取与分页参数输入

验收：

- 一个实现了 discover 的脚本源可以完整调试发现页链路

## 9. 建议实施顺序

推荐顺序：

1. 阶段 A
2. 阶段 B
3. 阶段 C
4. 阶段 D
5. 阶段 E

理由：

- A/B 解决“能不能高效联调”
- C 解决“出了问题能不能快速定位”
- D 解决“结果能不能接近真实页面感知”
- E 属于能力扩展，不阻塞主线测试网站联调

## 10. 测试建议

至少补这些测试：

- [ ] 工作台步骤切换测试
- [ ] `search -> detail` 自动带入测试
- [ ] 结果/错误/log/trace tab 展示测试
- [ ] `content` 预览渲染测试
- [ ] discover 调试页测试

推荐新增测试文件：

- `test/features/source/presentation/script_source_debug_page_test.dart`
  在现有文件基础上扩展
- `test/features/source/application/script_debug_workbench_controller_test.dart`
  如果引入 controller

## 11. 本轮建议先做什么

如果马上开始实现，建议只先做阶段 A + B。

原因：

- 这两步已经足够支撑你先写测试网站并开始联调
- 不需要先把预览做很复杂
- 可以最快把当前调试页升级成真正可用的工作台

本轮最小交付定义：

- 可单步执行 `search / detail / chapters / content`
- 可把 `search` 结果带入 `detail`
- 可把 `chapters` 结果带入 `content`
- 有基本的错误、日志、请求轨迹展示

做到这里，就可以支撑后续测试网站联调。
