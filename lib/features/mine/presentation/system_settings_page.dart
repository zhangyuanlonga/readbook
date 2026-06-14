import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/adaptive_setting_tile.dart';
import '../../../app/widgets/foundation/app_feedback.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../bookshelf/application/bookshelf_system_settings_service.dart';
import '../application/app_reset_service.dart';
import '../application/advanced_theme_provider.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../search/application/search_system_settings_service.dart';
import 'widgets/mine_route_top_bar.dart';

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final backdrop = resolveAdvancedThemeBackdrop(
          Theme.of(context).colorScheme,
          activeAdvancedTheme,
        );
        final horizontal = AppSpacing.pageHorizontal(context);
        final metrics = AppAdaptiveMetrics.of(context);
        final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
        final routeTopBar = buildMineRouteTopBar(
          context: context,
          title: '系统',
          subtitle: '书架、搜索与阅读基础偏好',
        );
        final topInset =
            MediaQuery.paddingOf(context).top +
            routeTopBar.preferredSize.height;

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
            appBar: routeTopBar,
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
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topInset + metrics.sectionGap,
                          horizontal,
                          metrics.sectionGap + bottomSafe,
                        ),
                        children: [
                          _buildSystemOverviewCard(context),
                          SizedBox(height: metrics.sectionGap),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide =
                                  metrics.isMediumUpWindow ||
                                  constraints.maxWidth >= 760;
                              if (!wide) {
                                return const Column(
                                  children: [
                                    _BookshelfAutoRefreshSettingPanel(),
                                    SizedBox(height: 12),
                                    _SearchConcurrencySettingPanel(),
                                    SizedBox(height: 12),
                                    _StorageManagementEntryPanel(),
                                    SizedBox(height: 12),
                                    _ReaderSettingsResetPanel(),
                                    SizedBox(height: 12),
                                    _AppResetPanel(),
                                  ],
                                );
                              }

                              return _buildDesktopSystemSettingsColumns(
                                const <Widget>[
                                  _BookshelfAutoRefreshSettingPanel(),
                                  _SearchConcurrencySettingPanel(),
                                  _StorageManagementEntryPanel(),
                                  _ReaderSettingsResetPanel(),
                                  _AppResetPanel(),
                                ],
                                spacing: 12,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemOverviewCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metrics = AppAdaptiveMetrics.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.42),
            colorScheme.surfaceContainerLow,
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(metrics.cardRadius + 4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.44),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: metrics.isCompactDensity ? 38 : 42,
                  height: metrics.isCompactDensity ? 38 : 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: colorScheme.primary,
                    size: metrics.isCompactDensity ? 20 : 22,
                  ),
                ),
                SizedBox(width: metrics.contentGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '系统偏好',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '把书架、阅读与搜索相关开关收在一起，减少层级和空白占用。',
                        maxLines: metrics.isCompactDensity ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: metrics.sectionGap),
            Wrap(
              spacing: metrics.contentGap,
              runSpacing: metrics.contentGap,
              children: [
                _buildMetaChip(
                  context,
                  icon: Icons.sync_rounded,
                  label: '书架刷新',
                ),
                _buildMetaChip(
                  context,
                  icon: Icons.restart_alt_rounded,
                  label: '阅读重置',
                ),
                _buildMetaChip(
                  context,
                  icon: Icons.storage_rounded,
                  label: '存储管理',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildDesktopSystemSettingsColumns(
  List<Widget> cards, {
  required double spacing,
}) {
  final leftCards = <Widget>[];
  final rightCards = <Widget>[];
  for (var index = 0; index < cards.length; index += 1) {
    if (index.isEven) {
      leftCards.add(cards[index]);
    } else {
      rightCards.add(cards[index]);
    }
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          children: _buildSystemSettingsColumnEntries(
            leftCards,
            spacing: spacing,
          ),
        ),
      ),
      SizedBox(width: spacing),
      Expanded(
        child: Column(
          children: _buildSystemSettingsColumnEntries(
            rightCards,
            spacing: spacing,
          ),
        ),
      ),
    ],
  );
}

