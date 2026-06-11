import 'package:flutter/material.dart';

/// 应用启动屏 - 纯白背景 + Selune 品牌字体 + 淡入动画
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 淡入动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // 淡入时长 800ms
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // 启动动画
    _controller.forward();

    // 1.5 秒后自动完成
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white, // 纯白背景
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -40), // 稍微偏上
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 主标题：Selune
                Text(
                  'Selune',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const ['Times New Roman', 'serif'],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 64.0 : 48.0,
                    color: const Color(0xFF1A1A1A),
                    height: 0.98,
                    letterSpacing: 0,
                  ),
                ),

                const SizedBox(height: 8),

                // 副标题：CLEAR READING
                Text(
                  'CLEAR READING',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 13.0 : 11.0,
                    color: const Color(0xFF666666).withValues(alpha: 0.68),
                    letterSpacing: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}