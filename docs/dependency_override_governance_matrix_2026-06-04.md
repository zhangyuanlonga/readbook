# 依赖 Override 治理矩阵

创建日期：2026-06-04

用途：记录 `pubspec.yaml` 中每个 `dependency_overrides` 的存在原因、影响平台、成熟替代方向和退出条件。任何新增、删除或改名 override，都必须同步本文档，并通过 `dart tool/check_dependency_override_governance.dart`。

## 1. 治理原则

- override 只能作为明确技术债或兼容补丁存在，不能作为默认依赖管理方式。
- 每个 override 必须说明为什么不能直接使用 pub.dev 上游版本。
- 每个 override 必须说明 Android、iOS、Web JS、macOS、Windows、Linux 影响范围。
- 每个 override 必须有成熟替代、回主线或长期保留的退出条件。
- 涉及 Web stub、PDF、编码检测、翻页组件等高风险能力时，必须补测试或 smoke 入口。

## 2. 当前 Override 矩阵

| 包名 | 本地路径 | 当前用途 / 原因 | 影响平台 | 当前风险 | 成熟替代 / 回主线方向 | 验证入口 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pdfium_dart | `third_party/plugins/pdfium_dart` | `pdfrx` / PDF 渲染链依赖的 PDFium FFI 底层包，本地包带 native assets build / link hooks。 | Android、macOS、Windows、Linux；iOS 通过 Flutter 插件链路间接受影响；Web JS 不直接支持。 | 本地包 `sdk: ^3.10.0` 高于项目 `^3.7.2`；`dart run tool/...` 曾触发 `libpdfium.dylib` 签名失败。 | 优先评估与当前 Flutter / Dart SDK 匹配的上游 `pdfrx` / `pdfium_dart` 版本；如果升级 SDK，应同步移除本地 override 或确认仍需补丁。 | `flutter build web --no-pub`、`flutter build macos --debug --no-pub`、PDF 页面 smoke、native assets 相关 guard。 | 上游版本支持当前项目 SDK 和目标平台，且 PDF 渲染 / build hook 不再需要本地补丁。 | 暂留 |
| flutter_charset_detector_android | `third_party/plugins/flutter_charset_detector_android` | Android 端编码检测实现，供 TXT / HTML 等本地内容解码兜底。 | Android 直接影响；其他平台通过 `flutter_charset_detector` 联邦插件选择实现。 | 本地包版本与上游关系需复查；MethodChannel 实现需要 Android 真机 / 模拟器补验。 | 优先回到上游 endorsed Android implementation；如果保留本地实现，需说明本地差异。 | `flutter test test/features/reader/application/local/txt_local_book_parser_test.dart`、Android TXT 导入 smoke。 | 上游 Android 实现满足编码检测需求，且 Android TXT 导入 smoke 通过。 | 暂留 |
| flutter_charset_detector_web | `third_party/plugins/flutter_charset_detector_web_stub` | 项目 Web stub，Web 端固定按 UTF-8 / allowMalformed 解码，避免 Web build 缺少联邦实现。 | Web JS 直接影响；Native 不应使用。 | 这是降级 stub，不是真正编码检测；非 UTF-8 Web 上传文件可能显示异常。 | 评估成熟 Web 编码检测方案；若没有可靠方案，保留 stub 但在 Web 本地内容策略中写清降级。 | `flutter build web --no-pub`、Web 上传 TXT smoke、编码检测单测。 | Web 端有成熟编码检测实现，或 Web 本地内容明确只支持 UTF-8 并在 UI 中说明。 | 暂留 |
| pdf_text_extract | `third_party/plugins/pdf_text_extract` | PDF 文本抽取插件，当前 `PdfLocalBookParser` 通过 `PDFDoc.fromPath` 抽取 PDF 页文本。 | Android、iOS 直接支持；Web JS、macOS、Windows、Linux 当前不支持此插件链路。 | 插件只声明 Android / iOS；本地 PDF 文本抽取多端能力不完整；MethodChannel 无法进 Dart isolate。 | 优先评估 `pdfrx` / PDFium 文本抽取、或更活跃的跨端 PDF 文本库；PDF 全端闭环应作为单独专项。 | `flutter test test/features/reader/application/local/pdf_local_book_parser_test.dart`、Android / iOS PDF 导入 smoke。 | 新方案支持目标平台、密码 / 扫描版失败路径可解释，且 PDF parser tests 通过。 | 暂留 |
| screen_retriever_macos | `third_party/plugins/screen_retriever_macos` | macOS 端屏幕信息实现，供 `window_manager` / 桌面窗口初始化链路解析插件。 | macOS 直接影响；Android、iOS、Web JS、Windows、Linux 不应使用该实现。 | 本地 macOS 联邦插件可能落后上游 SPM / Flutter 插件模板，后续 Flutter 版本会更严格要求插件维护状态。 | 优先回到上游 `screen_retriever_macos`；如果上游仍不兼容当前 Flutter / macOS 构建，再保留最小本地补丁。 | `flutter build macos --debug --no-pub`、桌面窗口启动 smoke、dependency override guard。 | 上游版本支持当前 Flutter SDK、macOS 构建通过，且窗口启动 smoke 无回退。 | 暂留 |
| turnable_page | `third_party/plugins/turnable_page` | 阅读器纸张翻页效果，当前阅读器 paper curl 和跨章节 snapshot overlay 依赖该包。 | Android、iOS、Web JS、Desktop UI 交互均可能受影响。 | 本地包 `sdk: ^3.8.1` 高于项目 `^3.7.2`；RenderBox 手势和 controller detach 行为已有项目侧兼容注释。 | 优先评估上游 `turnable_page` 与当前 SDK / Flutter 的兼容版本；若行为仍不稳定，考虑项目自有 adapter 包装或替换为更成熟翻页方案。 | `flutter test test/features/reader/presentation/reader_runtime_controller_test.dart`、阅读器分页 / paper curl smoke。 | 上游版本支持当前 SDK，阅读器触控、桌面键鼠、跨章节翻页 smoke 稳定通过。 | 暂留 |