List<Widget> _buildSystemSettingsColumnEntries(
  List<Widget> cards, {
  required double spacing,
}) {
  return [
    for (var index = 0; index < cards.length; index++) ...[
      cards[index],
      if (index < cards.length - 1) SizedBox(height: spacing),
    ],
  ];
}

Widget _buildMetaChip(
  BuildContext context, {
  required IconData icon,
  required String label,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final metrics = AppAdaptiveMetrics.of(context);

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: metrics.isCompactDensity ? 8 : 10,
      vertical: metrics.isCompactDensity ? 6 : 7,
    ),
    decoration: BoxDecoration(
      color: colorScheme.surface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.46),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: metrics.isCompactDensity ? 14 : 15,
          color: colorScheme.primary,
        ),
        SizedBox(width: metrics.isCompactDensity ? 5 : 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

Widget _buildCompactSettingCard(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String description,
  required String stateDescription,
  required String stateLabel,
  required bool value,
  required bool isLoading,
  required bool isSaving,
  required ValueChanged<bool>? onChanged,
  String? errorText,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final metrics = AppAdaptiveMetrics.of(context);

  return AdaptiveSettingSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveSettingTile(
          icon: icon,
          title: title,
          description: description,
          active: value,
          loading: isLoading || isSaving,
          trailing: Switch.adaptive(value: value, onChanged: onChanged),
        ),
        SizedBox(height: metrics.contentGap),
        Wrap(
          spacing: metrics.contentGap,
          runSpacing: metrics.contentGap,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.isCompactDensity ? 8 : 10,
                vertical: metrics.isCompactDensity ? 5 : 6,
              ),
              decoration: BoxDecoration(
                color:
                    value
                        ? colorScheme.secondaryContainer.withValues(alpha: 0.78)
                        : colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      value
                          ? colorScheme.secondary.withValues(alpha: 0.24)
                          : colorScheme.outlineVariant.withValues(alpha: 0.46),
                ),
              ),
              child: Text(
                stateLabel,
                style: textTheme.labelMedium?.copyWith(
                  color:
                      value
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: metrics.contentGap),
        Text(
          stateDescription,
          maxLines: metrics.isCompactDensity ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            height: 1.35,
          ),
        ),
        if (errorText case final message?) ...[
          SizedBox(height: metrics.contentGap),
          _buildErrorBanner(context, message: message),
        ],
      ],
    ),
  );
}

Widget _buildErrorBanner(BuildContext context, {required String message}) {
  final colorScheme = Theme.of(context).colorScheme;
  final metrics = AppAdaptiveMetrics.of(context);

  return Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      metrics.cardPadding,
      metrics.isCompactDensity ? 8 : 10,
      metrics.cardPadding,
      metrics.isCompactDensity ? 8 : 10,
    ),
    decoration: BoxDecoration(
      color: colorScheme.errorContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: metrics.isCompactDensity ? 15 : 16,
          color: colorScheme.error,
        ),
        SizedBox(width: metrics.contentGap),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: colorScheme.onErrorContainer,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

enum _ReaderSettingsResetScope { interfaceSettings, readingSettings }

class _ReaderSettingsResetPanel extends StatefulWidget {
  const _ReaderSettingsResetPanel();

  @override
  State<_ReaderSettingsResetPanel> createState() =>
      _ReaderSettingsResetPanelState();
}

class _StorageManagementEntryPanel extends StatelessWidget {
  const _StorageManagementEntryPanel();

  @override
  Widget build(BuildContext context) {
    return AdaptiveSettingSection(
      child: AdaptiveSettingTile(
        icon: Icons.storage_rounded,
        title: '存储管理',
        description: '查看数据库、本地图书、缓存和用户资源占用，并执行分类清理。',
        onTap: () => context.push('/storage-management'),
      ),
    );
  }
}

class _AppResetPanel extends StatefulWidget {
  const _AppResetPanel();

  @override
  State<_AppResetPanel> createState() => _AppResetPanelState();
}

class _AppResetPanelState extends State<_AppResetPanel> {
  final AppResetService _resetService = AppResetService();
  bool _isResetting = false;
  String? _errorText;

