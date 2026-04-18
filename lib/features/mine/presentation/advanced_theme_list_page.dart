import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../application/advanced_theme_provider.dart';

class AdvancedThemeListPage extends ConsumerStatefulWidget {
  const AdvancedThemeListPage({super.key});

  @override
  ConsumerState<AdvancedThemeListPage> createState() =>
      _AdvancedThemeListPageState();
}

enum _AdvancedThemeAction { edit, duplicate, export, delete }

class _AdvancedThemeListPageState extends ConsumerState<AdvancedThemeListPage> {
  static const XTypeGroup _themeJsonTypeGroup = XTypeGroup(
    label: 'Advanced theme JSON',
    extensions: <String>['json'],
    mimeTypes: <String>['application/json', 'text/json', 'text/plain'],
    uniformTypeIdentifiers: <String>['public.json'],
  );

  List<AppAdvancedTheme> _themes = const <AppAdvancedTheme>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConsumingExternalImportPayloads = false;
  StreamSubscription<IncomingExternalImportPayload>? _incomingImportSub;

  @override
  void initState() {
    super.initState();
    _incomingImportSub = ExternalImportBridge.instance.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.advancedTheme) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  @override
  void dispose() {
    _incomingImportSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final service = ref.read(advancedThemeServiceProvider);
    final themes = await service.loadThemes();
    if (!mounted) {
      return;
    }
    setState(() {
      _themes = themes;
      _isLoading = false;
    });
  }

