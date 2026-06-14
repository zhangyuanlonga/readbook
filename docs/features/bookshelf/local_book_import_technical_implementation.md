# 本地图书导入 - 技术实现建议

**文档类型**: 技术实现方案  
**创建日期**: 2026-06-14  
**关联文档**: local_book_import_ux_optimization_2026_06_14.md  
**目标**: 提升性能、代码质量、用户体验

---

## 🎯 核心优化方向

### 1. 快速预览模式（P0 核心优化）

**目标**: 2秒内可开始阅读

#### 技术方案

**TXT 文件快速预览**
```dart
// 推荐库: dart:io (原生即可)
class TxtQuickPreview {
  // 只读取前 50KB 作为预览
  Future<String> extractPreview(File file) async {
    const previewSize = 50 * 1024; // 50KB
    final bytes = await file.openRead(0, previewSize).first;
    return utf8.decode(bytes, allowMalformed: true);
  }
}
```

**EPUB 快速预览**
```yaml
# 推荐库
dependencies:
  # 轻量级 EPUB 解析
  epub_view: ^3.2.0  # 或者自建轻量解析器
```

```dart
class EpubQuickPreview {
  // 只解析 OPF 和前 3 章
  Future<PreviewData> extractPreview(File file) async {
    // 1. 解析 OPF 获取元数据
    final metadata = await parseOPF(file);
    
    // 2. 只解析前 3 章内容
    final chapters = await parseFirstNChapters(file, 3);
    
    return PreviewData(
      metadata: metadata,
      previewChapters: chapters,
      totalChapters: metadata.chapterCount,
    );
  }
}
```

**推荐实现策略**:
```dart
// 使用 Isolate 后台解析，避免阻塞 UI
import 'dart:isolate';

Future<PreviewData> parseInBackground(String filePath) async {
  return await compute(_parsePreviewIsolate, filePath);
}

static PreviewData _parsePreviewIsolate(String path) {
  // 在独立 Isolate 中解析
  // 避免阻塞主线程
}
```

---

### 2. 编码检测优化（P1 性能优化）

**当前问题**: 24KB 采样检测编码，可能耗时 1-2 秒

#### 推荐库

```yaml
dependencies:
  # 高性能编码检测（Rust 实现）
  charset_detector: ^2.2.0
  
  # 或使用现有的
  flutter_charset_detector_android: ^1.0.0  # 已有
```

#### 优化方案

**方案 A: 流式检测**（推荐）
```dart
import 'package:charset_detector/charset_detector.dart';

class StreamCharsetDetector {
  Future<String?> detectFast(File file) async {
    // 只读取前 8KB，足够检测编码
    final stream = file.openRead(0, 8 * 1024);
    final detector = CharsetDetector();
    
    await for (var chunk in stream) {
      detector.feed(chunk);
      if (detector.confidence > 0.8) {
        // 置信度够高，提前返回
        return detector.charset;
      }
    }
    
    return detector.result();
  }
}
```

**方案 B: 延迟转换**
```dart
// 不在导入时转换，在阅读时按需转换
class LazyEncodingConverter {
  Future<String> readChapterWithEncoding(
    File file, 
    int start, 
    int end,
    String? detectedCharset,
  ) async {
    final bytes = await file.openRead(start, end).first;
    
    // 按需转换编码
    if (detectedCharset != null && detectedCharset != 'utf-8') {
      return convertEncoding(bytes, detectedCharset);
    }
    
    return utf8.decode(bytes);
  }
}
```

---

### 3. 批量导入并行优化（P0 核心体验）

#### 推荐方案

```dart
import 'package:async/async.dart';  // 推荐库

class ParallelImportQueue {
  // 使用 StreamQueue 控制并发
  Future<List<ImportResult>> importBatch(List<File> files) async {
    // 1. 按文件大小和格式排序（优先小文件）
    final sorted = _prioritizeFiles(files);
    
    // 2. 并行验证（快速阶段）
    final validations = await Future.wait(
      sorted.map((f) => _validateFile(f)),
      eagerError: false,
    );
    
    // 3. 并行存储（I/O 密集）
    final storagePool = Pool(3); // 最多 3 个并行
    final stored = await Future.wait(
      validations.where((v) => v.valid).map((v) => 
        storagePool.withResource(() => _storeFile(v.file))
      ),
    );
    
    // 4. 串行持久化（数据库写入）
    for (final s in stored) {
      await _persistToDb(s);
    }
    
    // 5. 后台批量索引
    unawaited(_batchIndexInBackground(stored.map((s) => s.bookId)));
    
    return stored;
  }
}
```

