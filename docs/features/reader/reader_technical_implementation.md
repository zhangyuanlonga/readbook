# 阅读器核心 - 技术实现建议

**文档类型**: 技术实现方案  
**创建日期**: 2026-06-14  
**关联文档**: reader_optimization_plan.md  
**目标**: 提升性能、代码质量、用户体验

---

## 🎯 核心优化方向

### 1. 新手引导系统（P0）

#### 推荐库

```yaml
dependencies:
  # 功能引导库
  tutorial_coach_mark: ^1.2.11
  # 或
  showcaseview: ^3.0.0
```

#### 实现方案

```dart
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class ReaderOnboarding {
  TutorialCoachMark? _tutorial;
  
  void showTutorial(BuildContext context) {
    _tutorial = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "跳过",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => _markTutorialComplete(),
      onSkip: () => _markTutorialComplete(),
    );
    
    _tutorial?.show(context: context);
  }
  
  List<TargetFocus> _createTargets() {
    return [
      // 1. 翻页区域
      TargetFocus(
        identify: "page_zone",
        keyTarget: _pageZoneKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "点击左侧上一页，点击右侧下一页",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                SizedBox(height: 16),
                Icon(Icons.touch_app, color: Colors.white, size: 48),
              ],
            ),
          ),
        ],
      ),
      
      // 2. 菜单唤出
      TargetFocus(
        identify: "menu",
        keyTarget: _menuZoneKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => Text(
              "点击中间唤出菜单",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
    ];
  }
}
```

**更轻量的自建方案**:
```dart
// 如果不想引入库，自建轻量版
class SimpleOverlayGuide {
  static void show(BuildContext context, List<GuideStep> steps) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GuideOverlay(steps: steps),
    );
  }
}

class _GuideOverlay extends StatefulWidget {
  final List<GuideStep> steps;
  const _GuideOverlay({required this.steps});
  
  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay> {
  int _currentStep = 0;
  
  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    
    return Stack(
      children: [
        // 半透明遮罩
        Container(color: Colors.black54),
        
        // 高亮区域（镂空）
        CustomPaint(
          painter: _HolePainter(step.highlightRect),
          child: Container(),
        ),
        
        // 提示文本
        Positioned(
          top: step.messagePosition.dy,
          left: step.messagePosition.dx,
          child: _GuideMessage(
            message: step.message,
            onNext: _nextStep,
            onSkip: () => Navigator.pop(context),
            currentStep: _currentStep + 1,
            totalSteps: widget.steps.length,
          ),
        ),
      ],
    );
  }
  
  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      Navigator.pop(context);
    }
  }
}
```

---

### 2. 双指缩放调整字号（P1）

#### 实现方案（无需额外库）

```dart
class ZoomableReader extends StatefulWidget {
  @override
  State<ZoomableReader> createState() => _ZoomableReaderState();
}

class _ZoomableReaderState extends State<ZoomableReader> {
  double _currentFontSize = 18.0;
  double _baseFontSize = 18.0;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 双指缩放手势
      onScaleStart: (details) {
        _baseFontSize = _currentFontSize;
      },
      onScaleUpdate: (details) {
        setState(() {
          // 根据缩放比例调整字号
          _currentFontSize = (_baseFontSize * details.scale).clamp(12.0, 36.0);
        });
        
        // 实时预览（可选：使用防抖）
        _updateFontSizeDebounced(_currentFontSize);
      },
      onScaleEnd: (details) {
        // 保存最终字号
        _saveFontSize(_currentFontSize);
      },
      child: ReaderContent(fontSize: _currentFontSize),
    );
  }
  
  Timer? _debounceTimer;
  void _updateFontSizeDebounced(double size) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 100), () {
      // 更新设置
      ref.read(readerSettingsProvider.notifier).updateFontSize(size);
    });
  }
}
```

**推荐：防抖库**
```yaml
dependencies:
  easy_debounce: ^2.0.3
```

```dart
import 'package:easy_debounce/easy_debounce.dart';

void _updateFontSizeDebounced(double size) {
  EasyDebounce.debounce(
    'font-size',
    Duration(milliseconds: 100),
    () => ref.read(readerSettingsProvider.notifier).updateFontSize(size),
  );
}
```

---

### 3. 日夜间自动切换（P1）

#### 推荐库