  Future<void> _confirmReset() async {
    if (_isResetting) {
      return;
    }
    final controller = TextEditingController();
    var canConfirm = false;
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 460,
      builder: (surfaceContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '重置应用数据',
                  style: Theme.of(surfaceContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  '会清除登录状态、设置、阅读记录、数据库和缓存。\n\n不会删除本地图书文件、自定义封面、背景图、字体和其它用户资源。\n\n请输入“重置”确认。',
                  style: Theme.of(surfaceContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) {
                    final next = value.trim() == '重置';
                    if (next == canConfirm) {
                      return;
                    }
                    setSheetState(() {
                      canConfirm = next;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: '输入 重置',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(surfaceContext).pop(false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          canConfirm
                              ? () => Navigator.of(surfaceContext).pop(true)
                              : null,
                      child: const Text('确认重置'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isResetting = true;
      _errorText = null;
    });
    try {
      await _resetService.resetAndRestart();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '重置失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return AdaptiveSettingSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveSettingTile(
            icon: Icons.delete_sweep_rounded,
            title: '重置应用数据',
            description: '清除设置、数据库和缓存，保留本地图书与用户资源。',
            loading: _isResetting,
          ),
          SizedBox(height: metrics.contentGap),
          FilledButton.tonalIcon(
            onPressed: _isResetting ? null : _confirmReset,
            icon:
                _isResetting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.warning_amber_rounded),
            label: const Text('开始重置'),
          ),
          if (_errorText case final message?) ...[
            SizedBox(height: metrics.contentGap),
            _buildErrorBanner(context, message: message),
          ],
        ],
      ),
    );
  }
}

class _ReaderSettingsResetPanelState extends State<_ReaderSettingsResetPanel> {
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();

  bool _isSaving = false;
  String? _statusText;
  String? _errorText;

  ReaderSettings _resetInterfaceSettings(ReaderSettings current) {
    const defaults = ReaderSettings();
    return current.copyWith(
      brightness: defaults.brightness,
      themeMode: defaults.themeMode,
      pageTurnMode: defaults.pageTurnMode,
      backgroundStyle: defaults.backgroundStyle,
      backgroundTone: defaults.backgroundTone,
      pageAnimationStyle: defaults.pageAnimationStyle,
      infoHeaderEnabled: defaults.infoHeaderEnabled,
      infoFooterEnabled: defaults.infoFooterEnabled,
      infoShowTime: defaults.infoShowTime,
      infoShowBattery: defaults.infoShowBattery,
      infoShowChapter: defaults.infoShowChapter,
      infoShowProgress: defaults.infoShowProgress,
      infoHeaderPadding: defaults.infoHeaderPadding,
      infoFooterPadding: defaults.infoFooterPadding,
      infoHeaderDividerEnabled: defaults.infoHeaderDividerEnabled,
      infoFooterDividerEnabled: defaults.infoFooterDividerEnabled,
      infoHeaderMarginTop: defaults.infoHeaderMarginTop,
      infoHeaderMarginBottom: defaults.infoHeaderMarginBottom,
      infoHeaderMarginLeft: defaults.infoHeaderMarginLeft,
      infoHeaderMarginRight: defaults.infoHeaderMarginRight,
      infoFooterMarginTop: defaults.infoFooterMarginTop,
      infoFooterMarginBottom: defaults.infoFooterMarginBottom,
      infoFooterMarginLeft: defaults.infoFooterMarginLeft,
      infoFooterMarginRight: defaults.infoFooterMarginRight,
      showChapterHeader: defaults.showChapterHeader,
      chapterHeaderHorizontalOffset: defaults.chapterHeaderHorizontalOffset,
      chapterHeaderVerticalOffset: defaults.chapterHeaderVerticalOffset,
      clearBackgroundImage: true,
    );
  }

