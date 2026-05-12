# 跨端原生边界与 Flutter 收口方案

更新时间：2026-04-17  
用途：梳理当前项目在 iOS、Android、macOS、Windows、Linux、Web 的职责边界，明确哪些能力必须保留在原生层，哪些能力应该统一收口到 Flutter / Dart 层，并给出后续重构优先级。
总计划状态：`已完成专题`

## 0. 结论先行

这次“iOS 通过其他方式打开 TXT 失败、Android 正常”的问题，已经把当前项目的跨端边界问题暴露得很典型：

- 外部文件接入这件事，必须由原生层处理
- TXT 内容解析这件事，应该尽量由 Flutter / Dart 统一处理
- 当前项目在“内容解析”这层仍然混入了原生编码插件，因此出现了 Android 正常、iOS 失败的差异

一句话总结：

- **系统入口保留原生**
- **内容处理统一 Flutter**

本方案的目标不是“一刀切全改成 Flutter”，而是把平台职责收口到合理边界。

当前状态（2026-04-28）：

- 外部导入桥、source runtime health / scheduler / conflict、交互式 webview 验证入口已统一通过 app-level provider 暴露
- `SourcePage / Bookshelf / AdvancedTheme / FontManagement / ScriptSourceDebugPage / ReaderPage` 不再直接抓 `instance` 作为主入口
- 阅读页平台能力已收口到 `ReaderPlatformBridgeService`，页面层只消费能力语义，不再直接编排亮度桥和音量键桥
- `runtime -> application -> presentation` 现有主链已固定为：shared runtime/bridge implementation -> app/provider wiring -> feature application -> presentation

阶段 5 的桥接策略：

- 保留共享实现但通过 provider 暴露：
  - `ExternalImportBridge`
  - `SourceHealthService`
  - `SourceRuntimeSchedulerService`
  - `SourceRuntimeTaskConflictService`
  - `InteractiveVerificationBrowserExecutor`
- 以 feature application service 暴露能力：
  - `ReaderPlatformBridgeService`
  - `SourceLoginBrowserService`
  - `SourceLoginRuntimeService`

---

## 1. 这次 iOS 失败的直接原因

现象：

- Android 通过“其他方式打开 TXT 小说”可以正常导入、索引、阅读
- iOS 同路径下失败
- 错误为 `CharsetConversionError`

根因判断：

- 不是 TXT 导入主流程本身有平台分叉
- 也不是“外部文件打开”这层的主流程设计错误
- 真正的差异发生在 **编码检测 / 解码** 这一层

当前相关实现位于：

- [lib/features/reader/application/local/local_text_encoding_detector.dart](../lib/features/reader/application/local/local_text_encoding_detector.dart)
- [lib/features/reader/application/local/txt_local_book_parser.dart](../lib/features/reader/application/local/txt_local_book_parser.dart)

问题点在于：

- `LocalTextEncodingDetector` 会调用原生插件
  - `charset_converter`
  - `flutter_charset_detector`
- 这意味着 TXT 内容解析并不是纯 Dart 一套逻辑
- Android 与 iOS 实际调用的是不同平台实现

所以最终表现为：

- Android 能解
- iOS 在原生编码插件链路中失败

这也是为什么这次修复方向不是“继续补原生桥逻辑”，而是把 TXT 常见编码解析继续拉回 Dart 层。

---

## 2. 当前相关代码分布

### 2.1 文件导入链路

- iOS 文件入口  
  [ios/Runner/AppDelegate.swift](../ios/Runner/AppDelegate.swift)

- Android 文件入口  
  [android/app/src/main/kotlin/com/jiangyan/selune/MainActivity.kt](../android/app/src/main/kotlin/com/jiangyan/selune/MainActivity.kt)

- Flutter 桥接层  
  [lib/features/source/application/external_source_import_bridge.dart](../lib/features/source/application/external_source_import_bridge.dart)

