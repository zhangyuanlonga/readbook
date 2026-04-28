import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../../reader/application/reader_font_registry_service.dart';
import '../application/advanced_theme_provider.dart';

class FontManagementPage extends ConsumerStatefulWidget {
  const FontManagementPage({super.key});

  @override
  ConsumerState<FontManagementPage> createState() => _FontManagementPageState();
}

class _FontManagementPageState extends ConsumerState<FontManagementPage> {
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();

  bool _isLoading = true;
  bool _isImporting = false;
  bool _isConsumingExternalImportPayloads = false;
  String? _errorText;
  List<ReaderCustomFontEntry> _fonts = const [];
  StreamSubscription<IncomingExternalImportPayload>? _importSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    unawaited(ExternalImportBridge.instance.initialize());
    _importSubscription = ExternalImportBridge.instance.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.font) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  @override
  void dispose() {
    unawaited(_importSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final fonts = await _fontRegistryService.listRegisteredFonts();
      if (!mounted) {
        return;
      }
      setState(() {
        _fonts = fonts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '字体列表加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _consumePendingExternalImportPayloads() async {
    if (_isConsumingExternalImportPayloads || !mounted) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      while (mounted) {
        final payload = ExternalImportBridge.instance.consumePendingPayload(
          type: ExternalImportPayloadType.font,
        );
        if (payload == null) {
          break;
        }
        await _importFromExternalPayload(payload);
      }
    } finally {
      _isConsumingExternalImportPayloads = false;
    }
  }

  Future<void> _importFromExternalPayload(
    IncomingExternalImportPayload payload,
  ) async {
    final cached = await ExternalImportBridge.instance.cacheExternalFileFromUri(
      payload,
    );
    if (cached == null) {
      ExternalImportDiagnostics.logCacheFailed(payload);
      _showSnackBar(
        ExternalImportDiagnostics.readFailedMessage(
          payload.type,
          payload.label,
        ),
      );
      return;
    }

    try {
      if (!ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.font,
        cached.label,
      )) {
        ExternalImportDiagnostics.logImportUnsupported(
          ExternalImportPayloadType.font,
          cached.label,
        );
        _showSnackBar(
          ExternalImportCatalog.unsupportedFileMessage(
            ExternalImportPayloadType.font,
            cached.label,
          ),
        );
        return;
      }
      final entry = await _fontRegistryService.importFontFile(
        filePath: cached.path,
        displayName: cached.label.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
      await _reload();
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportSucceeded(
        ExternalImportPayloadType.font,
        entry.displayName,
      );
      _showSnackBar('已导入字体：${entry.displayName}');
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.font,
        cached.label,
        error,
      );
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.font,
        cached.label,
        error,
      );
      _showSnackBar(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.font,
          '$error',
          label: cached.label,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('字体管理'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go('/mine');
            },
          ),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _isLoading ? null : () => unawaited(_reload()),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isImporting ? null : _importFont,
          icon:
              _isImporting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.file_upload_outlined),
          label: Text(_isImporting ? '导入中...' : '导入字体'),
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.systemSettingsContentMaxWidth,
            );
            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        topInset + 12,
                        horizontal,
                        88 + bottomSafe,
                      ),
                      children: [
                        _buildHero(context),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_errorText != null)
                          _buildErrorCard(context)
                        else ...[
                          _buildLibraryHeader(context),
                          const SizedBox(height: 10),
                          if (_fonts.isEmpty)
                            _buildEmptyLibraryCard(context)
                          else
                            ..._fonts.map(
                              (font) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildFontCard(context, font),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.font_download_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '统一管理应用与阅读器字体',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(context, '已导入 ${_fonts.length} 款'),
              _buildHeroChip(context, '支持 TTF / OTF'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildLibraryHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的字体库',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '加载失败',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _errorText ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => unawaited(_reload()),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLibraryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '还没有导入字体',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '导入 `.ttf` 或 `.otf` 后会在这里显示。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard(BuildContext context, ReaderCustomFontEntry font) {
    final colorScheme = Theme.of(context).colorScheme;
    final file = File(font.filePath);
    final exists = file.existsSync();
    final importedAt = DateTime.fromMillisecondsSinceEpoch(
      font.importedAtEpochMs,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        font.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exists ? '文件可用' : '文件已丢失',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              exists
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      unawaited(_renameFont(font));
                    }
                    if (value == 'delete') {
                      unawaited(_removeFont(font));
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: Text('重命名'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('删除字体'),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '阅读预览',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天的阅读不只是在翻页，也是在塑造自己的语言节奏。',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: exists ? font.fontFamilyKey : null,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FontMetaChip(text: '阅读正文'),
                _FontMetaChip(text: _formatTime(importedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFont() async {
    setState(() {
      _isImporting = true;
    });
    try {
      final entry = await _fontRegistryService.pickAndImportFont();
      if (!mounted || entry == null) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入字体：${entry.displayName}')));
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入字体失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _removeFont(ReaderCustomFontEntry font) async {
    await _fontRegistryService.removeFont(font.fontFamilyKey);
    if (!mounted) {
      return;
    }
    await _reload();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除字体：${font.displayName}')));
  }

  Future<void> _renameFont(ReaderCustomFontEntry font) async {
    final controller = TextEditingController(text: font.displayName);
    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('重命名字体'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '显示名称',
              hintText: '输入新的字体名称',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || nextName == null) {
      return;
    }
    final normalized = nextName.trim();
    if (normalized.isEmpty || normalized == font.displayName) {
      return;
    }
    try {
      await _fontRegistryService.renameFontDisplayName(
        familyKey: font.fontFamilyKey,
        displayName: normalized,
      );
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已重命名字体：$normalized')));
    } on ReaderFontRegistryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _FontMetaChip extends StatelessWidget {
  const _FontMetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
