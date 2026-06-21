import 'dart:async';

import 'package:first_run_kit/first_run_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_official_theme_presets.dart';
import '../../bookshelf/providers.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/mine_page_preferences_service.dart';
import '../../mine/providers.dart';
import '../application/onboarding_first_run_bootstrap.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return FirstRunWrapper(
      config: FirstRunConfig(
        layout: FirstRunLayout.centered,
        primaryColor: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        surfaceColor: colorScheme.surfaceContainerHighest,
        onSurfaceColor: colorScheme.onSurface,
        progressColor: colorScheme.primary,
        progressBackgroundColor: colorScheme.surfaceContainerHighest,
        successColor: colorScheme.primary,
        warningColor: colorScheme.tertiary,
        errorColor: colorScheme.error,
        cardBorderRadius: 16,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        nextButtonBuilder: _filledButton,
        backButtonBuilder: _textButton,
        skipButtonBuilder: _textButton,
      ),
      steps: const <FirstRunStep>[
        OnboardingStep(
          title: '欢迎来到书享阅读',
          description: '先选好阅读和管理习惯，之后都可以在设置里随时调整。',
          image: _WelcomeMark(),
        ),
        CustomStep(widget: _AppearancePreferenceStep()),
        CustomStep(widget: _LayoutPreferenceStep()),
        CustomStep(widget: _ImportPermissionNoteStep()),
      ],
      onFinish: (_) => const _OnboardingFinishedRedirect(),
    );
  }
}

Widget _filledButton(
  BuildContext context,
  String label,
  VoidCallback onPressed,
) {
  return FilledButton(
    onPressed: onPressed,
    child: Text(_localizedButtonLabel(label)),
  );
}

Widget _textButton(BuildContext context, String label, VoidCallback onPressed) {
  return TextButton(
    onPressed: onPressed,
    child: Text(_localizedButtonLabel(label)),
  );
}

String _localizedButtonLabel(String label) {
  return switch (label) {
    'Back' => '上一步',
    'Skip' => '跳过',
    'Next' => '下一步',
    'Finish' => '开始使用',
    _ => label,
  };
}

class _OnboardingFinishedRedirect extends StatefulWidget {
  const _OnboardingFinishedRedirect();

  @override
  State<_OnboardingFinishedRedirect> createState() =>
      _OnboardingFinishedRedirectState();
}

class _OnboardingFinishedRedirectState
    extends State<_OnboardingFinishedRedirect> {
  @override
  void initState() {
    super.initState();
    OnboardingFirstRunBootstrap.markCompletedSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _WelcomeMark extends StatelessWidget {
  const _WelcomeMark();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: colorScheme.onPrimaryContainer,
        size: 54,
      ),
    );
  }
}

class _AppearancePreferenceStep extends ConsumerStatefulWidget {
  const _AppearancePreferenceStep();

  @override
  ConsumerState<_AppearancePreferenceStep> createState() =>
      _AppearancePreferenceStepState();
}