```yaml
dependencies:
  # 环境光感应
  light_sensor: ^0.0.3  # Android only
  
  # 或使用现有的
  battery_plus: ^5.0.2  # 已有，可获取充电状态
```

#### 实现方案

```dart
class AutoThemeSwitcher {
  Timer? _timer;
  StreamSubscription? _lightSensorSubscription;
  
  // 方案 A: 基于时间
  void startTimeBasedSwitch({
    required TimeOfDay nightStart,
    required TimeOfDay nightEnd,
  }) {
    _timer = Timer.periodic(Duration(minutes: 1), (_) {
      final now = TimeOfDay.now();
      final shouldBeNight = _isInNightTime(now, nightStart, nightEnd);
      final currentTheme = ref.read(readerThemeProvider);
      
      if (shouldBeNight && !currentTheme.isDark) {
        _switchToNightMode();
      } else if (!shouldBeNight && currentTheme.isDark) {
        _switchToDayMode();
      }
    });
  }
  
  // 方案 B: 基于环境光（Android）
  void startAmbientLightSwitch() {
    _lightSensorSubscription = LightSensor.lightSensorStream.listen((lux) {
      // lux < 10: 很暗，切换夜间
      // lux > 50: 明亮，切换日间
      if (lux < 10) {
        _switchToNightMode();
      } else if (lux > 50) {
        _switchToDayMode();
      }
    });
  }
  
  // 方案 C: 跟随系统（推荐）
  void followSystemTheme() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    if (brightness == Brightness.dark) {
      _switchToNightMode();
    } else {
      _switchToDayMode();
    }
  }
  
  void dispose() {
    _timer?.cancel();
    _lightSensorSubscription?.cancel();
  }
}
```

**平滑切换动画**（已有）:
```dart
// 使用现有的 CircularThemeReveal
import 'package:circular_theme_reveal/circular_theme_reveal.dart';

void _switchThemeAnimated(Offset tapPosition) {
  setState(() {
    _isDark = !_isDark;
    
    // 圆形扩散动画
    CircularThemeReveal.reveal(
      context: context,
      center: tapPosition,
      duration: Duration(milliseconds: 600),
      theme: _isDark ? _darkTheme : _lightTheme,
    );
  });
}
```

---

### 4. 智能章节缓存（P1）

#### 推荐策略

```dart
class SmartChapterCache {
  // 基于网络状况和存储空间的智能策略
  int _calculatePreloadRange() {
    final networkType = _getNetworkType();
    final availableStorage = _getAvailableStorage();
    
    // 决策矩阵
    return switch ((networkType, availableStorage)) {
      (NetworkType.wifi, > 1GB) => 5,      // WiFi + 充足空间 = 激进
      (NetworkType.wifi, _) => 3,          // WiFi + 紧张空间 = 适中
      (NetworkType.mobile, > 1GB) => 3,    // 移动网络 + 充足 = 适中
      (NetworkType.mobile, _) => 1,        // 移动网络 + 紧张 = 保守
      (NetworkType.none, _) => 0,          // 无网络 = 不预加载
    };
  }
  
  // 基于阅读速度的预测
  Future<void> predictivePreload(String currentChapterId) async {
    // 计算用户阅读速度
    final readingSpeed = _calculateReadingSpeed();
    
    // 预估还需多久读完当前章
    final remainingTime = _estimateRemainingTime(currentChapterId, readingSpeed);
    
    // 如果剩余时间 < 3 分钟，开始预加载
    if (remainingTime < Duration(minutes: 3)) {
      final nextChapterId = _getNextChapterId(currentChapterId);
      unawaited(_preloadChapter(nextChapterId));
    }
  }
  
  // LRU 缓存清理
  Future<void> cleanup() async {
    final cached = await _getCachedChapters();
    
    // 按最后访问时间排序
    cached.sort((a, b) => a.lastAccessTime.compareTo(b.lastAccessTime));
    
    // 保留最近 20 章，删除其余
    if (cached.length > 20) {
      final toDelete = cached.take(cached.length - 20);
      await _deleteCachedChapters(toDelete);
    }
  }
}
```

**推荐库**:
```yaml
dependencies:
  # 网络状态检测
  connectivity_plus: ^5.0.2
  
  # LRU 缓存实现
  lru_cache: ^1.0.0  # 或自建
```

---

