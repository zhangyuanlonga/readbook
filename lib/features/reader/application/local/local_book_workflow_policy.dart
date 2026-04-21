import '../../../../domain/entities/local_book.dart';

enum LocalBookImportExecutionMode { backgroundIndex, immediateIndex }

class LocalBookWorkflowPolicy {
  const LocalBookWorkflowPolicy._();

  static LocalBookImportExecutionMode resolveImportExecutionMode({
    required LocalBookFormat format,
    required bool waitForIndexingRequested,
  }) {
    if (waitForIndexingRequested || !format.supportsBackgroundIndexOnImport) {
      return LocalBookImportExecutionMode.immediateIndex;
    }
    return LocalBookImportExecutionMode.backgroundIndex;
  }

  static String importSuccessMessage({
    required int successCount,
    required int failureCount,
  }) {
    if (failureCount > 0) {
      return '已导入 $successCount 本书并加入书架，失败 $failureCount 本。后台会继续解析成功导入的图书。';
    }
    return '已导入 $successCount 本书并加入书架。后台会继续解析。';
  }

  static String statusLabel(LocalBookIndexStatus status) => switch (status) {
    LocalBookIndexStatus.pending => '待建立',
    LocalBookIndexStatus.indexing => '索引中',
    LocalBookIndexStatus.ready => '已就绪',
    LocalBookIndexStatus.stale => '需重建',
    LocalBookIndexStatus.failed => '失败',
  };

  static String statusHeadline(LocalBook book) => switch (book.indexStatus) {
    LocalBookIndexStatus.pending => '本地图书待建立目录',
    LocalBookIndexStatus.indexing => '本地图书正在解析',
    LocalBookIndexStatus.ready => '本地图书已就绪',
    LocalBookIndexStatus.stale => '本地图书需要重建目录',
    LocalBookIndexStatus.failed => '本地图书目录解析失败',
  };

  static String statusDescription(LocalBook book) {
    return switch (book.indexStatus) {
      LocalBookIndexStatus.pending =>
        '这本${book.format.displayLabel}图书已加入书架，目录解析将在后台继续进行。',
      LocalBookIndexStatus.indexing => '目录和章节正在后台建立，完成后会自动刷新。',
      LocalBookIndexStatus.ready => '当前目录和章节索引可用。',
      LocalBookIndexStatus.stale => '检测到文件或索引状态变化，建议重新索引后再阅读。',
      LocalBookIndexStatus.failed =>
        book.lastError?.trim().isNotEmpty == true
            ? book.lastError!.trim()
            : '建议先重新索引；如果仍失败，再尝试重新导入。',
    };
  }

  static String nonReadyOpenMessage(LocalBook book) {
    return switch (book.indexStatus) {
      LocalBookIndexStatus.pending => '这本本地图书正在等待建立目录，请稍后再试或在详情页重建。',
      LocalBookIndexStatus.indexing => '这本本地图书正在解析中，详情页会自动刷新。',
      LocalBookIndexStatus.stale => '检测到本地图书目录已过期，请先重建目录再阅读。',
      LocalBookIndexStatus.failed => '本地图书目录解析失败，请先重建目录；若仍失败再重新导入。',
      LocalBookIndexStatus.ready => '本地图书已就绪。',
    };
  }

  static String statusActionText(LocalBook book) {
    return switch (book.indexStatus) {
      LocalBookIndexStatus.pending => '状态: 待建立目录，可在此直接触发解析',
      LocalBookIndexStatus.indexing => '状态: 正在解析，可继续等待或重新打开详情查看进度',
      LocalBookIndexStatus.ready => '状态: 已完成解析，可直接阅读',
      LocalBookIndexStatus.stale => '状态: 目录需重建，建议先重建再阅读',
      LocalBookIndexStatus.failed =>
        book.lastError?.trim().isNotEmpty == true
            ? '状态: 解析失败，${_toSingleLineText(book.lastError!)}'
            : '状态: 解析失败，建议先重建目录；若仍失败再重新导入',
    };
  }

  static String userReadableLoadError(String message) {
    if (message.contains('本地文件不存在') || message.contains('未找到本地书籍')) {
      return '未找到本地书籍，请确认文件是否存在或重新导入。';
    }
    if (message.contains('目录尚未建立完成') || message.contains('正在建立目录')) {
      return '本地图书正在解析，请稍后再试。';
    }
    if (message.contains('目录已过期')) {
      return '检测到本地图书目录已过期，请先重建目录。';
    }
    if (message.contains('索引失败')) {
      return '本地书籍索引失败，请先重建目录；如果仍失败，再重新导入。';
    }
    if (message.contains('未解析到可读章节') ||
        message.contains('未找到本地章节内容') ||
        message.contains('本地章节正文缺失')) {
      return '未解析到可读正文，请先重建目录；若仍失败再重新导入。';
    }
    if (message.contains('文本文件为空') || message.contains('文本内容为空')) {
      return '本地文件内容为空，无法阅读。';
    }
    if (message.contains('暂不支持')) {
      return '本地文件格式不受支持，请重新导入。';
    }
    if (message.contains('本地书籍信息缺失') || message.contains('bookId')) {
      return '本地书籍信息缺失，请重新进入或重新导入。';
    }
    return '本地书籍加载失败，请先重建目录；若仍失败再重新导入。';
  }

  static String tocWarningText(String message) {
    if (message.contains('未找到本地书籍')) {
      return '本地书籍不存在，目录暂不可用。';
    }
    if (message.contains('索引失败')) {
      return '目录解析失败，请重建目录；若仍失败再重新导入。';
    }
    if (message.contains('未解析到可读章节') ||
        message.contains('未找到本地章节内容') ||
        message.contains('本地章节正文缺失')) {
      return '未解析到可读章节，请先重建目录。';
    }
    return '目录解析失败，请重建目录。';
  }

  static String readerLoadError(String message) {
    if (message.contains('本地文件不存在') || message.contains('未找到本地书籍')) {
      return '未找到本地书籍，请确认文件是否存在或重新导入。';
    }
    if (message.contains('目录尚未建立完成') || message.contains('正在建立目录')) {
      return '本地图书正在解析，请稍后再试。';
    }
    if (message.contains('目录已过期')) {
      return '检测到本地图书目录已过期，请先在详情页重建目录。';
    }
    if (message.contains('索引失败')) {
      return '本地书籍索引失败，请先在详情页重建目录；若仍失败再重新导入。';
    }
    if (message.contains('未解析到可读章节') ||
        message.contains('未找到本地章节内容') ||
        message.contains('本地章节正文缺失')) {
      return '未解析到可读正文，请先在详情页重建目录；若仍失败再重新导入。';
    }
    if (message.contains('文本文件为空') || message.contains('文本内容为空')) {
      return '本地文件内容为空，无法阅读。';
    }
    if (message.contains('暂不支持')) {
      return '本地文件格式不受支持，请重新导入。';
    }
    if (message.contains('本地书籍信息缺失') || message.contains('bookId')) {
      return '本地书籍信息缺失，请重新进入或重新导入。';
    }
    return '本地书籍加载失败，请先在详情页重建目录；若仍失败再重新导入。';
  }

  static String _toSingleLineText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
