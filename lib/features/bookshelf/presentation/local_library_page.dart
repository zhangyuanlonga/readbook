import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../application/local_book_import_service.dart';

class LocalLibraryPage extends StatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  State<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends State<LocalLibraryPage> {
  final LocalBookImportService _localBookImportService =
      LocalBookImportService();

  bool _isImporting = false;
  int _importTotal = 0;
  int _importCompleted = 0;
  String? _currentImportLabel;
  List<_PendingImportItem> _pendingItems = <_PendingImportItem>[];

  int get _pendingSelectedCount =>
      _pendingItems.where((item) => item.selected).length;
  bool get _hasPending => _pendingItems.isNotEmpty;
  bool get _allPendingSelected =>
      _pendingItems.isNotEmpty && _pendingItems.every((item) => item.selected);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickFilesToPending() async {
    if (_isImporting) {
      return;
    }

    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Book Files',
          extensions: ['txt', 'epub'],
          uniformTypeIdentifiers: [
            'public.plain-text',
            'org.idpf.epub-container',
          ],
        ),
      ],
      confirmButtonText: '选择本地图书',
    );

    if (!mounted || files.isEmpty) {
      return;
    }

    final items = <_PendingImportItem>[];
    for (final file in files) {
      final filePath = file.path.trim();
      if (filePath.isEmpty) {
        continue;
      }
      final name = file.name.trim().isEmpty ? p.basename(filePath) : file.name;
      items.add(_PendingImportItem.file(path: filePath, name: name));
    }

    _appendPendingItems(items);
  }

  Future<void> _addUrlToPending() async {
    if (_isImporting) {
      return;
    }

    final input = await _showUrlImportPage();
    if (!mounted || input == null) {
      return;
    }

    final rawUrl = input.trim();
    if (rawUrl.isEmpty) {
      _showMessage('链接不能为空。');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    final scheme = uri?.scheme.toLowerCase();
    final isHttpScheme = scheme == 'http' || scheme == 'https';
    if (uri == null || uri.host.isEmpty || !isHttpScheme) {
      _showMessage('链接格式无效，请输入 http/https 开头的图书地址。');
      return;
    }

    _appendPendingItems([_PendingImportItem.url(url: rawUrl)]);
  }

  void _appendPendingItems(List<_PendingImportItem> items) {
    if (items.isEmpty) {
      return;
    }

    final existingKeys = _pendingItems.map((item) => item.key).toSet();
    var added = 0;
    final updated = List<_PendingImportItem>.from(_pendingItems);
    for (final item in items) {
      if (existingKeys.contains(item.key)) {
        continue;
      }
      existingKeys.add(item.key);
      updated.add(item);
      added += 1;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingItems = updated;
    });

    if (added > 0) {
      _showMessage('已添加 $added 本待导入。');
    } else {
      _showMessage('待导入列表中已存在这些图书。');
    }
  }

  Future<void> _importPendingItems() async {
    if (_isImporting) {
      return;
    }

    final selected = _pendingItems.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      _showMessage('请先选择要导入的图书。');
      return;
    }

    _setImporting(true, total: selected.length, completed: 0);

    final succeededKeys = <String>{};
    var successCount = 0;
    var failureCount = 0;
    for (final item in selected) {
      try {
        item.errorText = null;
        item.status = _PendingImportStatus.importing;
        _updateCurrentImportLabel(item.title);
        if (item.type == _PendingImportType.file) {
          await _importFromFileItem(item);
        } else {
          await _importFromUrlItem(item);
        }
        succeededKeys.add(item.key);
        item.status = _PendingImportStatus.succeeded;
        successCount += 1;
      } on AppException catch (error) {
        item.errorText = error.briefMessage;
        item.status = _PendingImportStatus.failed;
        failureCount += 1;
      } on _ImportException catch (error) {
        item.errorText = error.message;
        item.status = _PendingImportStatus.failed;
        failureCount += 1;
      } catch (error) {
        item.errorText = '导入失败：$error';
        item.status = _PendingImportStatus.failed;
        failureCount += 1;
      } finally {
        _setImportProgress(
          completed: _importCompleted + 1,
          currentLabel:
              item.status == _PendingImportStatus.succeeded ? null : item.title,
        );
      }
    }

    if (mounted) {
      setState(() {
        _pendingItems = _pendingItems
            .where((item) => !succeededKeys.contains(item.key))
            .toList(growable: false);
      });
    }

    _setImporting(false);

    if (successCount > 0) {
      if (failureCount > 0) {
        _showMessage(
          '已导入 $successCount 本书并加入书架，失败 $failureCount 本。后台会继续解析成功导入的图书。',
        );
      } else {
        _showMessage('已导入 $successCount 本书并加入书架。后台会继续解析。');
      }
      _returnToBookshelf();
      return;
    }

    if (failureCount > 0) {
      _showMessage('导入失败，请检查待导入列表的错误提示。');
    }
  }

  Future<LocalBookImportResult> _importFromFileItem(
    _PendingImportItem item,
  ) async {
    final path = item.path?.trim() ?? '';
    if (path.isEmpty) {
      throw const _ImportException('文件路径无效。');
    }

    return _localBookImportService.importFromFile(
      filePath: path,
      displayName: item.title,
      waitForIndexing: false,
      onProgress: (progress) => _handleImportProgress(item, progress),
    );
  }

  Future<LocalBookImportResult> _importFromUrlItem(
    _PendingImportItem item,
  ) async {
    final rawUrl = item.url?.trim() ?? '';
    if (rawUrl.isEmpty) {
      throw const _ImportException('链接不能为空。');
    }

    final uri = Uri.tryParse(rawUrl);
    final scheme = uri?.scheme.toLowerCase();
    final isHttpScheme = scheme == 'http' || scheme == 'https';
    if (uri == null || uri.host.isEmpty || !isHttpScheme) {
      throw const _ImportException('链接格式无效，请输入 http/https 地址。');
    }

    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(
      tempDir.path,
      'local_import_${DateTime.now().millisecondsSinceEpoch}.tmp',
    );

    File? tempFile;
    try {
      _handlePendingStatus(item, _PendingImportStatus.downloading);
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 24),
          sendTimeout: const Duration(seconds: 12),
          followRedirects: true,
          maxRedirects: 5,
          validateStatus:
              (status) => status != null && status >= 200 && status < 400,
          headers: const {'Accept': '*/*'},
        ),
      ).download(rawUrl, tempPath);

      tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        throw const _ImportException('下载失败，未生成临时文件。');
      }

      final fileName = _resolveFileName(uri, response.headers);
      final extension = _resolveExtension(fileName, response.headers);
      if (extension.isEmpty) {
        throw const _ImportException('仅支持 txt/epub 文件。');
      }

      final safeBase = _sanitizeFileToken(
        p.basenameWithoutExtension(fileName.isEmpty ? 'local_book' : fileName),
      );
      final finalPath = p.join(
        tempDir.path,
        '${safeBase}_${DateTime.now().millisecondsSinceEpoch}$extension',
      );

      final finalized = await tempFile.rename(finalPath);

      try {
        return await _localBookImportService.importFromFile(
          filePath: finalized.path,
          displayName: '$safeBase$extension',
          waitForIndexing: false,
          onProgress: (progress) => _handleImportProgress(item, progress),
        );
      } finally {
        try {
          if (await finalized.exists()) {
            await finalized.delete();
          }
        } catch (_) {
          // ignore cleanup failure
        }
      }
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        throw _ImportException('链接导入失败：HTTP $statusCode。');
      }

      final message = error.message?.trim();
      throw _ImportException(
        '链接导入失败：${message == null || message.isEmpty ? '网络请求异常' : message}',
      );
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // ignore cleanup failure
        }
      }
    }
  }

  void _togglePendingSelection(_PendingImportItem item, bool selected) {
    setState(() {
      item.selected = selected;
    });
  }

  void _toggleSelectAllPending() {
    final next = !_allPendingSelected;
    setState(() {
      for (final item in _pendingItems) {
        item.selected = next;
      }
    });
  }

  void _clearPending() {
    setState(() {
      _pendingItems = <_PendingImportItem>[];
    });
  }

  void _removePendingItem(_PendingImportItem item) {
    setState(() {
      _pendingItems =
          _pendingItems.where((entry) => entry.id != item.id).toList();
    });
  }

  Future<void> _editPendingItemTitle(_PendingImportItem item) async {
    if (_isImporting) {
      return;
    }
    final edited = await _showEditTitlePage(item.title);
    if (!mounted || edited == null) {
      return;
    }
    final normalized =
        LocalBookImportService.normalizeImportedDisplayName(edited).trim();
    if (normalized.isEmpty || normalized == item.title) {
      return;
    }
    setState(() {
      item.title = normalized;
    });
  }

  Future<String?> _showUrlImportPage() async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (pageContext) => const _LocalUrlImportPage(),
      ),
    );
  }

  Future<String?> _showEditTitlePage(String initialTitle) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder:
            (pageContext) => _PendingTitleEditPage(initialTitle: initialTitle),
      ),
    );
  }

  void _setImporting(bool value, {int? total, int? completed}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isImporting = value;
      if (total != null) {
        _importTotal = total;
      }
      if (completed != null) {
        _importCompleted = completed;
      }
      if (!value) {
        _importTotal = 0;
        _importCompleted = 0;
        _currentImportLabel = null;
      }
    });
  }

  void _setImportProgress({required int completed, String? currentLabel}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _importCompleted = completed;
      _currentImportLabel = currentLabel;
    });
  }

  void _updateCurrentImportLabel(String? label) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentImportLabel = label;
    });
  }

  void _handlePendingStatus(
    _PendingImportItem item,
    _PendingImportStatus status, {
    String? errorText,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      item.status = status;
      if (errorText != null) {
        item.errorText = errorText;
      }
      _currentImportLabel = item.title;
    });
  }

  void _handleImportProgress(
    _PendingImportItem item,
    LocalBookImportProgress progress,
  ) {
    final nextStatus = switch (progress.stage) {
      LocalBookImportStage.preparing => _PendingImportStatus.importing,
      LocalBookImportStage.persisted => _PendingImportStatus.persisted,
      LocalBookImportStage.indexing => _PendingImportStatus.indexing,
      LocalBookImportStage.completed => _PendingImportStatus.succeeded,
    };
    _handlePendingStatus(item, nextStatus);
  }

  double? get _importProgressValue {
    if (!_isImporting || _importTotal <= 0) {
      return null;
    }
    return (_importCompleted / _importTotal).clamp(0, 1).toDouble();
  }

  String get _importProgressText {
    if (_importTotal <= 0) {
      return '准备导入';
    }
    if (_importCompleted >= _importTotal) {
      return '导入完成';
    }
    final current = _currentImportLabel?.trim();
    if (current != null && current.isNotEmpty) {
      return '正在处理《$current》';
    }
    return '正在导入';
  }

  String _sanitizeFileToken(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (sanitized.isEmpty) {
      return 'local_book';
    }
    return sanitized;
  }

  String _resolveFileName(Uri uri, Headers headers) {
    final disposition = headers.value('content-disposition');
    if (disposition != null) {
      final utf8Match = RegExp(
        r"filename\*=UTF-8''([^;]+)",
      ).firstMatch(disposition);
      if (utf8Match != null) {
        return Uri.decodeFull(utf8Match.group(1) ?? '').trim();
      }
      final normalMatch = RegExp(
        r'filename="?([^";]+)"?',
      ).firstMatch(disposition);
      if (normalMatch != null) {
        return (normalMatch.group(1) ?? '').trim();
      }
    }

    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.trim();
    }

    return 'local_book';
  }

  String _resolveExtension(String fileName, Headers headers) {
    final extension = p.extension(fileName).toLowerCase();
    if (extension == '.txt' || extension == '.epub') {
      return extension;
    }

    final contentType = headers.value('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('epub')) {
      return '.epub';
    }
    if (contentType.contains('text/plain')) {
      return '.txt';
    }

    return '';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final pendingCount = _pendingItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入本地图书'),
        actions: [
          if (_isImporting) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '$_importCompleted/$_importTotal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          _hasPending
              ? SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已选 $_pendingSelectedCount / ${_pendingItems.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            _isImporting || _pendingSelectedCount == 0
                                ? null
                                : _importPendingItems,
                        child: const Text('导入选中'),
                      ),
                    ],
                  ),
                ),
              )
              : null,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_isImporting)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
              sliver: SliverToBoxAdapter(child: _buildImportProgressCard()),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              _isImporting ? 12 : 12,
              horizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _buildImportSection()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 0),
            sliver: SliverToBoxAdapter(child: _buildImportListHeader()),
          ),
          if (pendingCount == 0)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
              sliver: SliverToBoxAdapter(child: _buildImportListEmptyState()),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _pendingItems[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildPendingItemTile(item),
                  );
                }, childCount: pendingCount),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImportSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导入方式',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '先选择本地图书，确认后再导入；文件入库后会立即返回，目录解析在后台继续进行。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = AppLayout.isPhoneSmallWidthFor(
                constraints.maxWidth,
              );
              final fileButton = FilledButton.icon(
                onPressed: _isImporting ? null : _pickFilesToPending,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('选择文件'),
              );
              final linkButton = OutlinedButton.icon(
                onPressed: _isImporting ? null : _addUrlToPending,
                icon: const Icon(Icons.link_rounded),
                label: const Text('添加链接'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [fileButton, const SizedBox(height: 8), linkButton],
                );
              }

              return Row(
                children: [
                  Expanded(child: fileButton),
                  const SizedBox(width: 8),
                  Expanded(child: linkButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImportListHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final pendingCount = _pendingItems.length;

    return Row(
      children: [
        Expanded(
          child: Text(
            '待导入 ($pendingCount)',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: _pendingItems.isEmpty ? null : _toggleSelectAllPending,
          child: Text(_allPendingSelected ? '取消全选' : '全选'),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _pendingItems.isEmpty ? null : _clearPending,
          child: const Text('清空'),
        ),
        Icon(Icons.playlist_add_check_rounded, color: colorScheme.primary),
      ],
    );
  }

  Widget _buildImportProgressCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final progressValue = _importProgressValue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _importProgressText,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: colorScheme.surface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '导入成功表示已加入书架；目录解析会在后台继续，稍后会自动变为可读状态。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportListEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '暂无图书',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '选择文件或添加链接后，会出现在这里。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingItemTile(_PendingImportItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleColor =
        item.errorText == null
            ? colorScheme.onSurfaceVariant
            : colorScheme.error;
    final statusMeta = _statusPresentation(item.status, colorScheme);

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _togglePendingSelection(item, !item.selected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: item.selected,
                onChanged:
                    _isImporting
                        ? null
                        : (value) {
                          if (value != null) {
                            _togglePendingSelection(item, value);
                          }
                        },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: '编辑名称',
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              _isImporting
                                  ? null
                                  : () => _editPendingItemTitle(item),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.errorText ?? item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildStatusChip(
                label: statusMeta.label,
                color: statusMeta.color,
                textColor: statusMeta.color,
              ),
              IconButton(
                tooltip: '移除',
                onPressed: _isImporting ? null : () => _removePendingItem(item),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color color,
    Color? textColor,
  }) {
    final background = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor ?? color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _PendingStatusPresentation _statusPresentation(
    _PendingImportStatus status,
    ColorScheme colorScheme,
  ) {
    return switch (status) {
      _PendingImportStatus.pending => _PendingStatusPresentation(
        label: '待导入',
        color: colorScheme.primary,
      ),
      _PendingImportStatus.downloading => _PendingStatusPresentation(
        label: '下载中',
        color: colorScheme.tertiary,
      ),
      _PendingImportStatus.importing => _PendingStatusPresentation(
        label: '入库中',
        color: colorScheme.primary,
      ),
      _PendingImportStatus.persisted => _PendingStatusPresentation(
        label: '已入库',
        color: colorScheme.secondary,
      ),
      _PendingImportStatus.indexing => _PendingStatusPresentation(
        label: '解析中',
        color: colorScheme.secondary,
      ),
      _PendingImportStatus.succeeded => _PendingStatusPresentation(
        label: '已完成',
        color: colorScheme.primary,
      ),
      _PendingImportStatus.failed => _PendingStatusPresentation(
        label: '失败',
        color: colorScheme.error,
      ),
    };
  }
}

enum _PendingImportType { file, url }

enum _PendingImportStatus {
  pending,
  downloading,
  importing,
  persisted,
  indexing,
  succeeded,
  failed,
}

class _PendingImportItem {
  _PendingImportItem._({
    required this.id,
    required this.type,
    required String title,
    required this.subtitle,
    this.path,
    this.url,
  }) : title = LocalBookImportService.normalizeImportedDisplayName(title),
       selected = true,
       errorText = null,
       status = _PendingImportStatus.pending;

  factory _PendingImportItem.file({
    required String path,
    required String name,
  }) {
    return _PendingImportItem._(
      id: 'file_${path.hashCode}_${DateTime.now().microsecondsSinceEpoch}',
      type: _PendingImportType.file,
      title: name.trim().isEmpty ? p.basename(path) : name.trim(),
      subtitle: path,
      path: path,
    );
  }

  factory _PendingImportItem.url({required String url}) {
    final uri = Uri.tryParse(url.trim());
    final title =
        uri != null && uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : uri?.host ?? url.trim();
    return _PendingImportItem._(
      id: 'url_${url.hashCode}_${DateTime.now().microsecondsSinceEpoch}',
      type: _PendingImportType.url,
      title: title.trim().isEmpty ? url.trim() : title.trim(),
      subtitle: url.trim(),
      url: url.trim(),
    );
  }

  final String id;
  final _PendingImportType type;
  String title;
  final String subtitle;
  final String? path;
  final String? url;
  bool selected;
  String? errorText;
  _PendingImportStatus status;

  String get key => switch (type) {
    _PendingImportType.file => 'file:${path ?? ''}',
    _PendingImportType.url => 'url:${url ?? ''}',
  };
}

class _ImportException implements Exception {
  const _ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PendingStatusPresentation {
  const _PendingStatusPresentation({required this.label, required this.color});

  final String label;
  final Color color;
}

class _LocalUrlImportPage extends StatefulWidget {
  const _LocalUrlImportPage();

  @override
  State<_LocalUrlImportPage> createState() => _LocalUrlImportPageState();
}

class _PendingTitleEditPage extends StatefulWidget {
  const _PendingTitleEditPage({required this.initialTitle});

  final String initialTitle;

  @override
  State<_PendingTitleEditPage> createState() => _PendingTitleEditPageState();
}

class _PendingTitleEditPageState extends State<_PendingTitleEditPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 760);
    final keyboardInset = AppLayout.keyboardInset(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑书名'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('完成'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '导入前可先调整书名，后续会按这个名称入库。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSubmit) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: '请输入书名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('保存名称'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalUrlImportPageState extends State<_LocalUrlImportPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 760);
    final keyboardInset = AppLayout.keyboardInset(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('链接导入本地图书'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '请输入 txt/epub 文件链接（http/https）',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSubmit) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/book.txt',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('加入待导入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