### 5. 章节无缝切换（P1）

#### 预渲染方案

```dart
class SeamlessChapterTransition {
  // 预渲染池（最多 2 个）
  final Map<String, RenderedChapter> _prerenderPool = {};
  
  Future<void> prerenderNext(String currentChapterId) async {
    final nextId = _getNextChapterId(currentChapterId);
    
    // 如果已经在预渲染，跳过
    if (_prerenderPool.containsKey(nextId)) return;
    
    // 在后台 Isolate 中预渲染
    final rendered = await compute(_renderChapterIsolate, RenderParams(
      chapterId: nextId,
      fontSize: _currentFontSize,
      lineHeight: _currentLineHeight,
      pageWidth: _pageWidth,
    ));
    
    _prerenderPool[nextId] = rendered;
    
    // 限制池大小
    if (_prerenderPool.length > 2) {
      final oldest = _prerenderPool.keys.first;
      _prerenderPool.remove(oldest);
    }
  }
  
  // Isolate 渲染函数
  static RenderedChapter _renderChapterIsolate(RenderParams params) {
    // 1. 解析章节内容
    final content = parseChapterContent(params.chapterId);
    
    // 2. 应用样式
    final styled = applyStyles(content, params.fontSize, params.lineHeight);
    
    // 3. 分页计算
    final pages = calculatePages(styled, params.pageWidth);
    
    // 4. 图片预解码
    final decodedImages = preDecodeImages(pages);
    
    return RenderedChapter(
      chapterId: params.chapterId,
      pages: pages,
      images: decodedImages,
    );
  }
  
  // 切换章节（无感知）
  void switchToNext(String currentId) {
    final nextId = _getNextChapterId(currentId);
    final prerendered = _prerenderPool[nextId];
    
    if (prerendered != null) {
      // 直接使用预渲染内容（< 50ms）
      setState(() {
        _currentChapter = prerendered;
      });
    } else {
      // 降级：显示加载中
      _loadChapterNormally(nextId);
    }
    
    // 预渲染下下章
    unawaited(prerenderNext(nextId));
  }
}
```

---

### 6. PDF 流式加载（P2）

#### 推荐方案

```dart
// 使用现有的 pdfium_dart + 虚拟列表
class PdfStreamViewer extends StatelessWidget {
  final String pdfPath;
  final int totalPages;
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 虚拟列表，只渲染可见项
      itemCount: totalPages,
      itemBuilder: (context, pageIndex) {
        return _PdfPageWidget(
          pdfPath: pdfPath,
          pageIndex: pageIndex,
        );
      },
    );
  }
}

class _PdfPageWidget extends StatefulWidget {
  final String pdfPath;
  final int pageIndex;
  
  @override
  State<_PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends State<_PdfPageWidget> 
    with AutomaticKeepAliveClientMixin {
  ui.Image? _renderedImage;
  bool _isRendering = false;
  
  @override
  bool get wantKeepAlive => _renderedImage != null;  // 保持已渲染页面
  
  @override
  void initState() {
    super.initState();
    // 延迟渲染（进入视口时）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renderPage();
    });
  }
  
  Future<void> _renderPage() async {
    if (_isRendering) return;
    
    setState(() => _isRendering = true);
    
    // 在 Isolate 中渲染 PDF 页面
    _renderedImage = await compute(_renderPdfPageIsolate, RenderPdfParams(
      pdfPath: widget.pdfPath,
      pageIndex: widget.pageIndex,
      width: MediaQuery.of(context).size.width.toInt(),
    ));
    
    if (mounted) {
      setState(() => _isRendering = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);  // AutomaticKeepAliveClientMixin
    
    if (_renderedImage != null) {
      return RawImage(image: _renderedImage);
    }
    
    if (_isRendering) {
      return Center(child: CircularProgressIndicator());
    }
    
    return SizedBox(height: 800);  // 占位
  }
}
```

**性能优化**:
```dart
// 图片内存缓存管理
class PdfImageCache {
  static const maxCacheSize = 50 * 1024 * 1024;  // 50MB
  final Map<int, ui.Image> _cache = {};
  int _currentSize = 0;
  
  void put(int pageIndex, ui.Image image) {
    final imageSize = image.width * image.height * 4;  // RGBA
    
    // 如果超出限制，清理旧缓存
    while (_currentSize + imageSize > maxCacheSize && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final oldImage = _cache.remove(oldestKey)!;
      _currentSize -= oldImage.width * oldImage.height * 4;
      oldImage.dispose();
    }
    
    _cache[pageIndex] = image;
    _currentSize += imageSize;
  }
  
  ui.Image? get(int pageIndex) => _cache[pageIndex];
}
```

