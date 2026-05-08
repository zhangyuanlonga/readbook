import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_interface_typography_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/appearance_page_resource_service.dart';
import '../application/cover_gallery_provider.dart';
import '../application/advanced_theme_provider.dart';
import 'widgets/appearance_other_settings_card.dart';
import 'widgets/image_resource_collection_widgets.dart';
import '../../reader/application/reader_font_registry_service.dart';
import '../providers.dart';

part 'appearance_page_view.dart';

enum AppearanceSection { appearance, tabBar, cover, background }

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({
    super.key,
    this.section = AppearanceSection.appearance,
  });

  final AppearanceSection section;

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  static const List<Map<String, String>> _coverGallerySamples = [
    {'title': '凡人修仙传', 'author': '忘语'},
    {'title': '斗破苍穹', 'author': '天蚕土豆'},
    {'title': '三体', 'author': '刘慈欣'},
    {'title': '庆余年', 'author': '猫腻'},
    {'title': '雪中悍刀行', 'author': '烽火戏诸侯'},
    {'title': '活着', 'author': '余华'},
  ];

  List<String> _backgroundPaths = [];
  bool _isLoadingBackgrounds = true;
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();
  late final ImageSelectionService _imageSelectionService;
  late final AppearancePageResourceService _resourceService;
  final TextEditingController _backgroundSearchController =
      TextEditingController();
  List<ReaderCustomFontEntry> _availableCustomFonts = const [];
  String _backgroundSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _imageSelectionService = ref.read(mineImageSelectionServiceProvider);
    _resourceService = ref.read(appearancePageResourceServiceProvider);
    _loadBackgrounds();
    unawaited(_loadAvailableFonts());
  }

  Future<void> _loadBackgrounds() async {
    final resources = await _resourceService.loadResources();
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundPaths = resources.backgroundPaths.toList(growable: false);
      _availableCustomFonts = resources.availableFonts.toList(growable: false);
      _isLoadingBackgrounds = false;
    });
  }

  Future<void> _loadAvailableFonts() async {
    final resources = await _resourceService.loadResources();
    if (!mounted) {
      return;
    }
    setState(() {
      _availableCustomFonts = resources.availableFonts.toList(growable: false);
    });
  }

  void _updateBackgroundSearchState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  @override
  void dispose() {
    _backgroundSearchController.dispose();
    super.dispose();
  }

  Future<void> _uploadBackground() async {
    try {
      final source = await _selectBackgroundImageSource();
      if (source == null || !mounted) {
        return;
      }

      final pickedImages = await _imageSelectionService.pickImages(
        confirmButtonText: '选择背景',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
        source: source,
      );
      if (pickedImages.isEmpty || !mounted) {
        return;
      }

      final importedCount = await _resourceService.importBackgrounds(
        pickedImages,
      );
      await _loadBackgrounds();
      _showMessage('已添加 $importedCount 张背景');
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } on PlatformException catch (error) {
      _showMessage('选择背景失败：${error.message ?? error.code}');
    } catch (error) {
      _showMessage('添加背景失败：$error');
    }
  }

  Future<ImageSelectionSource?> _selectBackgroundImageSource() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return ImageSelectionSource.files;
    }

    return showModalBottomSheet<ImageSelectionSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('相册'),
                  subtitle: const Text('从系统照片库选择一张图片'),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pop(ImageSelectionSource.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('文件'),
                  subtitle: const Text('从文件 App 或本地目录选择图片'),
                  onTap:
                      () =>
                          Navigator.of(context).pop(ImageSelectionSource.files),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteBackground(String path) async {
    await _resourceService.deleteBackground(path);
    await _loadBackgrounds();
  }

  Future<void> _confirmDeleteBackground(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除背景'),
            content: const Text('确定要删除这个背景图吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _deleteBackground(path);
    }
  }

  Future<void> _previewBackground(String path) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Center(
                            child: Text(
                              '图片加载失败',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 12,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static const List<_ThemeModeOption> _themeModeOptions = [
    _ThemeModeOption(
      mode: ThemeMode.light,
      label: '日间',
      icon: Icons.light_mode_outlined,
    ),
    _ThemeModeOption(
      mode: ThemeMode.dark,
      label: '夜间',
      icon: Icons.dark_mode_outlined,
    ),
    _ThemeModeOption(
      mode: ThemeMode.system,
      label: '跟随系统',
      icon: Icons.settings_suggest_outlined,
    ),
  ];

  static const List<_NavigationStyleOption> _navigationStyleOptions = [
    _NavigationStyleOption(
      preference: AppNavigationStylePreference.standard,
      label: '标准',
      icon: Icons.splitscreen_outlined,
    ),
    _NavigationStyleOption(
      preference: AppNavigationStylePreference.cupertinoDock,
      label: '苹果风格',
      icon: Icons.dock_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => _buildAppearancePage(context);
}

class _ThemeModeOption {
  const _ThemeModeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
}

class _NavigationStyleOption {
  const _NavigationStyleOption({
    required this.preference,
    required this.label,
    required this.icon,
  });

  final AppNavigationStylePreference preference;
  final String label;
  final IconData icon;
}

class _FontFamilyPickerDialog extends ConsumerStatefulWidget {
  const _FontFamilyPickerDialog({
    required this.fontRegistryService,
    required this.initialFonts,
  });

  final ReaderFontRegistryService fontRegistryService;
  final List<ReaderCustomFontEntry> initialFonts;

  @override
  ConsumerState<_FontFamilyPickerDialog> createState() =>
      _FontFamilyPickerDialogState();
}

class _FontFamilyPickerDialogState
    extends ConsumerState<_FontFamilyPickerDialog> {
  late List<ReaderCustomFontEntry> _availableCustomFonts;
  bool _isImporting = false;
  ImportExportTaskStatus? _inlineImportStatus;

  @override
  void initState() {
    super.initState();
    _availableCustomFonts = List<ReaderCustomFontEntry>.from(
      widget.initialFonts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFont = ref.watch(appInterfaceFontSettingsProvider);
    final selectedCustomFont = _resolveSelectedCustomFont(selectedFont);

    Widget buildFontChoiceTile({
      required String label,
      required bool selected,
      required Future<void> Function()? onTap,
      IconData? icon,
      bool loading = false,
    }) {
      final colorScheme = Theme.of(context).colorScheme;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap == null ? null : () => unawaited(onTap()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color:
                  selected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLow,
              border: Border.all(
                color:
                    selected
                        ? colorScheme.primary.withValues(alpha: 0.45)
                        : colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else if (icon != null)
                  Icon(
                    icon,
                    size: 14,
                    color:
                        selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                  ),
                if (icon != null || loading) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color:
                          selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择字体',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '与阅读器共用同一批已导入字体，只调整应用界面全局显示。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.35,
                children: [
                  buildFontChoiceTile(
                    label: appInterfaceSystemFontPresetLabel(
                      AppInterfaceSystemFontPreset.defaultSans,
                    ),
                    selected:
                        selectedFont.fontSource ==
                            AppInterfaceFontSource.system &&
                        selectedFont.systemFontPreset ==
                            AppInterfaceSystemFontPreset.defaultSans,
                    icon: Icons.text_fields_rounded,
                    onTap:
                        () => _selectSystemFont(
                          AppInterfaceSystemFontPreset.defaultSans,
                        ),
                  ),
                  buildFontChoiceTile(
                    label: appInterfaceSystemFontPresetLabel(
                      AppInterfaceSystemFontPreset.serif,
                    ),
                    selected:
                        selectedFont.fontSource ==
                            AppInterfaceFontSource.system &&
                        selectedFont.systemFontPreset ==
                            AppInterfaceSystemFontPreset.serif,
                    icon: Icons.format_shapes_rounded,
                    onTap:
                        () => _selectSystemFont(
                          AppInterfaceSystemFontPreset.serif,
                        ),
                  ),
                  buildFontChoiceTile(
                    label: appInterfaceSystemFontPresetLabel(
                      AppInterfaceSystemFontPreset.monospace,
                    ),
                    selected:
                        selectedFont.fontSource ==
                            AppInterfaceFontSource.system &&
                        selectedFont.systemFontPreset ==
                            AppInterfaceSystemFontPreset.monospace,
                    icon: Icons.code_rounded,
                    onTap:
                        () => _selectSystemFont(
                          AppInterfaceSystemFontPreset.monospace,
                        ),
                  ),
                  ..._availableCustomFonts.map(
                    (entry) => buildFontChoiceTile(
                      label: entry.displayName,
                      selected:
                          selectedCustomFont?.fontFamilyKey ==
                          entry.fontFamilyKey,
                      icon: Icons.font_download_outlined,
                      onTap: () => _selectCustomFont(entry),
                    ),
                  ),
                  buildFontChoiceTile(
                    label: '自定义',
                    selected: false,
                    loading: _isImporting,
                    icon: Icons.upload_file_rounded,
                    onTap: _importCustomFontFromSheet,
                  ),
                ],
              ),
            ),
            if (_inlineImportStatus != null) ...[
              const SizedBox(height: 12),
              ImportExportInlineStatus(status: _inlineImportStatus!),
            ],
          ],
        ),
      ),
    );
  }

  ReaderCustomFontEntry? _resolveSelectedCustomFont(
    AppInterfaceFontSettings settings,
  ) {
    if (settings.fontSource != AppInterfaceFontSource.custom) {
      return null;
    }
    final familyKey = settings.fontFamilyKey?.trim() ?? '';
    if (familyKey.isEmpty) {
      return null;
    }
    for (final entry in _availableCustomFonts) {
      if (entry.fontFamilyKey == familyKey) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _selectSystemFont(AppInterfaceSystemFontPreset preset) async {
    await ref
        .read(appInterfaceFontSettingsProvider.notifier)
        .setSystemFont(preset);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectCustomFont(ReaderCustomFontEntry entry) async {
    await ref
        .read(appInterfaceFontSettingsProvider.notifier)
        .setCustomFont(entry);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _importCustomFontFromSheet() async {
    if (_isImporting) {
      return;
    }
    setState(() {
      _isImporting = true;
      _inlineImportStatus = const ImportExportTaskStatus(
        title: '正在导入字体',
        message: '正在选择并注册字体到界面字体列表…',
        presentation: ImportExportTaskPresentation.inlineCompact,
      );
    });

    try {
      final imported = await widget.fontRegistryService.pickAndImportFont();
      if (imported == null) {
        return;
      }
      final refreshedFonts =
          await widget.fontRegistryService.listRegisteredFonts();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCustomFonts = refreshedFonts;
        _inlineImportStatus = ImportExportTaskStatus(
          title: '字体导入完成',
          message: '已完成字体注册，正在应用到当前界面设置…',
          detail: imported.displayName,
          progress: 1,
          presentation: ImportExportTaskPresentation.inlineCompact,
          result: ImportExportTaskResult.success,
        );
      });
      await ref
          .read(appInterfaceFontSettingsProvider.notifier)
          .setCustomFont(imported);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _inlineImportStatus = ImportExportTaskStatus(
            title: '导入字体失败',
            message: error.message ?? error.code,
            presentation: ImportExportTaskPresentation.inlineCompact,
            result: ImportExportTaskResult.failure,
          );
        });
      }
      _showMessage('导入字体失败：${error.message ?? error.code}');
    } on ReaderFontRegistryException catch (error) {
      if (mounted) {
        setState(() {
          _inlineImportStatus = ImportExportTaskStatus(
            title: '导入字体失败',
            message: error.message,
            presentation: ImportExportTaskPresentation.inlineCompact,
            result: ImportExportTaskResult.failure,
          );
        });
      }
      _showMessage(error.message);
    } catch (error) {
      if (mounted) {
        setState(() {
          _inlineImportStatus = ImportExportTaskStatus(
            title: '导入字体失败',
            message: '$error',
            presentation: ImportExportTaskPresentation.inlineCompact,
            result: ImportExportTaskResult.failure,
          );
        });
      }
      _showMessage('导入字体失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