- 本地图书导入  
  [lib/features/bookshelf/application/local_book_import_service.dart](../lib/features/bookshelf/application/local_book_import_service.dart)

- 本地图书存储  
  [lib/features/reader/application/local/local_book_storage_service.dart](../lib/features/reader/application/local/local_book_storage_service.dart)

- TXT 解析  
  [lib/features/reader/application/local/txt_local_book_parser.dart](../lib/features/reader/application/local/txt_local_book_parser.dart)

### 2.2 启动页链路

- iOS 原生启动页  
  [ios/Runner/Base.lproj/LaunchScreen.storyboard](../ios/Runner/Base.lproj/LaunchScreen.storyboard)

- Android 原生启动页  
  [android/app/src/main/res/drawable/launch_background.xml](../android/app/src/main/res/drawable/launch_background.xml)  
  [android/app/src/main/res/drawable-v21/launch_background.xml](../android/app/src/main/res/drawable-v21/launch_background.xml)

- Flutter 启动遮罩  
  [lib/app/app.dart](../lib/app/app.dart)

### 2.3 阅读器输入与主题

- 音量键桥  
  [lib/features/reader/application/reader_volume_key_page_bridge.dart](../lib/features/reader/application/reader_volume_key_page_bridge.dart)

- 阅读器设置  
  [lib/features/reader/application/reader_preferences_service.dart](../lib/features/reader/application/reader_preferences_service.dart)

- 全局主题模式  
  [lib/app/theme/app_theme_provider.dart](../lib/app/theme/app_theme_provider.dart)

- 阅读页  
  [lib/features/reader/presentation/reader_page.dart](../lib/features/reader/presentation/reader_page.dart)

---

## 3. 平台职责矩阵

### 3.1 iOS

当前职责：

- 接收系统通过 `open url` 打开的文件
- 识别文件类型
- 将外部文件复制到 App 可读缓存目录
- 将导入 payload 通过 `MethodChannel` 交给 Flutter
- 接收音量键拦截相关桥接
- 承载原生启动页

当前问题：

- TXT 内容解析不该依赖 iOS 原生字符转换插件
- 当前仍有 `charset_converter` / `flutter_charset_detector` 的参与

建议边界：

- 保留原生文件接入
- 保留原生启动页
- 保留音量键事件桥
- 不再让 iOS 原生负责 TXT 内容解码

### 3.2 Android

当前职责：

- 处理 `ACTION_VIEW / ACTION_SEND / ACTION_SEND_MULTIPLE`
- 从 `Intent` 提取文件 Uri
- 识别导入类型
- 将 payload 交给 Flutter
- 接收音量键桥接
- 承载原生启动页

当前问题：

- Android 当前能工作，但内容层仍存在原生编码依赖
- 只是 Android 平台实现恰好更稳定，不能因此视为架构正确

建议边界：

- 保留原生文件 Intent 接入
- 保留原生启动页
- 保留音量键事件桥
- 编码解码逻辑继续迁回 Flutter

### 3.3 macOS

当前职责：

- 主要是标准 Flutter 壳层
- 目前没有与 iOS/Android 等价的文件导入桥接逻辑

代码：

- [macos/Runner/AppDelegate.swift](../macos/Runner/AppDelegate.swift)

建议边界：

- 尽量保持原生层极薄
- 文件导入若后续扩展，优先仍以 Flutter 业务层消费为核心

### 3.4 Windows

当前职责：

- 标准 Flutter 宿主壳

代码：

- [windows/runner/main.cpp](../windows/runner/main.cpp)
- [windows/runner/flutter_window.cpp](../windows/runner/flutter_window.cpp)

建议边界：

- 保持原生层只做宿主和窗口能力
- 本地文本解析仍统一给 Flutter

### 3.5 Linux

当前职责：

- 标准 Flutter 宿主壳

代码：

- [linux/runner/my_application.cc](../linux/runner/my_application.cc)