---

### 7. 高质量 TTS（P2）

#### 推荐方案

```yaml
dependencies:
  # 讯飞语音（国内首选）
  # 需要自己封装或使用第三方插件
  
  # Google TTS（国外）
  flutter_tts: ^4.0.2
  
  # 本地 TTS（备用）
  # 系统自带
```

#### 实现方案

```dart
import 'package:flutter_tts/flutter_tts.dart';

class HighQualityTTS {
  final FlutterTts _tts = FlutterTts();
  
  Future<void> initialize() async {
    // 配置高质量参数
    await _tts.setLanguage("zh-CN");
    await _tts.setSpeechRate(0.5);  // 语速：0.5-2.0
    await _tts.setVolume(1.0);      // 音量：0.0-1.0
    await _tts.setPitch(1.0);       // 音调：0.5-2.0
    
    // 选择音色（如果支持）
    final voices = await _tts.getVoices;
    final femaleVoice = voices.firstWhere(
      (v) => v['name'].contains('female'),
      orElse: () => voices.first,
    );
    await _tts.setVoice(femaleVoice);
    
    // 监听播放状态
    _tts.setCompletionHandler(() {
      _onChapterCompleted();
    });
  }
  
  Future<void> speakChapter(String content) async {
    // 分段朗读（避免太长）
    final sentences = _splitIntoSentences(content);
    
    for (final sentence in sentences) {
      await _tts.speak(sentence);
      await _waitForCompletion();
    }
  }
  
  // 定时关闭
  void setTimer(Duration duration) {
    Timer(duration, () async {
      // 音量渐弱
      for (var i = 10; i >= 0; i--) {
        await _tts.setVolume(i / 10);
        await Future.delayed(Duration(milliseconds: 500));
      }
      await _tts.stop();
    });
  }
}
```

**推荐集成讯飞语音**（更高质量）:
```dart
// 需要自建插件或使用社区插件
// https://pub.dev/packages/xf_tts  （示例）

class XunfeiTTS {
  // 讯飞语音 SDK 封装
  // 支持更自然的语音合成
  // 支持多音色
  // 支持情感朗读（需付费）
}
```

---

### 8. 性能监控和优化

#### 推荐库

```yaml
dependencies:
  # 性能监控
  performance: ^0.2.0
  
  # FPS 监控
  fps_monitor: ^1.0.0
  
  # 内存监控
  # 使用 DevTools 或自建
```

#### 实现方案

```dart
class ReaderPerformanceMonitor {
  final _pageFlipDurations = <Duration>[];
  final _chapterLoadDurations = <Duration>[];
  
  // 监控翻页性能
  Future<T> measurePageFlip<T>(Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _pageFlipDurations.add(stopwatch.elapsed);
      
      // 如果翻页超过 200ms，记录慢日志
      if (stopwatch.elapsedMilliseconds > 200) {
        _logger.warn('Slow page flip: ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }
  
  // 生成性能报告
  PerformanceReport generateReport() {
    return PerformanceReport(
      avgPageFlipMs: _calculateAverage(_pageFlipDurations),
      p95PageFlipMs: _calculatePercentile(_pageFlipDurations, 0.95),
      avgChapterLoadMs: _calculateAverage(_chapterLoadDurations),
      slowFlips: _pageFlipDurations.where((d) => d.inMilliseconds > 200).length,
    );
  }
}
```

---

## 📦 推荐库总览

### UI 交互库

```yaml
dependencies:
  # 新手引导
  tutorial_coach_mark: ^1.2.11
  # 或 showcaseview: ^3.0.0
  
  # 防抖
  easy_debounce: ^2.0.3
  
  # 主题切换动画（已有）
  circular_theme_reveal: ^1.0.0  ✅
```

### 功能增强库

```yaml
dependencies:
  # TTS 语音
  flutter_tts: ^4.0.2
  
  # 网络状态
  connectivity_plus: ^5.0.2  ✅
  
  # 环境光传感器（可选）
  light_sensor: ^0.0.3  # Android only
```

