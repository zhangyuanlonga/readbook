import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_release.dart';

class AppUpdateDialog {
  const AppUpdateDialog._();

  static Uri? resolveUpdateUrl(AppUpdateRelease release) {
    final candidate = _resolvePreferredDownloadUrl(release);
    if (candidate.isEmpty) {
      return null;
    }
    return Uri.tryParse(candidate);
  }

  static String _resolvePreferredDownloadUrl(AppUpdateRelease release) {
    final currentPlatform = _currentPlatform();
    if (release.downloads.isNotEmpty) {
      final priorities = <String>[
        currentPlatform,
        if (currentPlatform == 'windows' ||
            currentPlatform == 'macos' ||
            currentPlatform == 'linux')
          'desktop',
        'default',
      ];
      for (final platform in priorities) {
        for (final item in release.downloads) {
          final itemPlatform = (item.platform ?? '').trim().toLowerCase();
          final url = (item.downloadUrl ?? '').trim();
          if (itemPlatform == platform && url.isNotEmpty) {
            return url;
          }
        }
      }
      for (final item in release.downloads) {
        final url = (item.downloadUrl ?? '').trim();
        if (url.isNotEmpty) {
          return url;
        }
      }
    }
    return (release.downloadUrl ?? '').trim();
  }

  static String _currentPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'default';
    }
  }

  static Future<void> openUpdateUrl(BuildContext context, Uri url) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('打开更新链接失败。')));
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

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: !forceUpdate,
      isDismissible: !forceUpdate,
      enableDrag: !forceUpdate,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return PopScope(
          canPop: !forceUpdate,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.76,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.system_update_alt_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '发现新版本',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      versionLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (forceUpdate) ...[
                      const SizedBox(height: 6),
                      Text(
                        '本次更新为强制更新，请尽快升级。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                    if (changelog != null && changelog.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            changelog,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.42,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (url == null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '暂无可用更新链接，请稍后再试。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (!forceUpdate) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('稍后'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                url == null
                                    ? null
                                    : () => openUpdateUrl(sheetContext, url),
                            child: const Text('前往更新'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