**推荐库**: 
```yaml
dependencies:
  async: ^2.11.0  # Pool 并发控制
```

---

### 4. 索引进度实时反馈（P0 用户体验）

#### 推荐方案

```dart
// 使用 Stream 实时反馈进度
class IndexProgressStream {
  final _controller = StreamController<IndexProgress>.broadcast();
  
  Stream<IndexProgress> get progressStream => _controller.stream;
  
  Future<void> indexWithProgress(String bookId) async {
    try {
      // 开始索引
      _emit(IndexProgress(
        bookId: bookId,
        stage: IndexStage.parsing,
        current: 0,
        total: null,  // 未知总数
        message: '正在解析文件结构...',
      ));
      
      final chapters = await _parseChapters(bookId);
      
      // 开始处理章节
      for (var i = 0; i < chapters.length; i++) {
        _emit(IndexProgress(
          bookId: bookId,
          stage: IndexStage.indexing,
          current: i + 1,
          total: chapters.length,
          message: '正在处理第 ${i + 1}/${chapters.length} 章...',
          estimatedSeconds: _estimateRemaining(i, chapters.length),
        ));
        
        await _processChapter(chapters[i]);
      }
      
      // 完成
      _emit(IndexProgress(
        bookId: bookId,
        stage: IndexStage.completed,
        current: chapters.length,
        total: chapters.length,
        message: '索引完成',
      ));
    } catch (e) {
      _emit(IndexProgress(
        bookId: bookId,
        stage: IndexStage.failed,
        error: e.toString(),
      ));
    }
  }
  
  void _emit(IndexProgress progress) {
    if (!_controller.isClosed) {
      _controller.add(progress);
    }
  }
}

// UI 层使用
StreamBuilder<IndexProgress>(
  stream: indexService.progressStream,
  builder: (context, snapshot) {
    final progress = snapshot.data;
    if (progress == null) return SizedBox();
    
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.total != null 
            ? progress.current / progress.total! 
            : null,
        ),
        Text(progress.message),
        if (progress.estimatedSeconds != null)
          Text('预计还需 ${progress.estimatedSeconds} 秒'),
      ],
    );
  },
)
```

---

### 5. 存储空间检查（P1 稳定性）

#### 推荐库

```yaml
dependencies:
  # 磁盘空间查询
  disk_space: ^0.2.1
  
  # 或使用
  path_provider: ^2.1.1  # 已有，配合原生方法
```

#### 实现方案

```dart
import 'package:disk_space/disk_space.dart';

class StorageChecker {
  Future<bool> checkBeforeImport(File file) async {
    // 1. 获取可用空间
    final availableSpace = await DiskSpace.getFreeDiskSpace;
    
    // 2. 预估需要空间（文件大小 * 2）
    final fileSize = await file.length();
    final requiredSpace = fileSize * 2;
    
    // 3. 检查
    if (availableSpace! < requiredSpace) {
      throw StorageInsufficientException(
        available: availableSpace,
        required: requiredSpace,
        suggestions: await _getSuggestions(),
      );
    }
    
    return true;
  }
  
  Future<List<String>> _getSuggestions() async {
    // 扫描可清理内容
    final cacheSize = await _calculateCacheSize();
    final oldBooksSize = await _calculateOldBooksSize();
    
    return [
      if (cacheSize > 50 * 1024 * 1024)
        '清理缓存可释放 ${_formatSize(cacheSize)}',
      if (oldBooksSize > 100 * 1024 * 1024)
        '删除 30 天未读的书可释放 ${_formatSize(oldBooksSize)}',
    ];
  }
}
```

---

### 6. 超时保护（P0 稳定性）

#### 实现方案

```dart
class IndexWithTimeout {
  Future<List<LocalChapter>> ensureIndexed({
    required String bookId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    try {
      return await _indexInternal(bookId).timeout(
        timeout,
        onTimeout: () async {
          // 超时处理
          await _updateBookStatus(
            bookId,
            LocalBookIndexStatus.failed,
            lastError: '索引超时（文件过大或格式复杂），请重试',
          );
          
          throw TimeoutException('索引超时');
        },
      );
    } catch (e) {
      // 记录错误日志
      _logger.error('Index failed', error: e, bookId: bookId);
      rethrow;
    }
  }
}
```