### 性能优化库

```yaml
dependencies:
  # LRU 缓存
  lru_cache: ^1.0.0
  
  # 性能监控
  performance: ^0.2.0
```

---

## ⚡ 性能优化核心原则

### 1. RepaintBoundary 隔离

```dart
// ✅ 隔离频繁变化的部分
RepaintBoundary(
  child: PageContent(),  // 翻页时只重绘这部分
)

RepaintBoundary(
  child: ReaderChrome(),  // 菜单栏独立重绘
)
```

### 2. const 构造函数

```dart
// ✅ 尽可能使用 const
const Text('章节标题')
const Icon(Icons.menu)
const SizedBox(height: 16)
```

### 3. ListView.builder 虚拟列表

```dart
// ✅ 长列表使用 builder
ListView.builder(
  itemCount: chapters.length,
  itemBuilder: (context, index) => ChapterTile(chapters[index]),
)

// ❌ 避免一次性构建全部
// ListView(children: chapters.map((c) => ChapterTile(c)).toList())
```

### 4. 图片缓存和预加载

```dart
// ✅ 预加载图片
precacheImage(NetworkImage(imageUrl), context);

// ✅ 使用 cached_network_image（如果是网络图片）
dependencies:
  cached_network_image: ^3.3.1
```

---

## 🧪 测试建议

### 性能测试

```dart
// test/performance/reader_performance_test.dart
void main() {
  testWidgets('page flip should complete in 100ms', (tester) async {
    await tester.pumpWidget(ReaderPage());
    
    final stopwatch = Stopwatch()..start();
    
    // 模拟翻页
    await tester.tap(find.byKey(Key('next_page')));
    await tester.pumpAndSettle();
    
    stopwatch.stop();
    
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });
}
```

### 集成测试

```dart
// integration_test/reader_flow_test.dart
void main() {
  testWidgets('complete reading flow', (tester) async {
    // 1. 打开书籍
    await tester.tap(find.text('三体'));
    await tester.pumpAndSettle();
    
    // 2. 翻页
    await tester.tap(find.byKey(Key('page_right')));
    await tester.pumpAndSettle();
    
    // 3. 调整字号
    await tester.tap(find.byKey(Key('font_size_plus')));
    await tester.pumpAndSettle();
    
    // 4. 验证状态
    expect(find.text('第一章'), findsOneWidget);
  });
}
```

---

## 📊 性能指标目标

| 指标 | 当前 | 目标 | 实现方案 |
|------|------|------|---------|
| 翻页响应 | 100ms | < 50ms | RepaintBoundary + 预计算 |
| 章节切换 | 300ms | < 50ms | 预渲染 |
| 字号调整 | 200ms | 实时 | 双指缩放 + 防抖 |
| 主题切换 | 即时 | 动画 | CircularThemeReveal |
| 内存占用 | - | < 150MB | 图片缓存限制 + 虚拟列表 |
| 首屏加载 | 300ms | < 200ms | 优化初始化 |

---

## 🎯 代码质量提升

### 使用状态管理最佳实践

```dart
// ✅ 推荐：细粒度 Provider
final fontSizeProvider = StateProvider<double>((ref) => 18.0);
final lineHeightProvider = StateProvider<double>((ref) => 1.5);
final themeProvider = StateProvider<ReaderTheme>((ref) => ReaderTheme.default);

// Consumer 只监听需要的状态
Consumer(
  builder: (context, ref, child) {
    final fontSize = ref.watch(fontSizeProvider);
    return Text('内容', style: TextStyle(fontSize: fontSize));
  },
)

// ❌ 避免：粗粒度状态
final readerStateProvider = StateProvider<ReaderState>(...);  // 包含所有状态
// 任何状态变化都会导致全局 rebuild
```

### 使用 CustomPainter 优化渲染

```dart
// 自定义绘制翻页动画
class PageFlipPainter extends CustomPainter {
  final double progress;
  final ui.Image? currentPage;
  final ui.Image? nextPage;
  
  @override
  void paint(Canvas canvas, Size size) {
    // 自定义绘制翻页效果
    // 比 Widget 树更高效
  }
  
  @override
  bool shouldRepaint(PageFlipPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
```

---

**文档状态**: ✅ 技术实现建议完成  
**下一步**: 根据优先级逐步实施