## 3. 当前结论

- 这 6 个 override 暂不直接删除，因为它们都绑定阅读器、本地内容、PDF / 编码 / 翻页或桌面窗口高风险能力。
- `pdfium_dart` 和 `turnable_page` 的本地包 SDK 约束高于项目 SDK，是后续依赖治理和 SDK 升级窗口的重点。
- `flutter_charset_detector_web` 是明确 Web 降级 stub，不应被误判为成熟编码检测能力。
- `pdf_text_extract` 只覆盖 Android / iOS，不能作为 PDF 多端闭环的最终方案。
- M2-10 macOS build 已确认 `charset_converter` 需要保持带 macOS plugin 声明的 `2.4.0` 解析结果；`2.3.0` 缺少 macOS 插件声明时，生成的 macOS registrant 会导入不存在的模块，导致构建失败。它不是 override，但属于依赖治理风险点。
- M2-10 移动端补构建曾确认：Android 需要在根 Gradle 配置覆盖旧插件写死的 Kotlin language / api version，避免 `sentry_flutter 8.14.2` 的 Kotlin 1.6 配置被 Kotlin 2.x 工具链拒绝；2026-06-05 M6 阶段补验中，Android debug APK 与 iOS `--no-codesign` 构建均已通过。
- 下一步如果继续 M2-D003 的后续深化，应先补每个本地包与上游差异清单，再决定是否回主线或替换。

## 4. 维护命令

```bash
dart tool/check_dependency_override_governance.dart
flutter pub get --offline
flutter analyze
```

如果修改了 PDF、编码检测或翻页链路，按影响范围补充：

```bash
flutter test test/features/reader/application/local/pdf_local_book_parser_test.dart
flutter test test/features/reader/application/local/txt_local_book_parser_test.dart
flutter test test/features/reader/presentation/reader_runtime_controller_test.dart
flutter build web --no-pub
flutter build macos --debug --no-pub
```
