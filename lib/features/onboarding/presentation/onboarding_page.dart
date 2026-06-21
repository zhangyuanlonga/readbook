import 'dart:async';

// UI-GOV-EXEMPT-FILE: fixed-visual
// reason: onboarding preview miniatures are illustrative mockups, not reusable app surfaces.

import 'package:first_run_kit/first_run_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_official_theme_presets.dart';
import '../../../app/widgets/foundation/app_button.dart';
import '../../../app/widgets/foundation/app_progress.dart';
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
        CustomStep(widget: _WelcomeStep()),
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
  return AppButton(onPressed: onPressed, label: _localizedButtonLabel(label));
}

Widget _textButton(BuildContext context, String label, VoidCallback onPressed) {
  return AppButton(
    variant: AppButtonVariant.text,
    onPressed: onPressed,
    label: _localizedButtonLabel(label),
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
    // UI-GOV-EXEMPT: scaffold redirect-placeholder
    return const Scaffold(
      body: Center(child: AppProgressIndicator(semanticLabel: '完成引导')),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return const _StepSurface(
      icon: Icons.menu_book_rounded,
      title: '欢迎来到书享阅读',
      subtitle: '先选好阅读和管理习惯，之后都可以在设置里随时调整。',
      preview: _WelcomePreview(),
      children: <Widget>[
        _MutedInfoRow(
          icon: Icons.auto_stories_rounded,
          text: '书架、阅读和我的页面会保持一致的体验。',
        ),
        SizedBox(height: 12),
        _MutedInfoRow(icon: Icons.tune_rounded, text: '本次只做初始偏好，后续可以随时修改。'),
      ],
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
      preview: _AppearancePreview(themeId: _themeId),
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
      preview: _LayoutPreview(
        bookshelfGrid: _bookshelfGrid,
        mineGrid: _mineLayoutMode == MinePageLayoutMode.grid,
      ),
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
      preview: _ImportPreview(),
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
    required this.preview,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget preview;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  preview,
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WelcomePreview extends StatelessWidget {
  const _WelcomePreview();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _PreviewFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _MiniBookCover(title: '长夜'),
                SizedBox(width: 12),
                _MiniBookCover(title: '星河'),
                SizedBox(width: 12),
                _MiniBookCover(title: '风物'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context) {
    final presets = appOfficialThemePresets.take(3).toList(growable: false);
    final selectedIndex = presets.indexWhere(
      (preset) => preset.id.themeId == themeId,
    );
    return _PreviewFrame(
      child: Row(
        children: [
          for (var index = 0; index < presets.length; index++) ...[
            Expanded(
              child: _ThemePreviewCard(
                preset: presets[index],
                selected:
                    index == selectedIndex || (selectedIndex < 0 && index == 0),
              ),
            ),
            if (index < presets.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _LayoutPreview extends StatelessWidget {
  const _LayoutPreview({required this.bookshelfGrid, required this.mineGrid});

  final bool bookshelfGrid;
  final bool mineGrid;

  @override
  Widget build(BuildContext context) {
    return _PreviewFrame(
      child: Row(
        children: [
          Expanded(
            child: _LayoutPreviewPanel(
              title: '书架',
              grid: bookshelfGrid,
              icon: Icons.menu_book_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LayoutPreviewPanel(
              title: '我的',
              grid: mineGrid,
              icon: Icons.person_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview();

  @override
  Widget build(BuildContext context) {
    return const _PreviewFrame(
      child: Column(
        children: [
          _ImportPreviewRow(icon: Icons.upload_file_rounded, label: '本地书籍'),
          SizedBox(height: 10),
          _ImportPreviewRow(icon: Icons.wallpaper_rounded, label: '背景与封面'),
          SizedBox(height: 10),
          _ImportPreviewRow(icon: Icons.font_download_rounded, label: '字体资源'),
        ],
      ),
    );
  }
}

class _MiniBookCover extends StatelessWidget {
  const _MiniBookCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.10),
            colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.preset, required this.selected});

  final AppOfficialThemePreset preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThemeSwatches(colors: preset.previewSwatches),
          const Spacer(),
          Text(
            preset.id.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color:
                  selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutPreviewPanel extends StatelessWidget {
  const _LayoutPreviewPanel({
    required this.title,
    required this.grid,
    required this.icon,
  });

  final String title;
  final bool grid;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const Spacer(),
          if (grid)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(4, (_) => _PreviewBlock.square()),
            )
          else
            Column(
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _PreviewBlock.line(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock._({required this.width, required this.height});

  factory _PreviewBlock.square() =>
      const _PreviewBlock._(width: 34, height: 28);

  factory _PreviewBlock.line() =>
      const _PreviewBlock._(width: double.infinity, height: 12);

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _ImportPreviewRow extends StatelessWidget {
  const _ImportPreviewRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
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