---

### 7. 智能重复检测（P1 用户体验）

#### 推荐方案

```dart
import 'package:crypto/crypto.dart';  // 推荐库

class SmartDuplicateDetector {
  // 方案 A: 快速哈希（文件头尾）
  Future<String> calculateQuickHash(File file) async {
    final fileSize = await file.length();
    
    // 读取头 32KB + 尾 32KB
    final headBytes = await file.openRead(0, 32 * 1024).first;
    final tailStart = max(0, fileSize - 32 * 1024);
    final tailBytes = await file.openRead(tailStart, fileSize).first;
    
    // 计算哈希
    final combined = [...headBytes, ...tailBytes];
    final hash = sha256.convert(combined);
    
    return hash.toString();
  }
  
  // 方案 B: 内容指纹（更准确）
  Future<BookFingerprint> calculateFingerprint(File file) async {
    final format = detectFormat(file);
    final size = await file.length();
    final quickHash = await calculateQuickHash(file);
    
    // 提取元数据
    String? title, author;
    if (format == LocalBookFormat.epub) {
      final metadata = await extractEpubMetadata(file);
      title = metadata.title;
      author = metadata.author;
    }
    
    return BookFingerprint(
      quickHash: quickHash,
      format: format,
      size: size,
      title: title,
      author: author,
    );
  }
  
  // 检测重复
  Future<LocalBook?> findDuplicate(BookFingerprint fingerprint) async {
    // 1. 先按 quickHash 查询（快速）
    var existing = await _findByHash(fingerprint.quickHash);
    if (existing != null) return existing;
    
    // 2. 再按元数据查询（模糊匹配）
    if (fingerprint.title != null) {
      existing = await _findByMetadata(
        title: fingerprint.title!,
        author: fingerprint.author,
        sizeTolerance: 0.1,  // 允许 10% 大小差异
      );
    }
    
    return existing;
  }
}
```

**推荐库**:
```yaml
dependencies:
  crypto: ^3.0.3  # SHA256 哈希
```

---

### 8. 错误诊断优化（P1 用户体验）

#### 推荐方案

```dart
class SmartErrorDiagnostics {
  String diagnoseImportError(Object error, File file) {
    // 使用模式匹配提供友好提示
    if (error is FileSystemException) {
      if (error.message.contains('permission')) {
        return '''
❌ 没有读取权限

可能原因:
• 文件位于受保护的目录
• 需要授予存储权限

解决方案:
1. 检查应用权限设置
2. 将文件移动到 Downloads 目录
        ''';
      }
      
      if (error.message.contains('not found')) {
        return '''
❌ 文件不存在或已被删除

解决方案:
1. 确认文件仍在原位置
2. 尝试重新选择文件
        ''';
      }
    }
    
    if (error is FormatException) {
      return '''
❌ 文件格式损坏

可能原因:
• 下载未完成
• 文件被截断或损坏

建议:
1. 重新下载此文件
2. 使用 Calibre 验证文件完整性
      ''';
    }
    
    if (error.toString().contains('OutOfMemory')) {
      return '''
❌ 内存不足

这本书文件过大，设备内存不足以处理

建议:
1. 关闭其他应用释放内存
2. 重启设备后重试
3. 考虑在更高配置设备上导入
      ''';
    }
    
    // 默认友好提示
    return '导入失败，请检查文件是否完整，或联系客服反馈';
  }
}
```

---

## 📦 推荐库总览

### 核心库（必须）

```yaml
dependencies:
  # 并发控制
  async: ^2.11.0
  
  # 加密和哈希
  crypto: ^3.0.3
  
  # 磁盘空间
  disk_space: ^0.2.1  # 或使用 path_provider + 原生
  
  # 编码检测
  charset_detector: ^2.2.0  # 或复用现有
```

### 格式解析库（已有）

```yaml
dependencies:
  # EPUB
  epub: ^4.0.0  # 已有
  
  # PDF
  # pdfium_dart (自建插件) ✅
  
  # Markdown
  markdown: ^7.3.1  # 已有
  
  # HTML
  html: ^0.15.5  # 已有
  
  # MOBI/AZW
  dart_mobi: ^1.0.2  # 已有
```

---

## ⚡ 性能优化建议

### 1. 使用 Isolate 隔离计算密集任务

