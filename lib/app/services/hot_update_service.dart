import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// 热更新检查服务 - 启动时检查并显示 UI 提示
class HotUpdateService {
  HotUpdateService._();

  static final instance = HotUpdateService._();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// 启动时检查更新
  Future<void> checkAndPromptUpdate(BuildContext context) async {
    try {
      if (!_updater.isAvailable) {
        return;
      }

      // 检查是否有新 patch
      final status = await _updater.checkForUpdate();

      if (status == UpdateStatus.unavailable ||
          status == UpdateStatus.upToDate) {
        return;
      }

      if (!context.mounted) return;

      if (status == UpdateStatus.restartRequired) {
        await _showRestartDialog(context);
        return;
      }

      // 显示更新对话框
      final shouldUpdate = await _showUpdateDialog(context);

      if (shouldUpdate == true) {
        if (!context.mounted) return;
        await _downloadAndApplyUpdate(context);
      }
    } catch (e) {
      // 静默失败，不影响应用正常使用
      debugPrint('热更新检查失败: $e');
    }
  }

  /// 显示更新对话框
  Future<bool?> _showUpdateDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('发现内容更新'),
            content: const Text('有新的内容补丁，是否立即下载？重启应用后生效。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('立即更新'),
              ),
            ],
          ),
    );
  }

  /// 下载并应用更新
  Future<void> _downloadAndApplyUpdate(BuildContext context) async {
    // 显示下载进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在下载更新...'),
              ],
            ),
          ),
    );

    try {
      // 下载更新
      await _updater.update();

      if (!context.mounted) return;

      // 关闭下载进度
      Navigator.pop(context);

      // 提示重启
      await _showRestartDialog(context);
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  /// 提示重启应用
  Future<void> _showRestartDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('更新完成'),
            content: const Text('更新已下载完成，请重启应用以应用更新。'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // 用户需要手动重启应用
                },
                child: const Text('知道了'),
              ),
            ],
          ),
    );
  }
}
