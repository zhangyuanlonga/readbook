import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 桌面 Shell 顶栏里的页面级工具动作。
///
/// 业务页面只注册“按钮语义 + 回调”，不要把具体 Widget 塞到 Shell 里，
/// 这样顶栏可以统一做窄窗口 overflow、tooltip 和禁用态处理。
class DesktopShellPageToolbarAction {
  const DesktopShellPageToolbarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.priority = 0,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int priority;
  final bool enabled;
}

class DesktopShellPageToolbarActions {
  const DesktopShellPageToolbarActions({required this.actions});

  final List<DesktopShellPageToolbarAction> actions;
}

/// Shell 页面工具位注册器。
///
/// 第一阶段只让 Shell 内页面使用；搜索、详情等独立路由后续可通过独立页面骨架
/// 复用同一动作模型，避免继续在每个页面手搓桌面顶栏。
final desktopShellPageToolbarActionsProvider =
    StateProvider<DesktopShellPageToolbarActions?>((ref) {
      return null;
    });
