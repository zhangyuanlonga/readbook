import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
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

  double? get _importProgressValue {
    if (!_isImporting || _importTotal <= 0) {
      return null;
    }
    return (_importCompleted / _importTotal).clamp(0, 1).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _localBookImportService = ref.read(localBookImportServiceProvider);
    _readerOpenService = ref.read(bookshelfReaderOpenServiceProvider);
  }

  String get _importProgressText {
    if (_importTotal <= 0) {
      return '准备导入';
    }
    if (_importCompleted >= _importTotal) {
      return '导入完成';
    }
    final stage = _currentStageText?.trim();
    if (stage != null && stage.isNotEmpty) {
      return stage;
    }
    final current = _currentImportLabel?.trim();
    if (current != null && current.isNotEmpty) {
      return '正在处理《$current》';
    }
    return '正在导入本地图书';
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
    });

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
            setState(() {
              _currentStageText = switch (progress.stage) {
                LocalBookImportStage.preparing => '准备文件',
                LocalBookImportStage.persisted => '已写入书架',
                LocalBookImportStage.indexing => '正在建立目录',
                LocalBookImportStage.completed => '完成导入',
              };
            });
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
          });
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isImporting = false;
      _currentStageText = successCount > 0 ? '完成导入，可直接阅读' : null;
    });

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
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 720);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('导入本地图书')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
              children: [
                if (_isImporting) _buildImportProgressCard(colorScheme),
                InkWell(
                  onTap: _isImporting ? null : _pickAndImportFiles,
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
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
                        const SizedBox(height: 18),
                        Text(
                          '点击选择本地图书',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '支持 TXT、EPUB、Markdown、HTML、PDF、MOBI、AZW、AZW3。导入会等待目录建立完成，完成后可直接阅读。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isImporting ? null : _pickAndImportFiles,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('从文件选择器导入'),
                        ),
                        if (!_isImporting && _lastImportedResult != null) ...[
                          const SizedBox(height: 12),
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
                                icon: const Icon(Icons.library_books_outlined),
                                label: const Text('返回书架'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导入说明',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. 选择文件后立即导入，不再进入待导入列表。\n2. 进度会依次显示准备、入库、索引、完成。\n3. 显示完成后代表目录已建立，可直接阅读。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      if ((_lastErrorText ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
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
    );
  }

  Widget _buildImportProgressCard(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _importProgressText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$_importCompleted/$_importTotal',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _importProgressValue,
                minHeight: 8,
                backgroundColor: colorScheme.surface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '显示完成后，说明图书目录已建立，可直接打开阅读。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