```dart
import 'dart:isolate';
import 'package:flutter/foundation.dart';

// 推荐使用 compute 函数（自动管理 Isolate）
Future<ParsedBook> parseBookInBackground(String path) async {
  return await compute(_parseBookIsolate, path);
}

static ParsedBook _parseBookIsolate(String path) {
  // CPU 密集型操作在独立 Isolate
  // 不阻塞 UI 线程
}
```

### 2. 使用流式读取大文件

```dart
// ❌ 错误：一次性读取全部
final allBytes = await file.readAsBytes();  // OOM 风险

// ✅ 正确：流式读取
await for (var chunk in file.openRead()) {
  processChunk(chunk);
}
```

### 3. 数据库批量写入

```dart
import 'package:drift/drift.dart';

// ✅ 使用 batch 批量插入
Future<void> insertChaptersBatch(List<LocalChapter> chapters) async {
  await db.batch((batch) {
    for (final chapter in chapters) {
      batch.insert(db.localChapters, chapter);
    }
  });
}
```

---

## 🎯 代码质量提升

### 1. 使用 sealed class 替代 enum（Dart 3+）

```dart
// ✅ 推荐：sealed class（类型安全 + 携带数据）
sealed class ImportResult {}

class ImportSuccess extends ImportResult {
  final LocalBook book;
  ImportSuccess(this.book);
}

class ImportFailure extends ImportResult {
  final String reason;
  final List<String> solutions;
  ImportFailure(this.reason, this.solutions);
}

// 使用时编译器强制处理所有情况
ImportResult result = await importBook();
switch (result) {
  case ImportSuccess(:final book):
    print('成功: ${book.title}');
  case ImportFailure(:final reason, :final solutions):
    print('失败: $reason');
}
```

### 2. 使用 Result 类型处理错误

```dart
// 推荐库
dependencies:
  result_type: ^0.2.0
  # 或
  dartz: ^0.10.1  # 函数式编程

// 使用示例
import 'package:result_type/result_type.dart';

Future<Result<LocalBook, ImportError>> importBook(String path) async {
  try {
    final book = await _import(path);
    return Success(book);
  } catch (e) {
    return Failure(ImportError.fromException(e));
  }
}

// 调用侧
final result = await importBook(path);
result.when(
  success: (book) => print('导入成功'),
  failure: (error) => showError(error.message),
);
```

### 3. 使用 freezed 生成不可变数据类

```yaml
# 已有
dependencies:
  freezed_annotation: ^2.4.1
dev_dependencies:
  freezed: ^2.4.5
  build_runner: ^2.4.6
```

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_progress.freezed.dart';

@freezed
class ImportProgress with _$ImportProgress {
  const factory ImportProgress({
    required String bookId,
    required ImportStage stage,
    required int current,
    int? total,
    String? message,
    int? estimatedSeconds,
  }) = _ImportProgress;
}

// 自动生成 copyWith、==、hashCode、toString
```

---

## 🧪 测试建议

### 单元测试关键函数

```dart
// test/features/bookshelf/local_book_import_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('LocalBookImportService', () {
    test('should detect duplicate by hash', () async {
      // Arrange
      final service = LocalBookImportService(...);
      final file = File('test_book.epub');
      
      // Act
      final hash = await service.calculateHash(file);
      final duplicate = await service.findDuplicate(hash);
      
      // Assert
      expect(duplicate, isNotNull);
    });
    
    test('should throw when storage insufficient', () async {
      // Arrange
      when(mockDiskSpace.getFreeDiskSpace())
        .thenAnswer((_) => Future.value(10 * 1024 * 1024));  // 10MB
      
      // Act & Assert
      expect(
        () => service.importBook(largeFile),  // 50MB file
        throwsA(isA<StorageInsufficientException>()),
      );
    });
  });
}
```

---

## 📊 性能指标目标

| 指标 | 当前 | 目标 | 方案 |
|------|------|------|------|
| 导入响应 | 2s | < 500ms | 快速预览 |
| 编码检测 | 1-2s | < 300ms | 流式检测 |
| 批量导入 | 串行 | 并行 3x | Pool 并发 |
| 索引反馈 | 无 | 实时 | Stream |
| 超时保护 | 无 | 5min | timeout() |
| 重复检测 | 基础 | 智能 | 哈希+元数据 |

---

**文档状态**: ✅ 技术实现建议完成  
**下一步**: 根据优先级逐步实施
