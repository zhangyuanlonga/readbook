import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(16, 14, 16, 14);

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isRegister = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? '注册' : '登录')),
      body: LayoutBuilder(
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                children: [
                  _buildIntroCard(context),
                  const SizedBox(height: 12),
                  _buildModeToggle(colorScheme),
                  const SizedBox(height: 12),
                  _buildFormCard(context),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(_isRegister ? '注册并登录' : '登录'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRegister ? '继续即表示你同意相关服务条款与隐私政策。' : '没有账号？可切换到注册创建新账号。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
        padding: _cardPadding,
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
                    _isRegister ? '欢迎加入书享阅读' : '欢迎回来',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegister ? '注册后可同步阅读进度与账号权益。' : '登录后可继续同步阅读数据与账号权益。',
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
        padding: _cardPadding,
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入用户名',
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
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (username.isEmpty || password.isEmpty) {
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
          username: username,
          password: password,
        );
      } else {
        await _authService.loginAndStore(
          username: username,
          password: password,
        );
      }

      if (!mounted) {
        return;
      }
      _showMessage(_isRegister ? '注册成功，已登录。' : '登录成功。');
      context.go('/profile');
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