  ReaderSettings _resetReadingSettings(ReaderSettings current) {
    const defaults = ReaderSettings();
    return current.copyWith(
      fontSize: defaults.fontSize,
      lineHeight: defaults.lineHeight,
      paragraphSpacing: defaults.paragraphSpacing,
      paragraphIndent: defaults.paragraphIndent,
      textFullJustifyEnabled: defaults.textFullJustifyEnabled,
      letterSpacing: defaults.letterSpacing,
      fontWeightLevel: defaults.fontWeightLevel,
      fontWeightValue: defaults.fontWeightValue,
      fontSource: defaults.fontSource,
      systemFontPreset: defaults.systemFontPreset,
      clearFontFamilyKey: true,
      clearCustomFontPath: true,
      bodyTextItalicEnabled: defaults.bodyTextItalicEnabled,
      bodyTextShadowEnabled: defaults.bodyTextShadowEnabled,
      bodyTextShadowColorValue: defaults.bodyTextShadowColorValue,
      bodyTextShadowBlurRadius: defaults.bodyTextShadowBlurRadius,
      bodyTextShadowOffsetDx: defaults.bodyTextShadowOffsetDx,
      bodyTextShadowOffsetDy: defaults.bodyTextShadowOffsetDy,
      volumeKeyPageEnabled: defaults.volumeKeyPageEnabled,
      autoReadEnabled: defaults.autoReadEnabled,
      autoReadSpeed: defaults.autoReadSpeed,
      pageTurnStepRatio: defaults.pageTurnStepRatio,
      bodyTextDecorationStyle: defaults.bodyTextDecorationStyle,
      bodyTextUnderlineThickness: defaults.bodyTextUnderlineThickness,
      bodyTextUnderlineGap: defaults.bodyTextUnderlineGap,
      bodyTextUnderlineDashLength: defaults.bodyTextUnderlineDashLength,
      bodyTextUnderlineDashGapRatio: defaults.bodyTextUnderlineDashGapRatio,
      bodyMarginTop: defaults.bodyMarginTop,
      bodyMarginBottom: defaults.bodyMarginBottom,
      bodyMarginLeft: defaults.bodyMarginLeft,
      bodyMarginRight: defaults.bodyMarginRight,
      clearBodyTextDecorationColor: true,
      mangaReadMode: defaults.mangaReadMode,
      mangaImageSpacing: defaults.mangaImageSpacing,
      mangaImagePadding: defaults.mangaImagePadding,
      mangaLoadStrategy: defaults.mangaLoadStrategy,
      switchSourceScoreRankingEnabled: defaults.switchSourceScoreRankingEnabled,
    );
  }

  Future<void> _reset(_ReaderSettingsResetScope scope) async {
    if (_isSaving) {
      return;
    }

    final isInterface = scope == _ReaderSettingsResetScope.interfaceSettings;
    final title = isInterface ? '恢复界面设置默认' : '恢复阅读设置默认';
    final content =
        isInterface
            ? '将重置阅读器的界面相关设置（主题、触发、信息栏等）。'
            : '将重置阅读器的阅读相关设置（字号、排版、边距、字体等）。';

    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 440,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                surfaceContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '$content\n\n该操作不会影响书架和阅读记录。',
              style: Theme.of(surfaceContext).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(true),
                  child: const Text('确认恢复'),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _statusText = null;
      _errorText = null;
    });

    try {
      final current = await _preferencesService.loadSettings();
      final next =
          isInterface
              ? _resetInterfaceSettings(current)
              : _resetReadingSettings(current);
      await _preferencesService.saveSettings(next);
      if (!mounted) {
        return;
      }
      final message = isInterface ? '界面设置已恢复默认。' : '阅读设置已恢复默认。';
      setState(() {
        _statusText = message;
      });
      AppFeedback.showSnackBar(
        context,
        message: message,
        tone: AppFeedbackTone.success,
        useHaptics: false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '恢复默认失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metrics = AppAdaptiveMetrics.of(context);

    return AdaptiveSettingSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveSettingTile(
            icon: Icons.restart_alt_rounded,
            title: '阅读设置恢复默认',
            description: '把阅读页“界面设置”和“设置”里的恢复入口集中到这里。',
            loading: _isSaving,
          ),
          SizedBox(height: metrics.contentGap),
          Wrap(
            spacing: metrics.contentGap,
            runSpacing: metrics.contentGap,
            children: [
              OutlinedButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : () =>
                            _reset(_ReaderSettingsResetScope.interfaceSettings),
                icon: const Icon(Icons.palette_outlined),
                label: const Text('恢复界面默认'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : () =>
                            _reset(_ReaderSettingsResetScope.readingSettings),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('恢复阅读默认'),
              ),
            ],
          ),
          if (_statusText case final String text) ...[
            SizedBox(height: metrics.contentGap),
            Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_errorText case final message?) ...[
            SizedBox(height: metrics.contentGap),
            _buildErrorBanner(context, message: message),
          ],
        ],
      ),
    );
  }
}