建议边界：

- 与 Windows/macOS 一致，尽量不在原生层扩散业务逻辑

### 3.6 Web

当前职责：

- 标准静态入口和 manifest
- 没有项目自定义的系统级桥接逻辑

代码：

- [web/index.html](../web/index.html)
- [web/manifest.json](../web/manifest.json)

建议边界：

- 保持最薄
- 所有业务逻辑仍由 Flutter 层统一驱动

---

## 4. 能力边界梳理

### 4.1 外部文件打开

是否必须原生：**是**

原因：

- iOS 必须通过 App 生命周期入口接收文件
- Android 必须通过 Intent 接收文件

当前判断：

- 当前 iOS/Android 原生接入方式是合理的
- Flutter 桥接层 [external_source_import_bridge.dart](../lib/features/source/application/external_source_import_bridge.dart) 也是正确的收口点

建议：

- 不要把“接收系统文件”这层迁到 Flutter 幻想成纯统一实现
- 保持原生只做接入与缓存

### 4.2 文件缓存与可恢复路径

是否应该 Flutter 统一：**是**

原因：

- 文件存储路径管理、本地副本、是否临时文件，这些本质是业务规则
- 这些规则不应该散落在原生层

当前判断：

- [local_book_storage_service.dart](../lib/features/reader/application/local/local_book_storage_service.dart) 已经是正确方向
- `external_imports` 判定为临时路径也是合理修复

建议：

- 继续把“什么路径可恢复、什么路径不可恢复”的规则集中在 Flutter 层

### 4.3 TXT 编码检测与解码

是否应该 Flutter 统一：**强烈建议是**

原因：

- 这是最容易出现跨平台差异的地方
- 同样的 TXT 在 Android 和 iOS 上不该因为插件实现不同而表现不同

当前判断：

- 当前这层仍然没有彻底 Flutter 化
- 即便逻辑表面在 Flutter，插件调用仍然带入平台差异

建议：

- 常见编码（UTF-8、UTF-16、Latin1、GBK、GB18030、Big5）优先走 Dart 实现
- 原生编码插件只作为少数 fallback
- iOS 最好彻底移除 `CharsetConverter` 参与 TXT 主路径

### 4.4 TXT 分章与索引

是否应该 Flutter 统一：**是**

原因：

- 分章规则、章节标题识别、长章节拆分都已经是业务逻辑
- 这层必须统一，否则跨端行为不可控

当前判断：

- [txt_local_book_parser.dart](../lib/features/reader/application/local/txt_local_book_parser.dart) 已经是正确承载点
- 新增的规则服务 [txt_chapter_rule_service.dart](../lib/features/reader/application/local/txt_chapter_rule_service.dart) 也属于这层

建议：

- 继续强化这层作为唯一权威解析层
- 不要让原生层参与“怎么分章”

### 4.5 阅读主题与主题模式

是否应该 Flutter 统一：**是**

原因：

- 主题切换完全是 Flutter UI 状态和业务状态
- 不依赖系统原生桥

当前判断：

- 全局主题和阅读正文主题联动逻辑应全部收口在 Flutter
- 当前已经在这个方向上

建议：

- 不要再引入原生层参与阅读主题模式

### 4.6 音量键翻页

是否必须原生接入：**是**

原因：

- 音量键本身是系统按键事件

是否应该 Flutter 决策：**是**

原因：

- “翻上一页还是下一页、何时开启、当前场景是否允许”都属于业务逻辑

当前判断：

- [reader_volume_key_page_bridge.dart](../lib/features/reader/application/reader_volume_key_page_bridge.dart) 的边界是合理的

建议：

- 原生负责采事件
- Flutter 负责解释事件

### 4.7 启动页

是否全原生：**不建议**

是否全 Flutter：**也不建议**

最佳方案：

- 原生启动页静态兜底
- Flutter 启动遮罩做动态能力

