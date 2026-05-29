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
        backgroundColor: WidgetStateProperty.all(colorScheme.surface),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
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
              decoration: const InputDecoration(
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
              decoration: InputDecoration(
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
                decoration: const InputDecoration(
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
                decoration: InputDecoration(
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

  Widget _buildSubmitButton() {
    final label = _isRegister ? '注册并登录' : '登录';
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submit,
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
                  : Text(label, key: ValueKey<String>(label)),
        ),
      ),
    );
  }

  Widget _buildModeHint(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          _isRegister ? '继续即表示你同意相关服务条款与隐私政策。' : '还没有账号？',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _isSubmitting ? null : () => _setMode(!_isRegister),
          child: Text(_isRegister ? '已有账号，返回登录' : '创建新账号'),
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
        context.go('/profile');
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
