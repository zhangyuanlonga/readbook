import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  static const Duration _keyboardInsetAnimationDuration = Duration(
    milliseconds: 180,
  );
  static const double _desktopPanelRadius = 24;
  static const double _desktopControlRadius = 12;

  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthService _authService;

  bool _isRegister = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _submitError;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
  }

  @override
  void dispose() {
    _accountController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktopAuth =
        AppLayout.isDesktopLike(
          context,
          isWeb: kIsWeb,
          platform: Theme.of(context).platform,
        ) &&
        AppLayout.screenWidth(context) >= AppLayout.expandedBreakpointWidth;

    if (isDesktopAuth) {
      return _buildDesktopAuthPage(
        context,
        keyboardInset: keyboardInset,
        bottomSafe: bottomSafe,
        colorScheme: colorScheme,
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(_isRegister ? '注册' : '登录')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: isWide ? 960 : AppLayout.settingsContentMaxWidth,
          );

          return AnimatedPadding(
            duration: _keyboardInsetAnimationDuration,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    metrics.contentGap,
                    horizontal,
                    metrics.contentGap + bottomSafe,
                  ),
                  children:
                      isWide
                          ? _buildWideContent(context, colorScheme)
                          : _buildCompactContent(context, colorScheme),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopAuthPage(
    BuildContext context, {
    required double keyboardInset,
    required double bottomSafe,
    required ColorScheme colorScheme,
  }) {
    final backgroundColor = colorScheme.surface;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      body: AnimatedPadding(
        duration: _keyboardInsetAnimationDuration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isTwoPane = width >= 1100;
            final horizontalPadding = width >= 1320 ? 56.0 : 32.0;
            final verticalPadding = constraints.maxHeight >= 840 ? 40.0 : 24.0;

            if (!isTwoPane) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(32, 32, 32, 32 + bottomSafe),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      minHeight: (constraints.maxHeight - 64 - bottomSafe)
                          .clamp(0.0, double.infinity),
                    ),
                    child: AppFadeSlideTransition(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDesktopCompactHeader(context, colorScheme),
                          const SizedBox(height: 24),
                          _buildDesktopAuthSurface(context, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final viewportHeight = (constraints.maxHeight - bottomSafe).clamp(
              0.0,
              double.infinity,
            );
            final availableWidth = (width - horizontalPadding * 2).clamp(
              1120.0,
              1760.0,
            );
            final shellWidth = availableWidth.clamp(1120.0, 1640.0);
            final shellHeight = (viewportHeight - verticalPadding * 2).clamp(
              760.0,
              980.0,
            );
            final leftPaneRatio = (((shellWidth - 1120.0) / 520.0) * 0.04 +
                    0.48)
                .clamp(0.48, 0.52);
            final leftPaneWidth = shellWidth * leftPaneRatio;
            final rightPaneWidth = shellWidth - leftPaneWidth;
            final leftPaneFlex = (leftPaneRatio * 1000).round();
            final rightPaneFlex = 1000 - leftPaneFlex;
            final leftInset = (leftPaneWidth * 0.14).clamp(72.0, 116.0);
            final brandTopInset = shellHeight >= 900 ? 72.0 : 56.0;
            final formMaxWidth = (rightPaneWidth * 0.72).clamp(430.0, 560.0);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: bottomSafe),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: AppFadeSlideTransition(
                      child: SizedBox(
                        width: shellWidth,
                        height: shellHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(
                              _desktopPanelRadius,
                            ),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: leftPaneFlex,
                                child: _buildDesktopBrandPanel(
                                  context,
                                  colorScheme: colorScheme,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    leftInset,
                                    brandTopInset,
                                    52,
                                    48,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: rightPaneFlex,
                                child: _buildDesktopAuthSurface(
                                  context,
                                  colorScheme,
                                  embedInSplitLayout: true,
                                  formMaxWidth: formMaxWidth,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopCompactHeader(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey<String>('auth_desktop_compact_header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDesktopBrandMark(context, colorScheme, compact: true),
        const SizedBox(height: 24),
        Text(
          _isRegister ? '创建 Selune 账户' : '欢迎回来',
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isRegister ? '创建新账户，开始同步阅读空间。' : '欢迎回来。请登录您的账户。',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.52,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBrandMark(
    BuildContext context,
    ColorScheme colorScheme, {
    bool compact = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final markSize = compact ? 36.0 : 32.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_stories_rounded,
          color: colorScheme.primary,
          size: markSize,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Selune',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBrandPanel(
    BuildContext context, {
    required ColorScheme colorScheme,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(_desktopPanelRadius),
      ),
      child: Container(
        key: const ValueKey<String>('auth_desktop_brand_panel'),
        padding: contentPadding ?? const EdgeInsets.fromLTRB(72, 56, 48, 48),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildDesktopBrandArtwork(colorScheme),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.58),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.18),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  '静心阅读，\n久一点。',
                  style: textTheme.displaySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 16),
                Container(width: 48, height: 2, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Selune Premium Reading',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 2.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.import_contacts_outlined,
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                    size: 112,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBrandArtwork(ColorScheme colorScheme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerLowest,
                const Color(0xFFF0F4F8),
              ],
            ),
          ),
        ),
        Positioned(
          left: -100,
          top: -36,
          child: _buildDesktopSnowPlane(
            width: 340,
            height: 230,
            angle: -0.52,
            colors: const [Color(0xFFFFFFFF), Color(0xFFEAEFF5)],
            opacity: 0.98,
          ),
        ),
        Positioned(
          left: 76,
          top: 44,
          child: _buildDesktopSnowPlane(
            width: 380,
            height: 280,
            angle: -0.72,
            colors: const [Color(0xFFF9FBFD), Color(0xFFE7ECF2)],
            opacity: 0.86,
          ),
        ),
        Positioned(
          left: -54,
          bottom: 82,
          child: _buildDesktopSnowPlane(
            width: 410,
            height: 250,
            angle: -0.36,
            colors: const [Color(0xFFF8FAFD), Color(0xFFE7ECF3)],
            opacity: 0.84,
          ),
        ),
        Positioned(
          right: -120,
          top: 132,
          child: _buildDesktopSnowPlane(
            width: 320,
            height: 300,
            angle: 0.6,
            colors: const [Color(0xFFF7FAFD), Color(0xFFE9EEF4)],
            opacity: 0.74,
          ),
        ),
        Positioned(
          right: -44,
          bottom: -22,
          child: _buildDesktopSnowPlane(
            width: 320,
            height: 220,
            angle: 0.34,
            colors: const [Color(0xFFFFFFFF), Color(0xFFECEFF4)],
            opacity: 0.88,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSnowPlane({
    required double width,
    required double height,
    required double angle,
    required List<Color> colors,
    required double opacity,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCBD4DF).withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopAuthSurface(
    BuildContext context,
    ColorScheme colorScheme, {
    bool embedInSplitLayout = false,
    double? formMaxWidth,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDesktopBrandMark(context, colorScheme),
        const SizedBox(height: 10),
        Text(
          _isRegister ? '创建新账户，开始同步阅读。' : '欢迎回来。请登录您的账户。',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),
        AppAnimatedSwitcher(
          child:
              _submitError == null
                  ? const SizedBox.shrink(key: ValueKey('auth_no_error'))
                  : _buildInlineError(context, _submitError!),
        ),
        if (_submitError != null) const SizedBox(height: 16),
        _buildForm(context, desktopStyled: true),
        if (!_isRegister) ...[
          const SizedBox(height: 12),
          _buildDesktopLoginActionRow(context, colorScheme),
        ],
        const SizedBox(height: 20),
        _buildSubmitButton(
          desktopStyled: true,
          label: _isRegister ? '创建账户' : '立即登录',
        ),
        if (_isRegister) ...[
          const SizedBox(height: 18),
          _buildModeHint(context, colorScheme, desktopStyled: true),
        ],
        if (!_isRegister) ...[
          const SizedBox(height: 32),
          _buildDesktopAlternativeLogin(context, colorScheme),
        ] else ...[
          const Spacer(),
          _buildDesktopAgreementFooter(context, colorScheme),
        ],
      ],
    );

    return Container(
      key: const ValueKey<String>('auth_desktop_surface'),
      padding: EdgeInsets.fromLTRB(
        embedInSplitLayout ? 48 : 32,
        embedInSplitLayout ? 56 : 30,
        embedInSplitLayout ? 48 : 32,
        embedInSplitLayout ? 32 : 30,
      ),
      decoration:
          embedInSplitLayout
              ? null
              : BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(_desktopPanelRadius),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: formMaxWidth ?? 430),
        child: form,
      ),
    );
  }

  Widget _buildDesktopLoginActionRow(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          '还没有账户？',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : () => _setMode(true),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.only(left: 4, right: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('立即注册'),
        ),
        const Spacer(),
        TextButton(
          onPressed: _isSubmitting ? null : () => _showMessage('请联系管理员重置密码。'),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('忘记密码？'),
        ),
      ],
    );
  }

  List<Widget> _buildCompactContent(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final metrics = AppAdaptiveMetrics.of(context);
    return [
      AppFadeSlideTransition(child: _buildIntroCard(context, expanded: false)),
      SizedBox(height: metrics.contentGap),
      AppFadeSlideTransition(
        delay: const Duration(milliseconds: 48),
        child: _buildAuthSurface(context, colorScheme),
      ),
    ];
  }

  List<Widget> _buildWideContent(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return [
      AppFadeSlideTransition(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _buildIntroCard(context, expanded: true)),
            SizedBox(width: AppAdaptiveMetrics.of(context).contentGap),
            Expanded(flex: 4, child: _buildAuthSurface(context, colorScheme)),
          ],
        ),
      ),
    ];
  }

  Widget _buildAuthSurface(BuildContext context, ColorScheme colorScheme) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeToggle(colorScheme),
            SizedBox(height: metrics.contentGap),
            AppAnimatedSwitcher(
              child:
                  _submitError == null
                      ? const SizedBox.shrink(key: ValueKey('auth_no_error'))
                      : _buildInlineError(context, _submitError!),
            ),
            if (_submitError != null) SizedBox(height: metrics.contentGap),
            _buildForm(context),
            SizedBox(height: metrics.sectionGap),
            _buildSubmitButton(),
            SizedBox(height: metrics.contentGap),
            _buildModeHint(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context, {required bool expanded}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: expanded ? 26 : 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: expanded ? 26 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isRegister ? '创建 Selune 账号' : '欢迎回来',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isRegister
                  ? '注册后可以同步书架、阅读进度和会员权益，换设备也能接上当前阅读。'
                  : '登录后继续同步书架、阅读记录、主题偏好和账号权益。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.42,
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 18),
              _buildBenefitRow(
                context,
                icon: Icons.sync_rounded,
                title: '阅读数据同步',
                description: '书架、进度和阅读记录可随账号恢复。',
              ),
              const SizedBox(height: 12),
              _buildBenefitRow(
                context,
                icon: Icons.workspace_premium_outlined,
                title: '权益状态跟随账号',
                description: '会员和高级主题能力登录后自动识别。',
              ),
              const SizedBox(height: 12),
              _buildBenefitRow(
                context,
                icon: Icons.palette_outlined,
                title: '偏好不用重配',
                description: '外观、图集和常用设置后续可统一管理。',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineError(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('auth_inline_error'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme colorScheme) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('登录')),
        ButtonSegment(value: true, label: Text('注册')),
      ],
      selected: {_isRegister},
      onSelectionChanged:
          _isSubmitting ? null : (value) => _setMode(value.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          colorScheme.surfaceContainerLowest,
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: colorScheme.outlineVariant),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_desktopControlRadius),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  InputDecoration _buildDesktopInputDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(_desktopControlRadius),
      ),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(_desktopControlRadius),
      ),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(_desktopControlRadius),
        ),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(_desktopControlRadius),
        ),
        borderSide: BorderSide(color: colorScheme.error, width: 1.4),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {bool desktopStyled = false}) {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _accountController,
              enabled: !_isSubmitting,
              autofillHints: const [AutofillHints.username],
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              validator: (value) => _requiredValidator(value, '账号'),
              decoration:
                  desktopStyled
                      ? _buildDesktopInputDecoration(
                        context: context,
                        labelText: _isRegister ? '账号' : '账号或用户名',
                        hintText: _isRegister ? '请输入账号' : '请输入账号（兼容用户名）',
                        prefixIcon: const Icon(Icons.person_outline),
                      )
                      : const InputDecoration(
                        labelText: '账号',
                        hintText: '请输入账号（兼容用户名）',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !_isSubmitting,
              autofillHints: [
                _isRegister
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              autocorrect: false,
              enableSuggestions: false,
              obscureText: _obscurePassword,
              textInputAction:
                  _isRegister ? TextInputAction.next : TextInputAction.done,
              validator: (value) => _requiredValidator(value, '密码'),
              decoration:
                  desktopStyled
                      ? _buildDesktopInputDecoration(
                        context: context,
                        labelText: '密码',
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed:
                              _isSubmitting
                                  ? null
                                  : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      )
                      : InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed:
                              _isSubmitting
                                  ? null
                                  : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
              onChanged: _isRegister ? (_) => setState(() {}) : null,
              onFieldSubmitted: _isRegister ? null : (_) => _submit(),
            ),
            if (_isRegister) ...[
              const SizedBox(height: 8),
              _buildPasswordStrengthHint(context),
              const SizedBox(height: 12),
              TextFormField(
                controller: _displayNameController,
                enabled: !_isSubmitting,
                autofillHints: const [AutofillHints.nickname],
                textInputAction: TextInputAction.next,
                decoration:
                    desktopStyled
                        ? _buildDesktopInputDecoration(
                          context: context,
                          labelText: '显示名',
                          hintText: '不填时默认使用账号',
                          prefixIcon: const Icon(Icons.badge_outlined),
                        )
                        : const InputDecoration(
                          labelText: '显示名',
                          hintText: '不填时默认使用账号',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                enabled: !_isSubmitting,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                validator: _confirmPasswordValidator,
                decoration:
                    desktopStyled
                        ? _buildDesktopInputDecoration(
                          context: context,
                          labelText: '确认密码',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm ? '显示确认密码' : '隐藏确认密码',
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () {
                                      setState(() {
                                        _obscureConfirm = !_obscureConfirm;
                                      });
                                    },
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        )
                        : InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm ? '显示确认密码' : '隐藏确认密码',
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () {
                                      setState(() {
                                        _obscureConfirm = !_obscureConfirm;
                                      });
                                    },
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthHint(BuildContext context) {
    final password = _passwordController.text;
    final score =
        [
          password.length >= 8,
          RegExp(r'[A-Za-z]').hasMatch(password),
          RegExp(r'\d').hasMatch(password),
          RegExp(r'[^A-Za-z0-9]').hasMatch(password),
        ].where((matched) => matched).length;
    final label = switch (score) {
      0 || 1 => '密码强度：偏弱',
      2 || 3 => '密码强度：适中',
      _ => '密码强度：较强',
    };
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        password.isEmpty ? '建议使用 8 位以上，并混合字母和数字。' : label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color:
              score >= 3 ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSubmitButton({bool desktopStyled = false, String? label}) {
    final resolvedLabel = label ?? (_isRegister ? '注册并登录' : '登录');
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submit,
        style:
            desktopStyled
                ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_desktopControlRadius),
                  ),
                  elevation: 1,
                )
                : null,
        child: AppAnimatedSwitcher(
          child:
              _isSubmitting
                  ? Row(
                    key: const ValueKey<String>('auth_submitting'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(_isRegister ? '正在注册' : '正在登录'),
                    ],
                  )
                  : Text(resolvedLabel, key: ValueKey<String>(resolvedLabel)),
        ),
      ),
    );
  }

  Widget _buildModeHint(
    BuildContext context,
    ColorScheme colorScheme, {
    bool desktopStyled = false,
  }) {
    return Column(
      children: [
        Text(
          _isRegister ? '已有账户？' : (desktopStyled ? '还没有账户？' : '还没有账号？'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _isSubmitting ? null : () => _setMode(!_isRegister),
          child: Text(_isRegister ? '返回登录' : '立即注册'),
        ),
      ],
    );
  }

  Widget _buildDesktopAlternativeLogin(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(color: colorScheme.outlineVariant, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '其他登录方式',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: colorScheme.outlineVariant, height: 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDesktopAltLoginButton(
                context,
                colorScheme,
                icon: Icons.chat_bubble_outline,
                label: 'WeChat',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDesktopAltLoginButton(
                context,
                colorScheme,
                icon: Icons.apple,
                label: 'Apple',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDesktopAgreementFooter(context, colorScheme),
      ],
    );
  }

  Widget _buildDesktopAltLoginButton(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _showMessage('$label 登录暂未接入。'),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_desktopControlRadius),
        ),
      ),
    );
  }

  Widget _buildDesktopAgreementFooter(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        Text(
          '登录即代表您同意',
          style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
        ),
        InkWell(
          onTap: () => _showMessage('服务协议暂未接入。'),
          child: Text(
            '服务协议',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.outline,
            ),
          ),
        ),
        Text(
          '与',
          style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
        ),
        InkWell(
          onTap: () => _showMessage('隐私政策暂未接入。'),
          child: Text(
            '隐私政策',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  void _setMode(bool isRegister) {
    if (_isRegister == isRegister) {
      return;
    }
    setState(() {
      _isRegister = isRegister;
      _submitError = null;
      _autovalidateMode = AutovalidateMode.disabled;
      _formKey = GlobalKey<FormState>();
    });
  }

  String? _requiredValidator(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) {
      return '请输入$fieldName';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) {
      return '请再次输入密码';
    }
    if (confirm != _passwordController.text) {
      return '两次密码输入不一致';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _submitError = null;
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final account = _accountController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isRegister) {
        await _authService.registerAndStore(
          account: account,
          password: password,
          displayName: displayName.isEmpty ? account : displayName,
        );
      } else {
        await _authService.loginAndStore(account: account, password: password);
      }

      if (!mounted) {
        return;
      }
      _showMessage(_isRegister ? '注册成功，已登录。' : '登录成功。');
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/home');
      }
    } on ApiException catch (error) {
      _showError(
        _isRegister && error.statusCode == 409
            ? '该账号已存在，请直接登录或更换账号名。'
            : error.briefMessage,
      );
    } on AppException catch (error) {
      _showError(error.briefMessage);
    } catch (_) {
      _showError('操作失败，请稍后再试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _submitError = message;
    });
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
