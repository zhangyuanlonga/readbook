import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../core/errors/app_exception.dart';
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

  @override
  void initState() {
    super.initState();
    _localBookImportService = ref.read(localBookImportServiceProvider);
    _readerOpenService = ref.read(bookshelfReaderOpenServiceProvider);
  }

  @override
  void dispose() {
    _taskSheetController?.close();
    super.dispose();
  }

  Future<void> _pickAndImportFiles() async {
    if (_isImporting) {
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
                ? File(filePath).uri.pathSegments.last
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
            setState(() {
              _lastProgressStage = nextStage;
              _currentStageText = switch (progress.stage) {
                LocalBookImportStage.preparing => '准备文件',
                LocalBookImportStage.persisted => '写入书架',
                LocalBookImportStage.indexing => '建立目录',
                LocalBookImportStage.completed => '完成导入',
              };
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

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 720);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('导入本地图书')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: AppFadeSlideTransition(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  metrics.contentGap,
                  horizontal,
                  metrics.sectionGap + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  InkWell(
                    onTap: _isImporting ? null : _pickAndImportFiles,
                    borderRadius: BorderRadius.circular(metrics.cardRadius + 6),
                    child: Ink(
                      padding: EdgeInsets.all(metrics.cardPadding + 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          metrics.cardRadius + 6,
                        ),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.library_add_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          SizedBox(height: metrics.sectionGap),
                          Text(
                            '点击选择本地图书',
                            style: (metrics.isCompactDensity
                                    ? Theme.of(context).textTheme.titleLarge
                                    : Theme.of(context).textTheme.headlineSmall)
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: metrics.contentGap * 0.8),
                          Text(
                            '支持 TXT、EPUB、Markdown、HTML、PDF、MOBI、AZW、AZW3。导入会等待目录建立完成，完成后可直接阅读。',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: metrics.sectionGap),
                          FilledButton.icon(
                            onPressed:
                                _isImporting ? null : _pickAndImportFiles,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('从文件选择器导入'),
                          ),
                          if (!_isImporting && _lastImportedResult != null) ...[
                            SizedBox(height: metrics.contentGap),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _openLatestImportedBook,
                                  icon: const Icon(Icons.menu_book_rounded),
                                  label: const Text('立即阅读'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _returnToBookshelf,
                                  icon: const Icon(
                                    Icons.library_books_outlined,
                                  ),
                                  label: const Text('返回书架'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: metrics.sectionGap),
                  Container(
                    padding: EdgeInsets.all(metrics.cardPadding),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(
                        metrics.cardRadius + 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '导入说明',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: metrics.contentGap * 0.8),
                        Text(
                          '1. 选择文件后立即导入，不再进入待导入列表。\n2. 进度会依次显示准备、入库、索引、完成。\n3. 显示完成后代表目录已建立，可直接阅读。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        if ((_lastErrorText ?? '').trim().isNotEmpty) ...[
                          SizedBox(height: metrics.contentGap),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(metrics.cardPadding * 0.85),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _lastErrorText!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
