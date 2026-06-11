import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/hot_update_service.dart';
import 'widgets/app_splash_screen.dart';

/// 应用启动包装器 - 显示启动屏后进入主应用
class AppWithSplash extends StatefulWidget {
  const AppWithSplash({super.key});

  @override
  State<AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends State<AppWithSplash> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: AppSplashScreen(
          onComplete: () {
            if (mounted) {
              setState(() {
                _showSplash = false;
              });
              // 启动屏完成后检查热更新
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkHotUpdate();
              });
            }
          },
        ),
      );
    }

    return const ProviderScope(child: App());
  }

  Future<void> _checkHotUpdate() async {
    // 等待主页面渲染完成
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await HotUpdateService.instance.checkAndPromptUpdate(context);
    }
  }
}
