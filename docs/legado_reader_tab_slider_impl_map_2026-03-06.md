# 开源阅读「上方 Tab + 下方滑动条」实现梳理（本地仓库对照）

日期：2026-03-06  
范围：仅梳理本地仓库实现位置与可迁移结构，不改功能行为。

## 1. 你截图这套 UI 在开源阅读里的核心入口

### 1.1 底部菜单入口（界面/设置）
- 底部按钮布局（`界面`、`设置`）：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/view_read_menu.xml:376`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/view_read_menu.xml:420`
- 章节进度滑条（位于底部菜单上方）：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/view_read_menu.xml:250`
- 点击事件分流：
  - `llFont -> showReadStyle()`：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt:483`
  - `llSetting -> showMoreSetting()`：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt:490`
- 实际弹窗打开：
  - `showReadStyle -> ReadStyleDialog`：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:1207`
  - `showMoreSetting -> MoreConfigDialog`：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:1214`

## 2. 截图中「上方 Tab 样式行 + 下方滑动条」主体

### 2.1 上方“Tab样式行”（按钮行）
- 布局文件：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/dialog_read_book_style.xml:11`
- 这行包含（与你截图一致）：
  - 字重：`text_font_weight_converter`（中/粗/细）
  - 字体：`tv_text_font`
  - 缩进：`tv_text_indent`
  - 简繁：`chinese_converter`
  - 边距：`tv_padding`
  - 信息：`tv_tip`
- 对应点击逻辑：
  - 字体弹窗：`tvTextFont.setOnClickListener`  
    `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt:117`
  - 缩进选择：`tvTextIndent.setOnClickListener`  
    `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt:120`
  - 边距弹窗：`tvPadding -> showPaddingConfig`  
    `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt:129`
  - 信息弹窗：`tvTip -> TipConfigDialog`  
    `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt:133`

### 2.2 下方滑动条行（字号/字距/行距/段距）
- 布局定义（4个 `DetailSeekBar`）：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/dialog_read_book_style.xml:128`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/dialog_read_book_style.xml:138`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/dialog_read_book_style.xml:147`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/dialog_read_book_style.xml:156`
- 数值映射（与截图右侧数值一致）：
  - `textSize = progress + 5`
  - `letterSpacing = (progress - 50) / 100f`
  - `lineSpacingExtra = progress`
  - `paragraphSpacing = progress`
  - 代码位置：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt:147`

### 2.3 “一行滑条”的通用组件（可直接参考）
- 组件类：`DetailSeekBar`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/widget/DetailSeekBar.kt:19`
- 组件布局：左标题 + 减号 + 中间滑条 + 加号 + 右数值
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/res/layout/view_detail_seek_bar.xml:9`
- 这就是你截图里“上面按钮、下面多条滑动条”的关键复用单元。

## 3. “信息 / 页眉页脚 / 正文不遮挡”相关实现（开源阅读）

### 3.1 信息条（页眉页脚）渲染与开关
- `PageView` 负责 header/footer 的显隐、颜色、布局和内容：
  - Header/Footer 高度计算：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt:60`
  - Header/Footer padding 应用：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt:105`
  - 信息位（time/battery/page等）绑定：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt:157`
  - 点击坐标扣除 `headerHeight`，避免触控错位：`/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt:401`

### 3.2 正文可视区计算（避免底部遮挡的关键）
- `ChapterProvider.upLayout()` 用正文 `paddingTop/Bottom/Left/Right` 计算可视区域：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt:1009`
- 可视高度直接扣除上下 padding：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt:1019`
- 当边距设置异常时有 fallback，避免正文被挤没：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt:1023`

### 3.3 配置项默认值（包含 header/footer/padding）
- `ReadBookConfig.Config` 默认字段：
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt:548`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt:560`
  - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt:574`

## 4. 我们 Flutter 当前对应点（当前仓库）

### 4.1 已有“界面/设置”分入口
- 底部栏分流为 `initialTab: interface/reading`：
  - `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:3622`
  - `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:3643`

### 4.2 当前“界面”与“阅读设置”仍是纵向分组，不是“上方Tab行 + 统一滑条组”
- 设置弹层入口与分组：
  - `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:5557`
- 当前字号/字体行：
  - `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:6062`
- 当前字距滑条：
  - `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:6449`

### 4.3 字体选择当前已是独立底部弹框
- `openFontPickerSheet`：
  - `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart:5673`
- 该部分可与“上方 tab 行”整合（点击“字体”按钮后拉起），不冲突。

## 5. 落地到 Flutter 的最小可执行改造建议

1. 新增一个可复用组件（建议名 `ReaderDetailSliderRow`）  
结构直接对齐 `DetailSeekBar`：左标题、减号、中间 `Slider`、加号、右值文本。

2. 在“界面”弹层顶部新增一行“Tab样式按钮”  
按钮建议：`中/粗/细`、`字体`、`缩进`、`简/繁`、`边距`、`信息`。  
其中 `字体/边距/信息` 分别打开对应子弹层。

3. 把 `字号/字距/行距/段距` 聚合成一组连续滑条  
视觉上和截图一致，减少当前分散在不同分组里的跳转成本。

4. 单独补全“信息(页眉页脚)”配置  
至少要有：
- header/footer 显隐
- header/footer 文案位（时间、电量、章节、进度）
- header/footer padding

5. 用“正文可视区 = 总高度 - header/footer占位 - 正文padding”统一计算  
避免再出现“底部遮挡正文”。

## 6. 备注

- 你之前提到的文档 `docs/legado_reader_page_ui_features_2026-03-05.md`，我在当前仓库未检索到同名文件。  
- 本文档是基于你本地存在的两个仓库现状做的最新实现映射。
