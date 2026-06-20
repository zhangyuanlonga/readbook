part of 'auth_page.dart';

extension _AuthPageFormSections on _AuthPageState {
  Widget _buildDesktopLoginActionRow(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap:
              _isSubmitting
                  ? null
                  : () => _setRememberPassword(!_rememberPassword),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSelectionIndicator(
                selected: _rememberPassword,
                enabled: !_isSubmitting,
                size: 22,
                semanticLabel: _rememberPassword ? '已记住密码' : '未记住密码',
              ),
              const SizedBox(width: 8),
              Text(
                '记住密码',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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

  Widget _buildModeToggle(
    ColorScheme colorScheme, {
    bool immersiveStyled = false,
  }) {
    if (immersiveStyled) {
      return SizedBox(
        key: const ValueKey<String>('auth_mobile_mode_tabs'),
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: _buildUnderlineModeTab(
                colorScheme,
                label: '登录',
                labelKey: const ValueKey<String>('auth_login_tab_label'),
                selected: !_isRegister,
                onTap: () => _setMode(false),
              ),
            ),
            Expanded(
              child: _buildUnderlineModeTab(
                colorScheme,
                label: '注册',
                labelKey: const ValueKey<String>('auth_register_tab_label'),
                selected: _isRegister,
                onTap: () => _setMode(true),
              ),
            ),
          ],
        ),
      );
    }

    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('登录', key: ValueKey<String>('auth_login_tab_label')),
        ),
        ButtonSegment(
          value: true,
          label: Text('注册', key: ValueKey<String>('auth_register_tab_label')),
        ),
      ],
      selected: {_isRegister},
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
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
            borderRadius: BorderRadius.circular(_authDesktopControlRadius),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 12),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? _authPrimaryColor(colorScheme)
                  : colorScheme.onSurfaceVariant,
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
      ),
    );
  }

  Widget _buildUnderlineModeTab(
    ColorScheme colorScheme, {
    required String label,
    required ValueKey<String> labelKey,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _isSubmitting || selected ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: _authModeTransitionDuration,
              curve: Curves.easeOutCubic,
              style:
                  textTheme.titleMedium?.copyWith(
                    color:
                        selected
                            ? _authPrimaryColor(colorScheme)
                            : colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: 0,
                  ) ??
                  TextStyle(
                    color:
                        selected
                            ? _authPrimaryColor(colorScheme)
                            : colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: 0,
                  ),
              child: Text(label, key: labelKey),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: _authModeTransitionDuration,
              curve: Curves.easeOutCubic,
              width: selected ? 72 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: _authPrimaryColor(colorScheme),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
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
    final inputTokens = appComponentThemeTokensOf(context).input;
    final borderRadius = BorderRadius.circular(inputTokens.radius);
    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: colorScheme.outlineVariant,
        width: inputTokens.borderWidth,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: colorScheme.primary,
        width: inputTokens.focusedBorderWidth,
      ),
    );
    return InputDecoration(
      hintText: hintText ?? labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _authFieldSurfaceColor(colorScheme),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: colorScheme.error,
          width: inputTokens.focusedBorderWidth,
        ),
      ),
    );
  }

  InputDecoration _buildImmersiveInputDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputTokens = appComponentThemeTokensOf(context).input;
    final borderRadius = BorderRadius.circular(inputTokens.radius);
    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: colorScheme.outlineVariant,
        width: inputTokens.borderWidth,
      ),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _authFieldSurfaceColor(colorScheme),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
        letterSpacing: 0,
      ),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: inputTokens.focusedBorderWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: colorScheme.error,
          width: inputTokens.focusedBorderWidth,
        ),
      ),
    );
  }

  Widget _buildAnimatedForm(
    BuildContext context, {
    bool desktopStyled = false,
    bool immersiveStyled = false,
  }) {
    return AnimatedSize(
      duration: _authModeTransitionDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: AppAnimatedSwitcher(
        duration: _authModeTransitionDuration,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: _buildForm(
          context,
          desktopStyled: desktopStyled,
          immersiveStyled: immersiveStyled,
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context, {
    bool desktopStyled = false,
    bool immersiveStyled = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: immersiveStyled ? 6 : 0),
      child: Form(
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
                validator: _validationService.validateAccount,
                decoration:
                    desktopStyled
                        ? _buildDesktopInputDecoration(
                          context: context,
                          labelText: _isRegister ? '账号' : '账号或用户名',
                          hintText: _isRegister ? '请输入账号' : '请输入账号（兼容用户名）',
                          prefixIcon: const Icon(Icons.person_outline),
                        )
                        : immersiveStyled
                        ? _buildImmersiveInputDecoration(
                          context: context,
                          labelText: _isRegister ? '账号' : '账号',
                          hintText: _isRegister ? '请输入账号' : '请输入账号（兼容用户名）',
                          prefixIcon: const Icon(Icons.person_outline),
                          suffixIcon:
                              _accountController.text.isEmpty || _isSubmitting
                                  ? null
                                  : IconButton(
                                    tooltip: '清空账号',
                                    onPressed:
                                        _isSubmitting
                                            ? null
                                            : _clearAccountInput,
                                    icon: const Icon(Icons.cancel_rounded),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.64),
                                  ),
                        )
                        : const InputDecoration(
                          labelText: '账号',
                          hintText: '请输入账号（兼容用户名）',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                onChanged:
                    immersiveStyled ? (_) => _refreshFormVisualState() : null,
              ),
              SizedBox(height: immersiveStyled ? 22 : 12),
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
                validator: _validationService.validateRequiredPassword,
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
                                    : _togglePasswordVisibility,
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        )
                        : immersiveStyled
                        ? _buildImmersiveInputDecoration(
                          context: context,
                          labelText: '密码',
                          hintText: '请输入您的密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : _togglePasswordVisibility,
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
                                    : _togglePasswordVisibility,
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                onChanged:
                    _isRegister ? (_) => _refreshFormVisualState() : null,
                onFieldSubmitted: _isRegister ? null : (_) => _submit(),
              ),
              if (_isRegister) ...[
                SizedBox(height: immersiveStyled ? 10 : 8),
                _buildPasswordStrengthHint(context),
                SizedBox(height: immersiveStyled ? 22 : 12),
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
                          : immersiveStyled
                          ? _buildImmersiveInputDecoration(
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
                SizedBox(height: immersiveStyled ? 22 : 12),
                TextFormField(
                  controller: _confirmController,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  validator:
                      (value) => _validationService.validateConfirmPassword(
                        value,
                        password: _passwordController.text,
                      ),
                  decoration:
                      desktopStyled
                          ? _buildDesktopInputDecoration(
                            context: context,
                            labelText: '确认密码',
                            hintText: '请再次输入密码',
                            prefixIcon: const Icon(
                              Icons.verified_user_outlined,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirm ? '显示确认密码' : '隐藏确认密码',
                              onPressed:
                                  _isSubmitting
                                      ? null
                                      : _toggleConfirmVisibility,
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          )
                          : immersiveStyled
                          ? _buildImmersiveInputDecoration(
                            context: context,
                            labelText: '确认密码',
                            hintText: '请再次输入密码',
                            prefixIcon: const Icon(
                              Icons.verified_user_outlined,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirm ? '显示确认密码' : '隐藏确认密码',
                              onPressed:
                                  _isSubmitting
                                      ? null
                                      : _toggleConfirmVisibility,
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          )
                          : InputDecoration(
                            labelText: '确认密码',
                            hintText: '请再次输入密码',
                            prefixIcon: const Icon(
                              Icons.verified_user_outlined,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirm ? '显示确认密码' : '隐藏确认密码',
                              onPressed:
                                  _isSubmitting
                                      ? null
                                      : _toggleConfirmVisibility,
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
      ),
    );
  }

  Widget _buildPasswordStrengthHint(BuildContext context) {
    final password = _passwordController.text;
    final strength = _validationService.resolvePasswordStrength(password);
    final colorScheme = Theme.of(context).colorScheme;
    final score = strength.score.clamp(0, 4).toInt();
    final activeColor =
        score >= 3 ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final active = index < score;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : 6),
                child: AnimatedContainer(
                  duration: _authModeTransitionDuration,
                  curve: Curves.easeOutCubic,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        active
                            ? activeColor
                            : colorScheme.outlineVariant.withValues(
                              alpha: 0.72,
                            ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          password.isEmpty ? '建议使用 8 位以上，并混合字母和数字。' : strength.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                strength.isStrongPresentation
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton({
    bool desktopStyled = false,
    bool immersiveStyled = false,
    String? label,
  }) {
    final resolvedLabel = label ?? (_isRegister ? '注册并登录' : '登录');
    final colorScheme = Theme.of(context).colorScheme;
    final forceLightForeground = desktopStyled || immersiveStyled;
    return AnimatedScale(
      duration: _authModeTransitionDuration,
      curve: Curves.easeOutCubic,
      scale: _isSubmitting ? 0.985 : 1,
      child: SizedBox(
        height: immersiveStyled ? 50 : 46,
        child: FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style:
              desktopStyled
                  ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.82,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        _authDesktopControlRadius,
                      ),
                    ),
                    elevation: 0,
                  )
                  : immersiveStyled
                  ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colorScheme.primary.withValues(
                      alpha: 0.46,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.82,
                    ),
                    textStyle: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  )
                  : null,
          child: AppAnimatedSwitcher(
            child:
                _isSubmitting
                    ? Row(
                      key: const ValueKey<String>('auth_submitting'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppProgressIndicator(
                          size: 18,
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                          semanticLabel: _isRegister ? '正在注册' : '正在登录',
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isRegister ? '正在注册' : '正在登录',
                          style:
                              forceLightForeground
                                  ? const TextStyle(color: Colors.white)
                                  : null,
                        ),
                      ],
                    )
                    : Text(
                      resolvedLabel,
                      key: ValueKey<String>(resolvedLabel),
                      style:
                          forceLightForeground
                              ? const TextStyle(color: Colors.white)
                              : null,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitchButton(BuildContext context, ColorScheme colorScheme) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => _setMode(!_isRegister),
        style: OutlinedButton.styleFrom(
          backgroundColor: _authQuietSurfaceColor(colorScheme),
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.45,
          ),
          side: BorderSide.none,
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(_isRegister ? '返回登录' : '注册'),
      ),
    );
  }

  Widget _buildAgreementFooter(
    BuildContext context,
    ColorScheme colorScheme, {
    bool immersiveStyled = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final baseColor =
        immersiveStyled
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.68)
            : colorScheme.outline;
    final linkColor =
        immersiveStyled ? colorScheme.primary : colorScheme.outline;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        if (immersiveStyled)
          Icon(
            Icons.check_circle_outline_rounded,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            size: 22,
          ),
        Text(
          '登录即代表您同意',
          style: textTheme.bodySmall?.copyWith(color: baseColor),
        ),
        InkWell(
          onTap: () => _showMessage('服务协议暂未接入。'),
          child: Text(
            '用户协议',
            style: textTheme.bodySmall?.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
          ),
        ),
        Text('与', style: textTheme.bodySmall?.copyWith(color: baseColor)),
        InkWell(
          onTap: () => _showMessage('隐私政策暂未接入。'),
          child: Text(
            '隐私政策',
            style: textTheme.bodySmall?.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
          ),
        ),
      ],
    );
  }
}
