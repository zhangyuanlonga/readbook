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

  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthService _authService;

  bool _isRegister = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _accountController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
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
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
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
                  children: [
                    AppFadeSlideTransition(child: _buildIntroCard(context)),
                    SizedBox(height: metrics.contentGap),
                    AppFadeSlideTransition(
                      delay: const Duration(milliseconds: 48),
                      child: _buildModeToggle(colorScheme),
                    ),
                    SizedBox(height: metrics.contentGap),
                    AppFadeSlideTransition(
                      delay: const Duration(milliseconds: 72),
                      child: _buildFormCard(context),
                    ),
                    SizedBox(height: metrics.sectionGap),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: AppAnimatedSwitcher(
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  key: ValueKey<String>('auth_submitting'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  _isRegister ? '注册并登录' : '登录',
                                  key: ValueKey<String>(
                                    _isRegister ? 'register' : 'login',
                                  ),
                                ),
                      ),
                    ),
                    SizedBox(height: metrics.contentGap),
                    Text(
                      _isRegister
                          ? '继续即表示你同意相关服务条款与隐私政策。'
                          : '没有账号？可切换到注册创建新账号。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_stories_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRegister ? '欢迎加入 Selune' : '欢迎回来',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegister
                        ? '注册时可自定义账号与显示名，后续可同步阅读进度与账号权益。'
                        : '登录后可继续同步阅读数据与账号权益。',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          _isSubmitting
              ? null
              : (value) {
                setState(() {
                  _isRegister = value.first;
                });
              },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(colorScheme.surface),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
        child: Column(
          children: [
            TextField(
              controller: _accountController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '账号',
                hintText: '请输入账号（兼容用户名）',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction:
                  _isRegister ? TextInputAction.next : TextInputAction.done,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () {
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
              onSubmitted: _isRegister ? null : (_) => _submit(),
            ),
            if (_isRegister) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '显示名',
                  hintText: '请输入显示名（可选）',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '确认密码',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    onPressed: () {
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
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final account = _accountController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (account.isEmpty || password.isEmpty) {
      _showMessage('请输入账号和密码。');
      return;
    }
    if (_isRegister && password != confirm) {
      _showMessage('两次密码输入不一致。');
      return;
    }

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
      _showMessage(
        _isRegister && error.statusCode == 409
            ? '该账号已存在，请直接登录或更换账号名。'
            : error.briefMessage,
      );
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('操作失败，请稍后再试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