当前判断：

- [app.dart](../lib/app/app.dart) 的 `_StartupGuardPage` 已经是很好的动态承载点

建议：

- 原生层保持静态弱存在感
- 动态配置能力做在 Flutter 启动遮罩

---

## 5. 当前最明显的架构风险

### 风险 1：内容层仍混入原生插件依赖

风险文件：

- [local_text_encoding_detector.dart](../lib/features/reader/application/local/local_text_encoding_detector.dart)

表现：

- Android 正常、iOS 失败
- 同一功能路径产生平台差异

判断：

- 这是当前最优先要继续收口的点

### 风险 2：导入成功不等于可阅读

风险文件：

- [bookshelf_page.dart](../lib/features/bookshelf/presentation/bookshelf_page.dart)
- [local_book_import_service.dart](../lib/features/bookshelf/application/local_book_import_service.dart)

表现：

- 外部打开导入完成后，如果索引是后台异步，用户感知容易出错

判断：

- 外部导入路径应优先保证“导入后立刻可读”

### 风险 3：边界清晰但文档不完整

现状：

- 代码其实已经开始往正确边界演进
- 但没有一份统一文档把“什么留原生、什么收 Flutter”说清楚

判断：

- 后续容易在不同能力上反复争论边界

---

## 6. 推荐重构方向

### 第一优先级：继续去原生化 TXT 内容解析

目标：

- iOS 不再依赖原生字符转换插件走 TXT 主路径
- Android 也尽量不再依赖原生转换插件作为主逻辑

建议动作：

1. `LocalTextEncodingDetector` 中对常见编码默认走 Dart 解码
2. 插件检测只保留为 fallback
3. 为 UTF-8 / UTF-16 / GBK / GB18030 / Big5 建立更完整的 Dart 测试样例

当前状态（2026-04-27）：

- `LocalTextEncodingDetector` 已调整为 Dart 常见编码优先，插件仅作为 fallback
- TXT 导入主路径已改为保留原始字节，不再在导入阶段重写 UTF-8
- 已补覆盖 UTF-8 / UTF-16LE / UTF-16BE / GBK / GB18030 / Big5 的代表性测试

### 第二优先级：固定外部导入后索引时序

目标：

- 外部打开 TXT 时，导入完成后应尽量直接可读

建议动作：

1. 外部导入路径保持 `waitForIndexing: true`
2. 明确“导入成功”的定义为“至少目录已可用”

当前状态（2026-04-27）：

- 外部导入路径已保持 `waitForIndexing: true`
- 手动导入入口也已统一到同一口径
- 当前“导入成功”语义已收紧为“目录已建立，可直接阅读”

### 第三优先级：保留原生桥但限制扩散

目标：

- 原生桥只做系统接入，不扩散业务逻辑

建议动作：

1. 所有新的系统入口能力先问自己：是否真的是系统层能力
2. 如果只是业务判断，不允许下沉到原生

### 第四优先级：补一份“平台边界检查清单”

建议在后续开发时统一遵守：

- 新需求是否必须接系统生命周期？
- 是否必须读系统原生事件？
- 是否只是内容层数据处理？
- 是否能在 Dart 里稳定测试？

如果答案是“只是内容层处理”，优先 Flutter。

---

## 7. 最终建议

当前项目不应该追求：

- “所有东西都走 Flutter”

也不应该继续维持：

- “看起来是 Flutter 逻辑，实际关键环节仍然依赖各端原生插件”

真正应该追求的是：

- **系统入口在原生**
- **文件内容在 Flutter**
- **主题状态在 Flutter**
- **阅读行为在 Flutter**
- **原生层保持最薄**

---

## 8. 一句话版本

这次 iOS TXT 打不开，说明你们项目最需要继续收口的不是“文件入口”，而是“文本解析层”。

接收系统文件必须原生；  
解析 TXT 内容应该尽量统一到 Flutter / Dart。
