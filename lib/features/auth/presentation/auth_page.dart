import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/theme/app_component_theme_tokens.dart';
import '../../../app/widgets/foundation/app_feedback.dart';
import '../../../app/widgets/foundation/app_selection_indicator.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../application/auth_form_validation_service.dart';
import '../providers.dart';

part 'auth_page_layout_sections.dart';
part 'auth_page_form_sections.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

const Duration _authKeyboardInsetAnimationDuration = Duration(
  milliseconds: 180,
);
const Duration _authModeTransitionDuration = Duration(milliseconds: 220);
const double _authMobilePanelRadius = 30;
const double _authDesktopPanelRadius = 24;
const double _authDesktopControlRadius = 12;
const double _authMediumContentMaxWidth = 560;

class _AuthPageState extends ConsumerState<AuthPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthService _authService;
  late final AuthFormValidationService _validationService;

  bool _isRegister = false;
  bool _isSubmitting = false;
  bool _rememberPassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _submitError;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _validationService = ref.read(authFormValidationServiceProvider);
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

    return _buildMobileAuthPage(
      context,
      keyboardInset: keyboardInset,
      bottomSafe: bottomSafe,
      horizontal: horizontal,
      colorScheme: colorScheme,
    );
  }

  void _setMode(bool isRegister) {
    if (_isRegister == isRegister) {
      return;
    }
    Feedback.forTap(context);
    setState(() {
      _isRegister = isRegister;
      _submitError = null;
      _autovalidateMode = AutovalidateMode.disabled;
      _formKey = GlobalKey<FormState>();
    });
  }

  void _refreshFormVisualState() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _clearAccountInput() {
    _accountController.clear();
    _refreshFormVisualState();
  }

  void _setRememberPassword(bool rememberPassword) {
    setState(() {
      _rememberPassword = rememberPassword;
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmVisibility() {
    setState(() {
      _obscureConfirm = !_obscureConfirm;
    });
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
        context.go('/bookshelf');
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
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ||
                  message.contains('请') ||
                  message.contains('已存在')
              ? AppFeedbackTone.error
              : AppFeedbackTone.success,
      useHaptics: false,
    );
  }
}