class _AppearancePreferenceStepState
    extends ConsumerState<_AppearancePreferenceStep> {
  late String _themeId;
  late AppNavigationStylePreference _navigationStyle;

  @override
  void initState() {
    super.initState();
    _themeId =
        ref.read(activeAdvancedThemeIdProvider) ?? appDefaultOfficialThemeId;
    _navigationStyle = ref.read(appNavigationStylePreferenceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepSurface(
      icon: Icons.palette_rounded,
      title: '选择第一眼的样子',
      subtitle: '主题和底部导航会立即保存。',
      children: <Widget>[
        Text('默认主题', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: appOfficialThemePresets
              .map((preset) {
                return _ThemeChoiceChip(
                  preset: preset,
                  selected: preset.id.themeId == _themeId,
                  onSelected: () => _setTheme(preset.id.themeId),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 22),
        Text('导航栏', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        if (isPlatformNavigationStyleSupported())
          SegmentedButton<AppNavigationStylePreference>(
            segments: const <ButtonSegment<AppNavigationStylePreference>>[
              ButtonSegment<AppNavigationStylePreference>(
                value: AppNavigationStylePreference.standard,
                icon: Icon(Icons.space_dashboard_rounded),
                label: Text('标准'),
              ),
              ButtonSegment<AppNavigationStylePreference>(
                value: AppNavigationStylePreference.cupertinoDock,
                icon: Icon(Icons.blur_on_rounded),
                label: Text('苹果风格'),
              ),
            ],
            selected: <AppNavigationStylePreference>{_navigationStyle},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final selected = selection.first;
              _setNavigationStyle(selected);
            },
          )
        else
          const _MutedInfoRow(
            icon: Icons.desktop_windows_rounded,
            text: '当前平台使用标准导航。',
          ),
      ],
    );
  }

  void _setTheme(String themeId) {
    if (_themeId == themeId) {
      return;
    }
    setState(() {
      _themeId = themeId;
    });
    unawaited(
      ref
          .read(activeAdvancedThemeIdProvider.notifier)
          .setActiveThemeId(themeId),
    );
  }

  void _setNavigationStyle(AppNavigationStylePreference preference) {
    if (_navigationStyle == preference) {
      return;
    }
    setState(() {
      _navigationStyle = preference;
    });
    unawaited(
      ref
          .read(appNavigationStylePreferenceProvider.notifier)
          .setPreference(preference),
    );
  }
}

class _LayoutPreferenceStep extends ConsumerStatefulWidget {
  const _LayoutPreferenceStep();

  @override
  ConsumerState<_LayoutPreferenceStep> createState() =>
      _LayoutPreferenceStepState();
}

class _LayoutPreferenceStepState extends ConsumerState<_LayoutPreferenceStep> {
  bool _bookshelfGrid = false;
  MinePageLayoutMode _mineLayoutMode = MinePageLayoutMode.list;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final bookshelfGrid =
        await ref.read(bookshelfServiceProvider).loadUseGridView();
    final mineLayoutMode =
        await ref.read(minePagePreferencesServiceProvider).loadLayoutMode() ??
        MinePageLayoutMode.list;
    if (!mounted) {
      return;
    }
    setState(() {
      _bookshelfGrid = bookshelfGrid;
      _mineLayoutMode = mineLayoutMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepSurface(
      icon: Icons.view_agenda_rounded,
      title: '选择常用列表',
      subtitle: '书架和我的页面会按你的习惯打开。',
      children: <Widget>[
        Text('书架', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.view_list_rounded),
              label: Text('列表'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.grid_view_rounded),
              label: Text('网格'),
            ),
          ],
          selected: <bool>{_bookshelfGrid},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            _setBookshelfGrid(selection.first);
          },
        ),
        const SizedBox(height: 22),
        Text('我的页面', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<MinePageLayoutMode>(
          segments: const <ButtonSegment<MinePageLayoutMode>>[
            ButtonSegment<MinePageLayoutMode>(
              value: MinePageLayoutMode.list,
              icon: Icon(Icons.view_list_rounded),
              label: Text('列表'),
            ),
            ButtonSegment<MinePageLayoutMode>(
              value: MinePageLayoutMode.grid,
              icon: Icon(Icons.grid_view_rounded),
              label: Text('网格'),
            ),
          ],
          selected: <MinePageLayoutMode>{_mineLayoutMode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            _setMineLayoutMode(selection.first);
          },
        ),
      ],
    );
  }

  void _setBookshelfGrid(bool value) {
    if (_bookshelfGrid == value) {
      return;
    }
    setState(() {
      _bookshelfGrid = value;
    });
    unawaited(ref.read(bookshelfServiceProvider).saveUseGridView(value));
  }

  void _setMineLayoutMode(MinePageLayoutMode mode) {
    if (_mineLayoutMode == mode) {
      return;
    }
    setState(() {
      _mineLayoutMode = mode;
    });
    unawaited(
      ref.read(minePagePreferencesServiceProvider).saveLayoutMode(mode),
    );
  }
}

class _ImportPermissionNoteStep extends StatelessWidget {
  const _ImportPermissionNoteStep();

  @override
  Widget build(BuildContext context) {
    return const _StepSurface(
      icon: Icons.folder_open_rounded,
      title: '导入时再授权',
      subtitle: '本地书、字体、背景图都可以稍后添加。',
      children: <Widget>[
        _MutedInfoRow(icon: Icons.book_rounded, text: '导入本地书时再选择文件。'),
        SizedBox(height: 12),
        _MutedInfoRow(icon: Icons.image_rounded, text: '更换背景或封面时再访问图片。'),
        SizedBox(height: 12),
        _MutedInfoRow(icon: Icons.settings_rounded, text: '刚才的选择之后都能在设置里调整。'),
      ],
    );
  }
}

class _StepSurface extends StatelessWidget {
  const _StepSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeChoiceChip extends StatelessWidget {
  const _ThemeChoiceChip({
    required this.preset,
    required this.selected,
    required this.onSelected,
  });

  final AppOfficialThemePreset preset;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ThemeSwatches(colors: preset.previewSwatches),
          const SizedBox(width: 8),
          Text(preset.id.label),
        ],
      ),
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 18,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < colors.length && index < 4; index += 1)
            Positioned(
              left: index * 7,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MutedInfoRow extends StatelessWidget {
  const _MutedInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
