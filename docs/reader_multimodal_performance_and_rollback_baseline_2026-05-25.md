# 阅读器多模态性能与回滚基线

更新时间：2026-05-25

## 1. 性能关注点

### 文本

- 分页首算时延
- 连续滚动章节切换时延
- inline image 预加载峰值

### PDF / Hybrid

- 首次打开 PDF 的文档加载时延
- 页码切换时延
- 缩放后页面重绘稳定性
- 大 PDF 内存峰值

### 固定版式 EPUB

- fixed-layout 识别时延
- 图片 / 资源物化时延
- 页级内容恢复正确率

### 漫画 / 绘本

- 图片预加载窗口带来的内存峰值
- 连续滚动滑动流畅度
- 分页切换响应时间

### 听书

- 首次音频加载时延
- 倍速切换响应时间
- 播放位置恢复正确率

## 2. 建议基线样本

- [ ] 大 TXT：50 万字以上
- [ ] 流式 EPUB：100 章以上且含正文图片
- [ ] 大 PDF：1000 页以上
- [ ] 扫描版 PDF：300 页以上
- [ ] 漫画长章节：80 图以上
- [ ] 绘本 / 杂志：30 页以上
- [ ] 听书长章节：60 分钟以上

## 3. 回滚边界

### 内容模式扩展

可回滚点：

- `ReaderContentModeResolver`
- `ReaderModeResolver`
- `ReaderModeCapabilitiesResolver`

回滚策略：

- `hybrid` 命中失败时可暂时退回 `text` / `comic`

### PDF 阅读器

可回滚点：

- `ReaderPdfView`
- `pdfrx` 依赖
- `LocalContentProvider` 的 `pdf` contentType 标记

回滚策略：

- 保留按页文本抽取链路
- 临时退回“文本抽取预览 + 不启用固定页 viewer”

### 固定版式 EPUB

可回滚点：

- `EpubLocalBookParser` fixed-layout 识别
- `epub-fixed` contentType 标记

回滚策略：

- 临时全部退回流式 EPUB 文本模式

### AudioReader 增强

可回滚点：

- 音频倍速 UI
- 音频 position snapshot 写入

回滚策略：

- 保留基础播放，关闭倍速和恢复时间点逻辑

## 4. 当前残留风险

- fixed-layout EPUB 还未做到高保真 HTML/CSS 版式恢复
- PDF / fixed-layout EPUB 的目录页级跳转尚未补完
- AudioReader 还未接后台播放和章节队列控制
- 跨模式交互 widget 测试覆盖仍偏薄
