import 'package:flutter/material.dart';

typedef AdvancedThemeGalleryPreviewThumbBuilder =
    Widget Function({
      required String? previewPath,
      required String title,
      required double width,
      required double height,
      required double borderRadius,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
    });

/// 高级主题编辑页里的启动图集选择卡片。
///
/// 组件只展示图集标题、数量和前三张预览，不读取编辑器 draft，也不直接打开预览弹窗。
/// 页面通过 `previewThumbBuilder` 注入缩略图渲染和长按预览行为，后续拆分资源选择器时
/// 可以继续保持“展示组件吃参数，页面负责业务意图”的边界。
class AdvancedThemeLaunchGallerySelectionCard extends StatelessWidget {
  const AdvancedThemeLaunchGallerySelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.previewPaths,
    required this.selected,
    required this.onTap,
    required this.previewThumbBuilder,
    this.onPreviewLongPress,
  });

  final String title;
  final String subtitle;
  final List<String> previewPaths;
  final bool selected;
  final VoidCallback onTap;
  final AdvancedThemeGalleryPreviewThumbBuilder previewThumbBuilder;
  final ValueChanged<String>? onPreviewLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.46)
                    : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.45),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: Row(
                  children: List.generate(3, (index) {
                    final previewPath =
                        index < previewPaths.length
                            ? previewPaths[index]
                            : null;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                        child: SizedBox(
                          height: 96,
                          child: previewThumbBuilder(
                            previewPath: previewPath,
                            title: title,
                            width: double.infinity,
                            height: 96,
                            borderRadius: 12,
                            onTap: onTap,
                            onLongPress:
                                previewPath == null
                                    ? null
                                    : () =>
                                        onPreviewLongPress?.call(previewPath),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
