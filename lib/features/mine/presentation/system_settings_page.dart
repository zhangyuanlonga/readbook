import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../bookshelf/application/bookshelf_system_settings_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../search/application/search_system_settings_service.dart';

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('系统')),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.systemSettingsContentMaxWidth,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    12,
                    horizontal,
                    16 + bottomSafe,
                  ),
                  children: [
                    _buildSystemOverviewCard(context),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >=
                            AppLayout.railBreakpointWidth;
                        if (wide) {
                          return const Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _BookshelfAutoRefreshSettingPanel(),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _ReaderAutoSwitchSettingPanel(),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child:
                                        _LocalTxtSplitLongChapterSettingPanel(),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _SearchAggregationSettingPanel(),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _SearchConcurrencySettingPanel(),
                              SizedBox(height: 12),
                              _ReadingRecordSettingPanel(),
                              SizedBox(height: 12),
                              _ReaderSettingsResetPanel(),
                            ],
                          );
                        }

                        return const Column(
                          children: [
                            _BookshelfAutoRefreshSettingPanel(),
                            SizedBox(height: 12),
                            _ReaderAutoSwitchSettingPanel(),
                            SizedBox(height: 12),
                            _LocalTxtSplitLongChapterSettingPanel(),
                            SizedBox(height: 12),
                            _SearchAggregationSettingPanel(),
                            SizedBox(height: 12),
                            _SearchConcurrencySettingPanel(),
                            SizedBox(height: 12),
                            _ReadingRecordSettingPanel(),
                            SizedBox(height: 12),
                            _ReaderSettingsResetPanel(),
                          ],
                        );
                      },
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

  Widget _buildSystemOverviewCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.44),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(
                  context,
                  icon: Icons.auto_fix_high_rounded,
                  label: '阅读容错',
                ),
                _buildMetaChip(
                  context,
                  icon: Icons.sync_rounded,
                  label: '书架刷新',
                ),
                _buildMetaChip(
                  context,
                  icon: Icons.auto_awesome_mosaic_rounded,
                  label: '搜索聚合',
                ),
                _buildMetaChip(
                  context,
                  icon: Icons.history_rounded,
                  label: '阅读记录',
                ),
                _buildMetaChip(
                  context,
                  icon: Icons.restart_alt_rounded,
                  label: '阅读重置',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildMetaChip(
  BuildContext context, {
  required IconData icon,
  required String label,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        Icon(icon, size: 15, color: colorScheme.primary),
        const SizedBox(width: 6),
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

  return Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.46),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    value
                        ? colorScheme.primaryContainer.withValues(alpha: 0.92)
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    value
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isLoading || isSaving)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else
              Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        const SizedBox(height: 10),
        Text(
          stateDescription,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            height: 1.35,
          ),
        ),
        if (errorText case final message?) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(context, message: message),
        ],
      ],
    ),
  );
}

Widget _buildErrorBanner(BuildContext context, {required String message}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: colorScheme.errorContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
        const SizedBox(width: 8),
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
      fontSource: defaults.fontSource,
      clearFontFamilyKey: true,
      clearCustomFontPath: true,
      volumeKeyPageEnabled: defaults.volumeKeyPageEnabled,
      autoReadEnabled: defaults.autoReadEnabled,
      autoReadSpeed: defaults.autoReadSpeed,
      pageTurnStepRatio: defaults.pageTurnStepRatio,
      bodyMarginTop: defaults.bodyMarginTop,
      bodyMarginBottom: defaults.bodyMarginBottom,
      bodyMarginLeft: defaults.bodyMarginLeft,
      bodyMarginRight: defaults.bodyMarginRight,
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text('$content\n\n该操作不会影响书架和阅读记录。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认恢复'),
              ),
            ],
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restart_alt_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '阅读设置恢复默认',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '把阅读页“界面设置”和“设置”里的恢复入口集中到这里。',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSaving)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
            const SizedBox(height: 10),
            Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_errorText case final message?) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(context, message: message),
          ],
        ],
      ),
    );
  }
}

class _ReaderAutoSwitchSettingPanel extends StatefulWidget {
  const _ReaderAutoSwitchSettingPanel();

  @override
  State<_ReaderAutoSwitchSettingPanel> createState() =>
      _ReaderAutoSwitchSettingPanelState();
}