  Future<void> _openEditor([AppAdvancedTheme? theme]) async {
    final result = await context.push<String>(
      theme == null
          ? '/appearance/advanced-themes/editor'
          : '/appearance/advanced-themes/editor?id=${theme.id}',
    );
    await _load();
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _duplicateTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final duplicated = await service.duplicateTheme(theme);
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('已复制主题「${duplicated.name}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _exportTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_themeJsonTypeGroup],
      suggestedName: '${_normalizedFileName(theme.name)}.json',
      confirmButtonText: '导出',
    );
    if (location == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final service = ref.read(advancedThemeServiceProvider);
      final file = File(location.path);
      await file.writeAsString(
        service.encodeThemeColorJson(theme),
        flush: true,
      );
      if (!mounted) {
        return;
      }
      _showMessage('已导出主题「${theme.name}」');
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('导出失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _importTheme() async {
    if (_isSaving) {
      return;
    }
    final picked = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_themeJsonTypeGroup],
      confirmButtonText: '导入主题',
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final rawJson = await File(picked.path).readAsString();
      final service = ref.read(advancedThemeServiceProvider);
      final importedTheme = await service.importThemeColorJson(rawJson);
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('已导入主题「${importedTheme.name}」');
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('导入失败，请确认 JSON 格式正确。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
          type: ExternalImportPayloadType.advancedTheme,
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
      _showMessage('读取外部主题失败：${payload.label}');
      return;
    }

    try {
      final rawJson = await File(cached.path).readAsString();
      final service = ref.read(advancedThemeServiceProvider);
      final importedTheme = await service.importThemeColorJson(rawJson);
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('已导入主题「${importedTheme.name}」');
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('导入外部主题失败：${payload.label}');
    }
  }

  Future<void> _deleteTheme(AppAdvancedTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除高级主题'),
          content: Text('确定删除「${theme.name}」吗？浅色和深色壁纸都会一并移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final wasActive = ref.read(activeAdvancedThemeIdProvider) == theme.id;
      final service = ref.read(advancedThemeServiceProvider);
      await service.deleteTheme(theme.id);
      if (wasActive) {
        await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
      }
      await _load();
      if (!mounted) {
        return;
      }
      _showMessage('已删除主题「${theme.name}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _applyTheme(AppAdvancedTheme theme) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await ref
          .read(activeAdvancedThemeIdProvider.notifier)
          .setActiveThemeId(theme.id);
      if (!mounted) {
        return;
      }
      _showMessage('已应用主题「${theme.name}」');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _disableActiveTheme() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
      if (!mounted) {
        return;
      }
      _showMessage('已停用高级主题');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizedFileName(String name) {
    final normalized = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return normalized.isEmpty ? 'advanced_theme_colors' : normalized;
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final activeThemeId = ref.watch(activeAdvancedThemeIdProvider);
    final activeThemeAsync = ref.watch(activeAdvancedThemeProvider);

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/appearance?section=appearance');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('高级主题'),
          actions: [
            if (activeThemeId != null)
              TextButton(
                onPressed: _isLoading || _isSaving ? null : _disableActiveTheme,
                child: const Text('停用'),
              ),
            IconButton(
              tooltip: '导入主题',
              onPressed: _isLoading || _isSaving ? null : _importTheme,
              icon: const Icon(Icons.file_upload_outlined),
            ),
            IconButton(
              tooltip: '新增高级主题',
              onPressed: _isLoading || _isSaving ? null : () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            12,
                            horizontal,
                            16 + bottomSafe,
                          ),
                          children: [
                            _buildIntroCard(context, activeThemeAsync),
                            const SizedBox(height: 10),
                            if (_themes.isEmpty)
                              _buildEmptyState(context)
                            else
                              ..._themes.map(
                                (theme) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildThemeCard(
                                    context,
                                    theme,
                                    isActive: activeThemeId == theme.id,
                                  ),
                                ),
                              ),
                          ],
                        ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroCard(
    BuildContext context,
    AsyncValue<AppAdvancedTheme?> activeThemeAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeThemeName = switch (activeThemeAsync) {
      AsyncData(:final value) when value != null => value.name,
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.palette_rounded,
              color: colorScheme.onPrimaryContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '双模式自定义主题',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  activeThemeName == null
                      ? '当前未启用高级主题，应用后会覆盖基础主题中的已配置项。'
                      : '当前生效：$activeThemeName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.palette_outlined, size: 34, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            '还没有高级主题',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角新增，就可以分别配置浅色和深色主题。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AppAdvancedTheme theme, {
    required bool isActive,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving ? null : () => _openEditor(theme),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color:
              isActive
                  ? colorScheme.primaryContainer.withValues(alpha: 0.22)
                  : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isActive
                    ? colorScheme.primary.withValues(alpha: 0.55)
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              theme.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '当前生效',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '更新于 ${_formatDateTime(theme.updatedAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_AdvancedThemeAction>(
                  enabled: !_isSaving,
                  onSelected: (action) {
                    switch (action) {
                      case _AdvancedThemeAction.edit:
                        _openEditor(theme);
                      case _AdvancedThemeAction.duplicate:
                        _duplicateTheme(theme);
                      case _AdvancedThemeAction.export:
                        _exportTheme(theme);
                      case _AdvancedThemeAction.delete:
                        _deleteTheme(theme);
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(
                          value: _AdvancedThemeAction.edit,
                          child: Text('编辑'),
                        ),
                        PopupMenuItem(
                          value: _AdvancedThemeAction.duplicate,
                          child: Text('复制'),
                        ),
                        PopupMenuItem(
                          value: _AdvancedThemeAction.export,
                          child: Text('导出 JSON'),
                        ),
                        PopupMenuItem(
                          value: _AdvancedThemeAction.delete,
                          child: Text('删除'),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPreviewPanel(
                    context,
                    mode: AppAdvancedThemeMode.light,
                    config: theme.lightConfig,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPreviewPanel(
                    context,
                    mode: AppAdvancedThemeMode.dark,
                    config: theme.darkConfig,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _isSaving || isActive ? null : () => _applyTheme(theme),
                    child: Text(isActive ? '已应用' : '应用主题'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isSaving ? null : () => _openEditor(theme),
                  child: const Text('编辑'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeBadge(
                  context,
                  mode: AppAdvancedThemeMode.light,
                  label:
                      '浅色 ${theme.lightConfig.colors.configuredColorCount} 项',
                  hasWallpaper: theme.lightConfig.hasWallpaper,
                ),
                _buildModeBadge(
                  context,
                  mode: AppAdvancedThemeMode.dark,
                  label: '深色 ${theme.darkConfig.colors.configuredColorCount} 项',
                  hasWallpaper: theme.darkConfig.hasWallpaper,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(
    BuildContext context, {
    required AppAdvancedThemeMode mode,
    required AppAdvancedThemeModeConfig config,
  }) {
    final defaultScheme = _defaultSchemeFor(context, mode);
    final backgroundColor =
        _colorFrom(config.colors.backgroundColorValue) ?? defaultScheme.surface;
    final cardColor =
        _colorFrom(config.colors.cardColorValue) ?? defaultScheme.surface;
    final textPrimaryColor =
        _colorFrom(config.colors.textPrimaryColorValue) ??
        defaultScheme.onSurface;
    final textSecondaryColor =
        _colorFrom(config.colors.textSecondaryColorValue) ??
        defaultScheme.onSurfaceVariant;
    final borderColor =
        _colorFrom(config.colors.cardBorderColorValue) ??
        defaultScheme.outlineVariant;
    final primaryColor =
        _colorFrom(config.colors.primaryColorValue) ?? defaultScheme.primary;
    final wallpaperPath = config.wallpaperPath?.trim() ?? '';

    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        image:
            wallpaperPath.isNotEmpty && File(wallpaperPath).existsSync()
                ? DecorationImage(
                  image: FileImage(File(wallpaperPath)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    backgroundColor.withValues(alpha: 0.72),
                    BlendMode.srcOver,
                  ),
                )
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mode == AppAdvancedThemeMode.light
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 14,
                  color: textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  mode == AppAdvancedThemeMode.light ? '浅色' : '深色',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textSecondaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 74,
              height: 10,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.56),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 8,
                      decoration: BoxDecoration(
                        color: textPrimaryColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 96,
                      height: 6,
                      decoration: BoxDecoration(
                        color: textSecondaryColor.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBadge(
    BuildContext context, {
    required AppAdvancedThemeMode mode,
    required String label,
    required bool hasWallpaper,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mode == AppAdvancedThemeMode.light
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            size: 13,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            hasWallpaper
                ? Icons.wallpaper_outlined
                : Icons.image_not_supported_outlined,
            size: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  ColorScheme _defaultSchemeFor(
    BuildContext context,
    AppAdvancedThemeMode mode,
  ) {
    final theme = Theme.of(context);
    if (mode == AppAdvancedThemeMode.dark) {
      return theme.brightness == Brightness.dark
          ? theme.colorScheme
          : theme.colorScheme.copyWith(
            surface: const Color(0xFF181D24),
            onSurface: const Color(0xFFE8ECF6),
            onSurfaceVariant: const Color(0xFFB3BDCB),
            primary: const Color(0xFF8EB8FF),
            outlineVariant: const Color(0xFF313844),
          );
    }
    return theme.colorScheme.copyWith(
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827),
      onSurfaceVariant: const Color(0xFF667085),
      primary: const Color(0xFF1677FF),
      outlineVariant: const Color(0xFFE5EAF2),
    );
  }

  Color? _colorFrom(int? value) {
    if (value == null) {
      return null;
    }
    return Color(value);
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
