import 'package:flutter/material.dart';

import '../../../../app/widgets/foundation/app_button.dart';
import '../../application/private_book_source_service.dart';

enum BookSourceImportMethod { url, file, paste }

class BookSourceImportMethodSheet extends StatelessWidget {
  const BookSourceImportMethodSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '选择导入方式',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _BookSourceImportMethodTile(
              icon: Icons.link_rounded,
              title: '通过链接导入',
              subtitle: '适合分享链接和大 JSON',
              onTap:
                  () => Navigator.of(context).pop(BookSourceImportMethod.url),
            ),
            const Divider(height: 1, indent: 56),
            _BookSourceImportMethodTile(
              icon: Icons.folder_open_rounded,
              title: '从文件选择',
              subtitle: '读取本地 .json 或 .txt',
              onTap:
                  () => Navigator.of(context).pop(BookSourceImportMethod.file),
            ),
            const Divider(height: 1, indent: 56),
            _BookSourceImportMethodTile(
              icon: Icons.copy_rounded,
              title: '粘贴 JSON',
              subtitle: '从剪贴板读取并预览',
              onTap:
                  () => Navigator.of(context).pop(BookSourceImportMethod.paste),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSourceImportMethodTile extends StatelessWidget {
  const _BookSourceImportMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class ConfirmActionSurface extends StatelessWidget {
  const ConfirmActionSurface({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = destructive ? colorScheme.error : colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            AppButton(
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(false),
              label: '取消',
            ),
            const SizedBox(width: 8),
            AppButton(
              onPressed: () => Navigator.of(context).pop(true),
              variant:
                  destructive
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
              label: confirmLabel,
            ),
          ],
        ),
      ],
    );
  }
}

class RenameGroupSurface extends StatelessWidget {
  const RenameGroupSurface({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '重命名分组',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分组名称'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            AppButton(
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
              label: '取消',
            ),
            const SizedBox(width: 8),
            AppButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              label: '保存',
            ),
          ],
        ),
      ],
    );
  }
}

class SubmitSourceReviewSurface extends StatelessWidget {
  const SubmitSourceReviewSurface({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '提交共享审核',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '提交说明',
            hintText: '说明这个书源适合共享的原因',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            AppButton(
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
              label: '取消',
            ),
            const SizedBox(width: 8),
            AppButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              label: '提交',
            ),
          ],
        ),
      ],
    );
  }
}

class PrivateBookSourceQuotaCard extends StatelessWidget {
  const PrivateBookSourceQuotaCard({super.key, required this.quota});

  final SourceQuotaSnapshot quota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _QuotaPill(
              label:
                  '总书源 ${quota.privateSourceCount}/${_limitText(quota.maxPrivateSources)}',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _QuotaPill(
              label:
                  '检测 ${quota.dailyTestUsed}/${_limitText(quota.dailyTestLimit)}',
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

String _limitText(int value) => value < 0 ? '不限' : '$value';

class _QuotaPill extends StatelessWidget {
  const _QuotaPill({required this.label, this.foregroundColor});

  final String label;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = foregroundColor ?? colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