class _BookshelfAutoRefreshSettingPanel extends StatefulWidget {
  const _BookshelfAutoRefreshSettingPanel();

  @override
  State<_BookshelfAutoRefreshSettingPanel> createState() =>
      _BookshelfAutoRefreshSettingPanelState();
}

class _BookshelfAutoRefreshSettingPanelState
    extends State<_BookshelfAutoRefreshSettingPanel> {
  final BookshelfSystemSettingsService _settingsService =
      BookshelfSystemSettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final enabled =
          await _settingsService.loadAutoRefreshOnTabActiveEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = enabled;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '读取书架自动刷新开关失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_isSaving) {
      return;
    }

    final previous = _enabled;
    setState(() {
      _enabled = enabled;
      _isSaving = true;
      _errorText = null;
    });

    try {
      await _settingsService.saveAutoRefreshOnTabActiveEnabled(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存书架自动刷新开关失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCompactSettingCard(
      context,
      icon: Icons.sync_rounded,
      title: '书架自动刷新',
      description: '重新切回书架时自动刷新列表与阅读进度。',
      stateDescription: _enabled ? '切回书架后会自动刷新。' : '仅手动下拉或操作后刷新。',
      stateLabel: _enabled ? '默认开启' : '已关闭',
      value: _enabled,
      isLoading: _isLoading,
      isSaving: _isSaving,
      onChanged: _isLoading || _isSaving ? null : _toggle,
      errorText: _errorText,
    );
  }
}

class _SearchConcurrencySettingPanel extends StatefulWidget {
  const _SearchConcurrencySettingPanel();

  @override
  State<_SearchConcurrencySettingPanel> createState() =>
      _SearchConcurrencySettingPanelState();
}

class _SearchConcurrencySettingPanelState
    extends State<_SearchConcurrencySettingPanel> {
  final SearchSystemSettingsService _settingsService =
      SearchSystemSettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  int _value = SearchSystemSettingsService.defaultMaxConcurrentSources;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final value = await _settingsService.loadMaxConcurrentSources();
      if (!mounted) {
        return;
      }
      setState(() {
        _value = value;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '读取搜索并发失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateValue(int next) async {
    if (_isSaving) {
      return;
    }
    final normalized = next.clamp(
      SearchSystemSettingsService.minMaxConcurrentSources,
      SearchSystemSettingsService.maxMaxConcurrentSources,
    );
    final previous = _value;
    setState(() {
      _value = normalized;
      _isSaving = true;
      _errorText = null;
    });

    try {
      await _settingsService.saveMaxConcurrentSources(normalized);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _value = previous;
        _errorText = '保存搜索并发失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metrics = AppAdaptiveMetrics.of(context);

    return AdaptiveSettingSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveSettingTile(
            icon: Icons.hub_outlined,
            title: '搜索并发',
            description:
                '控制搜索和换源时同时请求的书源数量。默认 ${SearchSystemSettingsService.defaultMaxConcurrentSources}，上限 ${SearchSystemSettingsService.maxMaxConcurrentSources}。',
            loading: _isLoading || _isSaving,
          ),
          SizedBox(height: metrics.sectionGap),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed:
                    _isLoading || _isSaving
                        ? null
                        : () => unawaited(_updateValue(_value - 1)),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(width: metrics.contentGap),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.cardPadding,
                    vertical: metrics.isCompactDensity ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(metrics.cardRadius),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_value',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '当前最大并发书源数',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: metrics.contentGap),
              IconButton.filledTonal(
                onPressed:
                    _isLoading || _isSaving
                        ? null
                        : () => unawaited(_updateValue(_value + 1)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          SizedBox(height: metrics.contentGap),
          Text(
            '范围：${SearchSystemSettingsService.minMaxConcurrentSources} - ${SearchSystemSettingsService.maxMaxConcurrentSources}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (_errorText != null) ...[
            SizedBox(height: metrics.contentGap),
            Text(
              _errorText!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
