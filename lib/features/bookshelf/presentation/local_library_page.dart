import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import '../../source/application/external_import_catalog.dart';
import '../application/bookshelf_reader_open_service.dart';
import '../application/local_book_import_service.dart';
import '../providers.dart';

class LocalLibraryPage extends ConsumerStatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  ConsumerState<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends ConsumerState<LocalLibraryPage> {
  late final LocalBookImportService _localBookImportService;
  late final BookshelfReaderOpenService _readerOpenService;
  late final LocalBookRepository _localBookRepository;
  late final LocalBookIndexService _localBookIndexService;
  StreamSubscription<LocalBookIndexEvent>? _localIndexEventSubscription;

  bool _isImporting = false;
  int _importTotal = 0;
  int _importCompleted = 0;
  String? _currentImportLabel;
  String? _lastErrorText;
  String? _currentStageText;
  LocalBookImportResult? _lastImportedResult;
  ImportExportTaskStatus? _taskStatus;
  LocalBookImportStage? _lastProgressStage;
  PersistentBottomSheetController? _taskSheetController;
  String? _reindexingBookId;
  String? _reindexStatusText;
  String? _reindexErrorText;

  @override
  void initState() {
    super.initState();
    _localBookImportService = ref.read(localBookImportServiceProvider);
    _readerOpenService = ref.read(bookshelfReaderOpenServiceProvider);
    _localBookRepository = ref.read(bookshelfLocalBookRepositoryProvider);
    _localBookIndexService = ref.read(bookshelfLocalBookIndexServiceProvider);
    _localIndexEventSubscription = LocalBookIndexService.watchEvents.listen(
      _handleLocalIndexEvent,
    );
  }

  @override
  void dispose() {
    _taskSheetController?.close();
    _localIndexEventSubscription?.cancel();
    super.dispose();
  }

  void _handleLocalIndexEvent(LocalBookIndexEvent event) {
    if (!mounted || event.bookId != _reindexingBookId) {
      return;
    }
    setState(() {
      _reindexStatusText =
          event.status == LocalBookIndexStatus.ready
              ? '重索引完成，共 ${event.chapterCount} 章'
              : _localIndexStatusLabel(event.status);
      if (event.status == LocalBookIndexStatus.ready ||
          event.status == LocalBookIndexStatus.failed) {
        _reindexingBookId = null;
      }
    });
  }

