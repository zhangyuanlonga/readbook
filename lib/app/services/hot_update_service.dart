import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../core/logging/app_logger.dart';
import '../../core/navigation/global_navigator.dart';
import '../widgets/adaptive_bottom_sheet.dart';
import '../widgets/foundation/app_feedback.dart';

/// 热更新检查服务 - 启动时检查并显示 UI 提示
class HotUpdateService {
  HotUpdateService._();

  static final instance = HotUpdateService._();

  final ShorebirdUpdater _updater = ShorebirdUpdater();
  final AppLogger _logger = AppLogger.instance;

  /// 启动时检查更新
  Future<void> checkAndPromptUpdate(BuildContext context) async {
    try {
      final isAvailable = _updater.isAvailable;
      _logger.info(
        'Hot update check started',
        context: <String, Object?>{'isAvailable': isAvailable},
      );
      if (!isAvailable) {
        return;
      }

      // 检查是否有新 patch
      final status = await _updater.checkForUpdate();
      _logger.info(
        'Hot update status resolved',
        context: <String, Object?>{'status': status.name},
      );

      if (status == UpdateStatus.unavailable ||
          status == UpdateStatus.upToDate) {
        return;
      }

      if (!context.mounted) {
        _logger.warn(
          'Hot update fallback context unmounted',
          context: <String, Object?>{'status': status.name},
        );
        return;
      }
      final dialogContext = await _resolveDialogContext(context);
      if (dialogContext == null || !dialogContext.mounted) {
        _logger.warn(
          'Hot update dialog context unavailable',
          context: <String, Object?>{'status': status.name},
        );
        return;
      }

      if (status == UpdateStatus.restartRequired) {
        await _showRestartDialog(dialogContext);
        return;
      }

      // 显示更新对话框
      final shouldUpdate = await _showUpdateDialog(dialogContext);
      _logger.info(
        'Hot update prompt completed',
        context: <String, Object?>{'accepted': shouldUpdate == true},
      );

      if (shouldUpdate == true) {
        if (!dialogContext.mounted) return;
        await _downloadAndApplyUpdate(dialogContext);
      }
    } catch (e) {
      // 静默失败，不影响应用正常使用
      _logger.warn(
        'Hot update check failed',
        context: <String, Object?>{'error': e.toString()},
      );
      debugPrint('热更新检查失败: $e');
    }
  }

  Future<BuildContext?> _resolveDialogContext(BuildContext fallback) async {
    for (var attempt = 0; attempt < 12; attempt += 1) {
      final rootContext = globalRootNavigatorKey.currentContext;
      if (rootContext != null && rootContext.mounted) {
        return rootContext;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (fallback.mounted &&
        Navigator.maybeOf(fallback, rootNavigator: true) != null) {
      return fallback;
    }
    return null;
  }

  /// 显示更新对话框
  Future<bool?> _showUpdateDialog(BuildContext context) {
    return showAdaptiveActionSurface<bool>(
      context: context,
      barrierDismissible: false,
      showDragHandle: false,
      maxWidth: 420,
      padding: EdgeInsets.zero,
      builder:
          (surfaceContext) => _HotUpdateActionSurface(
            icon: Icons.system_update_alt_rounded,
            title: '发现内容更新',
            message: '有新的内容补丁，是否立即下载？重启应用后生效。',
            secondaryLabel: '稍后',
            onSecondary: () => Navigator.of(surfaceContext).pop(false),
            primaryLabel: '立即更新',
            onPrimary: () => Navigator.of(surfaceContext).pop(true),
          ),
    );
  }

  /// 下载并应用更新
  Future<void> _downloadAndApplyUpdate(BuildContext context) async {
    _logger.info('Hot update download started');
    unawaited(
      showAdaptiveActionSurface<void>(
        context: context,
        barrierDismissible: false,
        showDragHandle: false,
        maxWidth: 360,
        padding: EdgeInsets.zero,
        builder: (surfaceContext) => const _HotUpdateProgressSurface(),
      ),
    );

    try {
      // 下载更新
      await _updater.update();
      _logger.info('Hot update downloaded');

      if (!context.mounted) return;

      // 关闭下载进度
      Navigator.of(context, rootNavigator: true).pop();

      // 提示重启
      await _showRestartDialog(context);
    } catch (e) {
      _logger.warn(
        'Hot update download failed',
        context: <String, Object?>{'error': e.toString()},
      );
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      AppFeedback.showSnackBar(
        context,
        message: '更新失败: $e',
        tone: AppFeedbackTone.error,
        useHaptics: false,
      );
    }
  }

  /// 提示重启应用
  Future<void> _showRestartDialog(BuildContext context) {
    return showAdaptiveActionSurface<void>(
      context: context,
      barrierDismissible: false,
      showDragHandle: false,
      maxWidth: 420,
      padding: EdgeInsets.zero,
      builder:
          (surfaceContext) => _HotUpdateActionSurface(
            icon: Icons.restart_alt_rounded,
            title: '更新完成',
            message: '更新已下载完成，请重启应用以应用更新。',
            primaryLabel: '知道了',
            onPrimary: () {
              Navigator.of(surfaceContext).pop();
              // 用户需要手动重启应用。
            },
          ),
    );
  }
}

class _HotUpdateActionSurface extends StatelessWidget {
  const _HotUpdateActionSurface({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.42),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (secondaryLabel != null && onSecondary != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        child: Text(secondaryLabel!),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotUpdateProgressSurface extends StatelessWidget {
  const _HotUpdateProgressSurface();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
          child: const AppInlineFeedback(
            title: '正在下载更新',
            message: '请保持应用打开，下载完成后会提示重启。',
            tone: AppFeedbackTone.loading,
          ),
        ),
      ),
    );
  }
}
