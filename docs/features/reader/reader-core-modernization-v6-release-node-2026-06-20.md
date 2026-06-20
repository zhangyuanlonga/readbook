# 阅读器核心改造 V6：正式替换与质量打磨

**日期**: 2026-06-20
**状态**: 已完成代码 alpha，待 TF 样本/性能验收
**进度**: 78%
**用户效果**: 文本分页阅读默认进入新 layout renderer；旧阅读器保留为 fallback，可通过打包参数一键回滚。

---

## 1. 目标效果

V6 是默认切换节点。当前代码已把 text+paged 正式入口切到新 renderer，并保留旧 `ReaderPagedAnimationSurface` 作为 fallback。

- [x] 新文本分页阅读器默认开启。
- [x] 旧阅读器保留 fallback。
- [x] release/TF 回滚开关明确。
- [x] 新 renderer diagnostics 写入阅读器诊断上下文。
- [x] 长按选择最小闭环接入现有灵感/复制工具条。
- [ ] 长文本、长段落、中文标点、EPUB、漫画、PDF、音频样本 smoke 记录补齐。
- [ ] profile mode 首屏和内存峰值记录补齐。
- [ ] TF 外部用户灰度反馈闭环补齐。

---

## 2. 已落地代码

- [x] 新增 `ReaderLayoutReleasePolicy`：集中判断正式入口是否启用新 renderer。
- [x] 新增 `ReaderLayoutReleaseSurface`：正式入口复用 renderer controller，但隔离 preview 命名。
- [x] `ReaderPage` textPaged 入口默认走 release renderer。
- [x] release renderer ready 状态复用现有 header/footer/padding/page index 框架。
- [x] release renderer loading/fallback 状态可回到旧分页路径。
- [x] 新 renderer 页数纳入 `_currentPagedPageCount`，进度保存不再按 0 页处理。
- [x] pageIndex override 接入，外部 tap/键盘翻页可以同步新 PageView。
- [x] selection snapshot 桥接到现有灵感工具条。
- [x] 书签 highlight 转为 `ReaderLayoutTextAnnotationRange`。
- [x] 复制诊断时包含 layout release 状态、页数和 fallback reason。

---

## 3. TF/Release 开关

默认策略：

- [x] `ReaderContentMode.text` + `ReaderModeViewportKind.textPaged` + 有文本内容：启用新 renderer。
- [x] 滚动文本、漫画、PDF/混合文档、音频：不切新 renderer。
- [x] layout stream 失败、空结果、取消：走旧 renderer fallback。

打包参数：

- [x] 强制回旧阅读器：`--dart-define=READER_LAYOUT_FORCE_LEGACY=true`
- [x] 关闭 V6 默认切换：`--dart-define=READER_LAYOUT_ENABLE_RELEASE=false`
- [x] 显示 layout diagnostics overlay：`--dart-define=READER_LAYOUT_SHOW_DIAGNOSTICS=true`
- [x] 设置内容长度保护阈值：`--dart-define=READER_LAYOUT_MAX_CONTENT_LENGTH=300000`

建议 TF 外部邀请首包：

- [x] 默认启用新 renderer。
- [x] 保留紧急回滚包：`READER_LAYOUT_FORCE_LEGACY=true`。
- [ ] 样本 smoke 和 profile 数据补齐后再扩大外部用户范围。

---

## 4. 必须完成项

- [x] fallback 开关。
- [x] release notes 和回滚说明。
- [x] diagnostics 记录新旧路径状态。
- [x] 自动单测覆盖发布策略和 ready wrapper。
- [ ] 全量样本库补齐。
- [ ] 自动 smoke 和手工 smoke 双清单。
- [ ] profile mode 性能基线。
- [ ] 内存峰值检查。
- [ ] 首屏耗时检查。
- [ ] 章节切换和设置变化压力测试。

---

## 5. 不做项

- [x] 不删除旧阅读器。
- [x] 不让漫画/PDF/音频误走文本 layout renderer。
- [x] 不在没有 dart-define fallback 的情况下默认上线。
- [x] 不把复杂纸张卷页动画强行并入 V6；新 renderer 先使用稳定 PageView，旧 renderer 继续承担完整动画 fallback。

---

## 6. 验收标准

- [x] targeted `flutter analyze` 通过。
- [x] 新增 release policy 单测通过。
- [x] renderer surface readyBuilder/fallback 测试通过。
- [x] V2-V6 reader core test bundle 通过。
- [ ] 文本、EPUB、漫画、PDF、音频 smoke 通过。
- [ ] 超长文本不明显卡死。
- [ ] 进度恢复稳定。
- [ ] 标注/书签/搜索/朗读核心闭环稳定。
- [x] fallback 可关闭新阅读器。
- [x] 正式默认切换有灰度和回滚方案。

---

## 7. 当前风险

- [ ] 新 renderer 的高级翻页动画尚未追平旧 renderer，V6 默认路径先采用稳定 PageView。
- [ ] 新 layout selection 已接入长按选中和工具条，但跨页拖拽选择仍需后续追平。
- [ ] EPUB 图片真实 aspect ratio、点击 payload 和局部 relayout 仍需后续增强。
- [ ] profile mode 性能基线还未在当前提交内完成。

---

## 8. 最终完成定义

- [x] 新阅读器成为 text+paged 默认路径。
- [x] 旧阅读器只作为 fallback。
- [x] V6 文档更新完成。
- [ ] 样本、性能、异常、回滚都有记录。
- [ ] TF 外部邀请反馈无 P0/P1 阻塞问题。