  Future<void> _pickAndImportFiles() async {
    if (_isImporting) {
      return;
    }
    final localFileImport =
        ref.read(appPlatformCapabilitiesProvider).localFileImport;
    if (!localFileImport.isSupported) {
      _showMessage(localFileImport.reason ?? '当前平台暂不支持从本地文件选择器导入。');
      return;
    }

    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        ExternalImportCatalog.localBookTypeGroup,
      ],
      confirmButtonText: '选择本地图书',
    );

    if (!mounted || files.isEmpty) {
      return;
    }

    setState(() {
      _isImporting = true;
      _importTotal = files.length;
      _importCompleted = 0;
      _currentImportLabel = null;
      _currentStageText = '正在准备导入';
      _lastErrorText = null;
      _lastImportedResult = null;
      _lastProgressStage = null;
      _taskStatus = ImportExportTaskStatus(
        title: '正在导入本地图书',
        message: '正在准备处理 ${files.length} 个文件…',
        detail: '图文内容较多时，解析和提取资源会耗时更久。',
        progress: 0,
        progressLabel: '0/$files.length',
      );
    });
    _showOrRefreshTaskSheet();

    var successCount = 0;
    final failedBooks = <String>[];
    for (final file in files) {
      final filePath = file.path.trim();
      if (filePath.isEmpty) {
        continue;
      }

      try {
        final displayName =
            file.name.trim().isEmpty
                ? Uri.file(filePath).pathSegments.last
                : file.name.trim();
        setState(() {
          _currentImportLabel =
              LocalBookImportService.normalizeImportedDisplayName(displayName);
        });
        final result = await _localBookImportService.importFromFile(
          filePath: filePath,
          displayName: displayName,
          waitForIndexing:
              LocalBookWorkflowPolicy.directImportShouldWaitForIndexing,
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            final nextStage = progress.stage;
            final shouldUpdateStage = _lastProgressStage != nextStage;
            final currentStageText = switch (progress.stage) {
              LocalBookImportStage.preparing => '准备文件',
              LocalBookImportStage.persisted => '写入书架',
              LocalBookImportStage.indexing => '建立目录',
              LocalBookImportStage.completed => '完成导入',
            };
            setState(() {
              _lastProgressStage = nextStage;
              _currentStageText = currentStageText;
              if (shouldUpdateStage || _taskStatus == null) {
                _taskStatus = ImportExportTaskStatus(
                  title: '正在导入本地图书',
                  message:
                      '${progress.displayName} · ${_currentStageText ?? '处理中'}',
                  detail: progress.detail,
                  progress:
                      _importTotal <= 0
                          ? null
                          : _importCompleted / _importTotal,
                  progressLabel:
                      _importTotal <= 0
                          ? null
                          : '$_importCompleted/$_importTotal',
                );
              }
            });
            _showOrRefreshTaskSheet();
          },
        );
        _lastImportedResult = result;
        successCount += 1;
      } on AppException catch (error) {
        failedBooks.add(file.name.trim().isEmpty ? filePath : file.name.trim());
        _lastErrorText = error.briefMessage;
      } catch (error) {
        failedBooks.add(file.name.trim().isEmpty ? filePath : file.name.trim());
        _lastErrorText = '导入失败：$error';
      } finally {
        if (mounted) {
          setState(() {
            _importCompleted += 1;
            if (_isImporting) {
              _taskStatus = ImportExportTaskStatus(
                title: '正在导入本地图书',
                message:
                    _currentImportLabel?.trim().isNotEmpty == true
                        ? '${_currentImportLabel!} · ${_currentStageText ?? '处理中'}'
                        : (_currentStageText ?? '处理中'),
                detail: _taskStatus?.detail,
                progress:
                    _importTotal <= 0 ? null : _importCompleted / _importTotal,
                progressLabel:
                    _importTotal <= 0
                        ? null
                        : '$_importCompleted/$_importTotal',
              );
            }
          });
          _showOrRefreshTaskSheet();
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isImporting = false;
      _currentStageText = successCount > 0 ? '完成导入，可直接阅读' : null;
      _taskStatus =
          successCount > 0
              ? ImportExportTaskStatus(
                title: '本地图书已导入',
                message: '目录已建立，可直接阅读。',
                detail: _currentImportLabel,
                progress: 1,
                progressLabel: '$_importCompleted/$_importTotal',
                result: ImportExportTaskResult.success,
              )
              : null;
    });
    _showOrRefreshTaskSheet();

    if (successCount > 0) {
      final failureCount = failedBooks.length;
      _showMessage(
        LocalBookWorkflowPolicy.localLibraryImportSuccessMessage(
          successCount: successCount,
          failureCount: failureCount,
        ),
      );
      return;
    }

    _showMessage(_lastErrorText ?? '导入失败，请重试。');
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showOrRefreshTaskSheet() {
    if (!mounted) {
      return;
    }
    final status = _taskStatus;
    final scaffold = Scaffold.maybeOf(context);
    if (status == null || scaffold == null) {
      return;
    }
    if (_taskSheetController == null) {
      _taskSheetController = scaffold.showBottomSheet(
        (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return ImportExportTaskSheet(
                status: _taskStatus ?? status,
                primaryAction:
                    !_isImporting && _lastImportedResult != null
                        ? FilledButton.icon(
                          onPressed: _openLatestImportedBook,
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text('立即阅读'),
                        )
                        : null,
                secondaryAction:
                    !_isImporting && _lastImportedResult != null
                        ? OutlinedButton.icon(
                          onPressed: _returnToBookshelf,
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('返回书架'),
                        )
                        : null,
              );
            },
          );
        },
        backgroundColor: Colors.transparent,
        enableDrag: false,
      );
      _taskSheetController!.closed.whenComplete(() {
        if (mounted) {
          _taskSheetController = null;
        }
      });
      return;
    }
    _taskSheetController!.setState?.call(() {});
  }

  void _returnToBookshelf() {
    if (!mounted) {
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }

    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath != '/bookshelf') {
      context.go('/bookshelf');
    }
  }

  Future<void> _openLatestImportedBook() async {
    final result = _lastImportedResult;
    if (result == null || !mounted) {
      return;
    }

    final plan = await _readerOpenService.resolve(
      book: result.bookshelfBook,
      openRequestedAtMs: DateTime.now().millisecondsSinceEpoch,
      localBookHint: result.localBook,
    );
    if (!mounted) {
      return;
    }

    switch (plan.action) {
      case BookshelfReaderOpenAction.openReader:
        final route = plan.readerRoute;
        if (route == null) {
          return;
        }
        context.push(route);
        return;
      case BookshelfReaderOpenAction.openDetail:
        context.push(
          '/local/book/${result.localBook.id}?sourceId=${Uri.encodeComponent(result.bookshelfBook.sourceId)}&detailUrl=${Uri.encodeComponent(result.bookshelfBook.detailUrl)}',
        );
        return;
    }
  }

  Future<void> _reindexBook(LocalBook book) async {
    if (_reindexingBookId != null) {
      return;
    }
    setState(() {
      _reindexingBookId = book.id;
      _reindexStatusText = '正在重索引 ${book.title}';
      _reindexErrorText = null;
    });
    try {
      await _localBookIndexService.ensureIndexed(bookId: book.id, force: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _reindexingBookId = null;
        _reindexStatusText = '重索引完成';
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reindexingBookId = null;
        _reindexErrorText = error.briefMessage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reindexingBookId = null;
        _reindexErrorText = '重索引失败：$error';
      });
    }
  }

  Future<void> _openLocalBook(LocalBook book) async {
    if (!mounted) {
      return;
    }
    context.push('/local/book/${book.id}');
  }

  List<LocalBook> _sortLocalBooks(List<LocalBook> books) {
    final sorted = List<LocalBook>.from(books);
    sorted.sort((a, b) {
      final readyCompare = _localIndexSortRank(
        a.indexStatus,
      ).compareTo(_localIndexSortRank(b.indexStatus));
      if (readyCompare != 0) {
        return readyCompare;
      }
      final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      return a.title.compareTo(b.title);
    });
    return sorted;
  }

  int _localIndexSortRank(LocalBookIndexStatus status) {
    return switch (status) {
      LocalBookIndexStatus.indexing => 0,
      LocalBookIndexStatus.failed => 1,
      LocalBookIndexStatus.stale => 2,
      LocalBookIndexStatus.pending => 3,
      LocalBookIndexStatus.ready => 4,
    };
  }

  String _localIndexStatusLabel(LocalBookIndexStatus status) {
    return switch (status) {
      LocalBookIndexStatus.pending => '等待索引',
      LocalBookIndexStatus.indexing => '正在索引',
      LocalBookIndexStatus.ready => '可阅读',
      LocalBookIndexStatus.stale => '需要重索引',
      LocalBookIndexStatus.failed => '索引失败',
    };
  }

  Color _localIndexStatusColor(
    BuildContext context,
    LocalBookIndexStatus status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      LocalBookIndexStatus.ready => colorScheme.primary,
      LocalBookIndexStatus.indexing => colorScheme.tertiary,
      LocalBookIndexStatus.failed => colorScheme.error,
      LocalBookIndexStatus.pending ||
      LocalBookIndexStatus.stale => colorScheme.secondary,
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '未知大小';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  Widget _buildImportPanel(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final localFileImport = ref.watch(
      appPlatformCapabilitiesProvider.select(
        (capabilities) => capabilities.localFileImport,
      ),
    );
    final supportsImport = localFileImport.isSupported;
    return InkWell(
      onTap: _isImporting || !supportsImport ? null : _pickAndImportFiles,
      borderRadius: BorderRadius.circular(metrics.cardRadius + 6),
      child: Ink(
        padding: EdgeInsets.all(metrics.cardPadding + 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(metrics.cardRadius + 6),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.library_add_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 27,
              ),
            ),
            SizedBox(height: metrics.sectionGap),
            Text(
              '导入本地图书',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: metrics.contentGap * 0.8),
            Text(
              supportsImport
                  ? '支持 TXT、EPUB、Markdown、HTML、PDF；MOBI、AZW、AZW3 为实验支持。导入完成后会建立目录，ready 状态可直接阅读。'
                  : '当前平台暂不支持本地文件选择器。首版可继续浏览已有本地图书、书签、阅读记录和外观设置。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            SizedBox(height: metrics.sectionGap),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isImporting || !supportsImport
                          ? null
                          : _pickAndImportFiles,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _isImporting
                        ? '导入中'
                        : supportsImport
                        ? '选择文件'
                        : '暂不可用',
                  ),
                ),
                if (!_isImporting && _lastImportedResult != null) ...[
                  OutlinedButton.icon(
                    onPressed: _openLatestImportedBook,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('立即阅读'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _returnToBookshelf,
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('返回书架'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryStatusPanel(BuildContext context, List<LocalBook> books) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final readyCount =
        books
            .where((book) => book.indexStatus == LocalBookIndexStatus.ready)
            .length;
    final needsIndexCount =
        books
            .where((book) => book.indexStatus != LocalBookIndexStatus.ready)
            .length;
    final totalBytes = books.fold<int>(0, (sum, book) => sum + book.fileSize);
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '书库状态',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: metrics.contentGap),
          Wrap(
            spacing: metrics.contentGap,
            runSpacing: metrics.contentGap,
            children: [
              _buildStatusChip(context, '总数', '${books.length} 本'),
              _buildStatusChip(context, '可读', '$readyCount 本'),
              _buildStatusChip(context, '待处理', '$needsIndexCount 本'),
              _buildStatusChip(context, '占用', _formatFileSize(totalBytes)),
            ],
          ),
          if ((_currentStageText ?? '').trim().isNotEmpty ||
              (_reindexStatusText ?? '').trim().isNotEmpty) ...[
            SizedBox(height: metrics.contentGap),
            _buildInlineStatusBanner(
              context,
              icon: Icons.sync_rounded,
              text: _currentStageText ?? _reindexStatusText!,
            ),
          ],
          if ((_lastErrorText ?? '').trim().isNotEmpty ||
              (_reindexErrorText ?? '').trim().isNotEmpty) ...[
            SizedBox(height: metrics.contentGap),
            _buildInlineStatusBanner(
              context,
              icon: Icons.error_outline_rounded,
              text: _lastErrorText ?? _reindexErrorText!,
              error: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalBooksPanel(BuildContext context, List<LocalBook> books) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '本地文件',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (metrics.isMediumUpWindow) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: Text(
                    '格式',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '大小',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else
                Text(
                  '按状态和更新时间排序',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          SizedBox(height: metrics.contentGap),
          if (books.isEmpty)
            Text(
              '还没有本地图书。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var index = 0; index < books.length; index++) ...[
              _buildLocalBookRow(context, books[index]),
              if (index < books.length - 1)
                Divider(
                  height: metrics.sectionGap,
                  color: colorScheme.outlineVariant,
                ),
            ],
        ],
      ),
    );
  }

  Widget _buildLocalBookRow(BuildContext context, LocalBook book) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _localIndexStatusColor(context, book.indexStatus);
    final busy = _reindexingBookId == book.id;
    return InkWell(
      borderRadius: BorderRadius.circular(metrics.cardRadius),
      onTap: () => unawaited(_openLocalBook(book)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: metrics.contentGap * 0.45),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  busy
                      ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                      : Icon(
                        Icons.insert_drive_file_outlined,
                        color: statusColor,
                      ),
            ),
            SizedBox(width: metrics.contentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: metrics.contentGap * 0.3),
                  Text(
                    '${book.format.displayLabel} · ${book.chapterCount} 章 · ${_formatFileSize(book.fileSize)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: metrics.contentGap),
            if (metrics.isMediumUpWindow) ...[
              SizedBox(
                width: 96,
                child: Text(
                  book.format.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  _formatFileSize(book.fileSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(_localIndexStatusLabel(book.indexStatus)),
              side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
              backgroundColor: statusColor.withValues(alpha: 0.08),
              labelStyle: TextStyle(color: statusColor),
            ),
            IconButton(
              tooltip: '重索引',
              onPressed: busy ? null : () => unawaited(_reindexBook(book)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, String value) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.cardPadding * 0.8,
        vertical: metrics.contentGap * 0.65,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildInlineStatusBanner(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool error = false,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final color = error ? colorScheme.error : colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.cardPadding * 0.8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    error
                        ? colorScheme.onErrorContainer
                        : colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final maxWidth = AppLayout.pageContentMaxWidth(
      context,
      maxWidth: AppLayout.localLibraryContentMaxWidth,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('本地书库')),
      body: SafeArea(
        child: StreamBuilder<List<LocalBook>>(
          stream: _localBookRepository.watchAllBooks(),
          builder: (context, snapshot) {
            final books = _sortLocalBooks(snapshot.data ?? const <LocalBook>[]);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AppFadeSlideTransition(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      metrics.contentGap,
                      horizontal,
                      metrics.sectionGap +
                          MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      if (metrics.isMediumUpWindow)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _buildImportPanel(context),
                            ),
                            SizedBox(width: metrics.sectionGap),
                            Expanded(
                              flex: 5,
                              child: _buildLibraryStatusPanel(context, books),
                            ),
                          ],
                        )
                      else ...[
                        _buildImportPanel(context),
                        SizedBox(height: metrics.sectionGap),
                        _buildLibraryStatusPanel(context, books),
                      ],
                      SizedBox(height: metrics.sectionGap),
                      _buildLocalBooksPanel(context, books),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
