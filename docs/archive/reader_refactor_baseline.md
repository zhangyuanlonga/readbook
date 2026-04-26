# 阅读器改造前基线

更新时间：2026-04-02
用途：作为阶段 B 的回归基线，后续阅读器重构必须至少保持以下行为不退化。

## 1. 必守主路径

- 打开章节：文本章节可正常进入阅读页，本地与脚本源都能加载。
- 切章：上一章、下一章、连续滚动预加载不能落到分卷节点。
- 书签：正文内书签可创建、展示、删除、跳转。
- 目录：目录可展示当前书源章节，分卷节点不可直接阅读。
- 自动阅读：文本模式可启动、暂停、恢复、停止。
- 换源：脚本源阅读中可切换书源，并尽量保留章节定位。
- 缓存：支持缓存的书源可按目录批量缓存可读章节。
- 分页：分页模式可翻页、恢复进度、切换动画。
- 滚动：滚动模式可定位、自动阅读、连续章节追加。
- 漫画：纯图片章节继续走独立图片阅读路径。

## 2. 当前已落地的自动化保护

- `test/features/book/application/book_detail_service_test.dart`
  覆盖目录加载与 `isVolume` 保留。
- `test/features/reader/application/reader_chapter_navigation_test.dart`
  覆盖分卷节点跳过与可读章节定位。
- `test/features/reader/application/chapter_content_service_test.dart`
  覆盖脚本源正文缓存、纯图片章节缓存。
- `test/features/reader/application/local_content_provider_test.dart`
  覆盖本地图文混排与纯图片章节区分。
- `test/domain/entities/reader_document_test.dart`
  覆盖统一文档模型、序列化、图文顺序。
- `test/features/reader/application/reader_preferences_service_test.dart`
  覆盖阅读设置、阅读进度、目录快照持久化。

## 3. 仍需补齐的回归项

- 同一章在滚动/分页下恢复进度一致。
- 切换滚动/分页模式后不丢章节和定位。
- 换源后的定位保留需要更贴近阅读页主流程的测试。
- 阅读页菜单与设置分层目前仍主要依赖人工验证。
