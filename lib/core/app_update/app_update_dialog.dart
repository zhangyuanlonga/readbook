import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_release.dart';

class AppUpdateDialog {
  const AppUpdateDialog._();

  static Uri? resolveUpdateUrl(AppUpdateRelease release) {
    final candidate =
        (release.storeUrl ?? '').trim().isNotEmpty
            ? release.storeUrl!
            : (release.downloadUrl ?? '').trim();
    if (candidate.isEmpty) {
      return null;
    }
    return Uri.tryParse(candidate);
  }

  static Future<void> openUpdateUrl(BuildContext context, Uri url) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开更新链接失败。')),
    );
  }

  static Future<void> showUpdateDialog(
    BuildContext context,
    AppUpdateRelease release,
  ) async {
    if (!context.mounted) {
      return;
    }
    final url = resolveUpdateUrl(release);
    final forceUpdate = release.forceUpdate == true;
    final versionLabel =
        release.versionName ??
        (release.versionCode != null ? '版本 ${release.versionCode}' : '新版本');
    final changelog = release.changelog?.trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            title: const Text('发现新版本'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(versionLabel),
                if (forceUpdate) ...[
                  const SizedBox(height: 6),
                  Text(
                    '本次更新为强制更新，请尽快升级。',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                  ),
                ],
                if (changelog != null && changelog.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    changelog,
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          height: 1.4,
                        ),
                  ),
                ],
                if (url == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '暂无可用更新链接，请稍后再试。',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('稍后'),
                ),
              FilledButton(
                onPressed:
                    url == null
                        ? null
                        : () => openUpdateUrl(dialogContext, url),
                child: const Text('前往更新'),
              ),
            ],
          ),
        );
      },
    );
  }
}
