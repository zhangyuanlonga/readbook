import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../application/advanced_theme_provider.dart';

enum FeaturePlaceholderKind { readerBackground, launchImage, fontManagement }

class FeaturePlaceholderPage extends ConsumerWidget {
  const FeaturePlaceholderPage({super.key, required this.kind});

  final FeaturePlaceholderKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = _FeaturePlaceholderSpec.forKind(kind);
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      ref.watch(activeAdvancedThemeProvider).valueOrNull,
    );
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

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
          title: Text(spec.title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        body: DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  topInset + 12,
                  horizontal,
                  16 + bottomSafe,
                ),
                children: [
                  _buildIntroCard(context, spec),
                  const SizedBox(height: 12),
                  _buildTodoCard(context, spec),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context, _FeaturePlaceholderSpec spec) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  spec.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            spec.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(BuildContext context, _FeaturePlaceholderSpec spec) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预留内容',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final item in spec.todoItems) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            if (item != spec.todoItems.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FeaturePlaceholderSpec {
  const _FeaturePlaceholderSpec({
    required this.title,
    required this.description,
    required this.icon,
    required this.todoItems,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String> todoItems;

  static _FeaturePlaceholderSpec forKind(FeaturePlaceholderKind kind) {
    return switch (kind) {
      FeaturePlaceholderKind.readerBackground => const _FeaturePlaceholderSpec(
        title: '阅读背景',
        description: '这里预留阅读器专属背景资源入口，后续会和正文页阅读背景、纸张纹理、自定义图片统一管理。',
        icon: Icons.chrome_reader_mode_outlined,
        todoItems: [
          '预留阅读背景资源列表与当前使用状态展示。',
          '后续接入阅读器背景图上传、选择和删除能力。',
          '支持按主题或按阅读模式分别配置背景。',
        ],
      ),
      FeaturePlaceholderKind.launchImage => const _FeaturePlaceholderSpec(
        title: '启动图',
        description: '这里预留应用启动图配置入口，后续可以统一管理开屏素材、品牌图和深浅色模式适配。',
        icon: Icons.rocket_launch_outlined,
        todoItems: [
          '预留启动图资源预览与素材库展示。',
          '后续接入启动图上传、替换和适配规则配置。',
          '支持按主题或节日活动切换启动图方案。',
        ],
      ),
      FeaturePlaceholderKind.fontManagement => const _FeaturePlaceholderSpec(
        title: '字体管理',
        description: '这里预留应用与阅读器共用的字体管理入口，后续会把导入、删除、预览和作用域配置集中起来。',
        icon: Icons.font_download_outlined,
        todoItems: [
          '预留已导入字体列表、预览和当前使用状态。',
          '后续接入字体导入、删除和重命名能力。',
          '支持区分应用界面字体与阅读器正文字体的使用范围。',
        ],
      ),
    };
  }
}