class _ReaderAutoSwitchSettingPanelState
    extends State<_ReaderAutoSwitchSettingPanel> {
  final ReaderSystemSettingsService _systemSettingsService =
      ReaderSystemSettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final enabled =
          await _systemSettingsService.loadAutoSwitchSourceOnFailureEnabled();
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
        _errorText = '读取自动换源开关失败，请稍后重试。';
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
      await _systemSettingsService.saveAutoSwitchSourceOnFailureEnabled(
        enabled,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存自动换源开关失败，请稍后重试。';
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
      icon: Icons.swap_horiz_rounded,
      title: '阅读容错',
      description: '正文加载失败时自动尝试候选来源。',
      stateDescription: _enabled ? '失败时自动补位。' : '仅支持手动切换来源。',
      stateLabel: _enabled ? '已开启' : '已关闭',
      value: _enabled,
      isLoading: _isLoading,
      isSaving: _isSaving,
      onChanged: _isLoading || _isSaving ? null : _toggle,
      errorText: _errorText,
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

class _SearchAggregationSettingPanel extends StatefulWidget {
  const _SearchAggregationSettingPanel();

  @override
  State<_SearchAggregationSettingPanel> createState() =>
      _SearchAggregationSettingPanelState();
}

class _SearchAggregationSettingPanelState
    extends State<_SearchAggregationSettingPanel> {
  final SearchSystemSettingsService _settingsService =
      SearchSystemSettingsService();

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
          await _settingsService.loadAggregateByTitleAuthorEnabled();
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
        _errorText = '读取搜索聚合开关失败，请稍后重试。';
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
      await _settingsService.saveAggregateByTitleAuthorEnabled(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存搜索聚合开关失败，请稍后重试。';
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
      icon: Icons.merge_type_rounded,
      title: '搜索聚合',
      description: '按书名与作者合并多源命中结果。',
      stateDescription: _enabled ? '多源命中时自动合并展示。' : '按原始结果逐条展示。',
      stateLabel: _enabled ? '聚合中' : '原始列表',
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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.hub_outlined,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '搜索并发',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '控制搜索和换源时同时请求的书源数量，默认 15。',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading || _isSaving)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed:
                    _isLoading || _isSaving
                        ? null
                        : () => unawaited(_updateValue(_value - 1)),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
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
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed:
                    _isLoading || _isSaving
                        ? null
                        : () => unawaited(_updateValue(_value + 1)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '范围：${SearchSystemSettingsService.minMaxConcurrentSources} - ${SearchSystemSettingsService.maxMaxConcurrentSources}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
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

class _LocalTxtSplitLongChapterSettingPanel extends StatefulWidget {
  const _LocalTxtSplitLongChapterSettingPanel();

  @override
  State<_LocalTxtSplitLongChapterSettingPanel> createState() =>
      _LocalTxtSplitLongChapterSettingPanelState();
}

class _LocalTxtSplitLongChapterSettingPanelState
    extends State<_LocalTxtSplitLongChapterSettingPanel> {
  final ReaderSystemSettingsService _systemSettingsService =
      ReaderSystemSettingsService();

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
          await _systemSettingsService.loadLocalTxtSplitLongChapterEnabled();
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
        _errorText = '读取长章节拆分开关失败，请稍后重试。';
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
      await _systemSettingsService.saveLocalTxtSplitLongChapterEnabled(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存长章节拆分开关失败，请稍后重试。';
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
      icon: Icons.splitscreen_outlined,
      title: '本地 TXT 长章节拆分',
      description: 'TXT 自动分章时，超长章节自动拆成多章。',
      stateDescription: _enabled ? '新导入或重新索引时默认开启。' : '保留原大章节，不自动拆分。',
      stateLabel: _enabled ? '默认开启' : '默认关闭',
      value: _enabled,
      isLoading: _isLoading,
      isSaving: _isSaving,
      onChanged: _isLoading || _isSaving ? null : _toggle,
      errorText: _errorText,
    );
  }
}

class _ReadingRecordSettingPanel extends StatefulWidget {
  const _ReadingRecordSettingPanel();

  @override
  State<_ReadingRecordSettingPanel> createState() =>
      _ReadingRecordSettingPanelState();
}

class _ReadingRecordSettingPanelState
    extends State<_ReadingRecordSettingPanel> {
  final ReaderSystemSettingsService _systemSettingsService =
      ReaderSystemSettingsService();

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
      final enabled = await _systemSettingsService.loadReadRecordEnabled();
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
        _errorText = '读取阅读记录开关失败，请稍后重试。';
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
      await _systemSettingsService.saveReadRecordEnabled(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存阅读记录开关失败，请稍后重试。';
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
      icon: Icons.history_rounded,
      title: '阅读记录',
      description: '记录阅读时长、按天汇总和时间线会话。',
      stateDescription: _enabled ? '阅读时自动累计记录。' : '不再新增阅读记录，已有记录仍保留。',
      stateLabel: _enabled ? '记录中' : '已关闭',
      value: _enabled,
      isLoading: _isLoading,
      isSaving: _isSaving,
      onChanged: _isLoading || _isSaving ? null : _toggle,
      errorText: _errorText,
    );
  }
}
