import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/feature_disabled_page.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../application/source_login_ui.dart';
import '../application/source_runtime_session_service.dart';
import 'source_session_status_sheet.dart';

class SourceLoginUiForm extends ConsumerStatefulWidget {
  const SourceLoginUiForm({
    super.key,
    required this.sourceId,
    required this.task,
  });

  final String sourceId;
  final SourceLoginTask task;

  @override
  ConsumerState<SourceLoginUiForm> createState() => _SourceLoginUiFormState();
}

class _SourceLoginUiFormState extends ConsumerState<SourceLoginUiForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, String> _values = <String, String>{};
  late SourceLoginUiSpec _spec;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _spec = SourceLoginUiSpec.fromTask(widget.task);
    _initializeValues();
  }

  @override
  void didUpdateWidget(SourceLoginUiForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task) {
      _disposeControllers();
      _controllers.clear();
      _values.clear();
      _spec = SourceLoginUiSpec.fromTask(widget.task);
      _initializeValues();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    if (_spec.isDynamic) {
      return FeatureDisabledPage(
        title: title,
        message: _spec.diagnostic ?? '该书源使用动态 loginUi JS，当前版本暂不能渲染。',
        icon: Icons.code_rounded,
        actionLabel: '返回',
        onAction: () {
          if (context.canPop()) {
            context.pop(false);
          }
        },
      );
    }
    if (!_spec.isRenderable) {
      return FeatureDisabledPage(
        title: title,
        message: _spec.diagnostic ?? 'loginUi 无法解析为可用表单。',
        icon: Icons.dynamic_form_rounded,
        actionLabel: '返回',
        onAction: () {
          if (context.canPop()) {
            context.pop(false);
          }
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _LoginUiNotice(task: widget.task),
              const SizedBox(height: 16),
              for (final field in _spec.fields) ...[
                _buildField(field),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              AppButton(
                expanded: true,
                onPressed: _isSubmitting ? null : _submit,
                isLoading: _isSubmitting,
                icon: const Icon(Icons.save_rounded),
                label: _isSubmitting ? '提交中' : '保存登录信息',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(SourceLoginUiField field) {
    return switch (field.type) {
      SourceLoginUiFieldType.text => _buildTextField(field, obscure: false),
      SourceLoginUiFieldType.password => _buildTextField(field, obscure: true),
      SourceLoginUiFieldType.select => _buildSelectField(field),
      SourceLoginUiFieldType.toggle => _buildToggleField(field),
      SourceLoginUiFieldType.button => _buildActionButton(field),
    };
  }

  Widget _buildTextField(SourceLoginUiField field, {required bool obscure}) {
    final controller = _controllers[field.name]!;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.next,
      validator: (value) => _requiredMessage(field, value),
      onChanged: (value) => _values[field.name] = value,
    );
  }

  Widget _buildSelectField(SourceLoginUiField field) {
    final options = field.options;
    if (options.isEmpty) {
      return TextFormField(
        initialValue: _values[field.name] ?? '',
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => _requiredMessage(field, value),
        onChanged: (value) => _values[field.name] = value,
      );
    }
    final selected = _values[field.name];
    final value =
        selected != null && options.contains(selected)
            ? selected
            : options.first;
    _values[field.name] = value;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      validator: (value) => _requiredMessage(field, value),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _values[field.name] = value);
      },
    );
  }

  Widget _buildToggleField(SourceLoginUiField field) {
    final onValue = field.options.isNotEmpty ? field.options.first : 'true';
    final offValue = field.options.length > 1 ? field.options[1] : 'false';
    final current = _values[field.name] ?? field.defaultValue ?? onValue;
    final active = current == onValue;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(field.label),
      subtitle: Text(active ? onValue : offValue),
      value: active,
      onChanged: (value) {
        setState(() => _values[field.name] = value ? onValue : offValue);
      },
    );
  }

  Widget _buildActionButton(SourceLoginUiField field) {
    return AppButton(
      variant: AppButtonVariant.secondary,
      expanded: true,
      onPressed: () => unawaited(_runButtonAction(field)),
      icon: const Icon(Icons.open_in_new_rounded),
      label: field.label,
    );
  }

  Future<void> _runButtonAction(SourceLoginUiField field) async {
    final action = field.action?.trim();
    if (action == null || action.isEmpty) {
      _showMessage('该按钮没有配置 action。');
      return;
    }
    final uri = Uri.tryParse(action);
    if (uri != null && uri.hasScheme) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showMessage('无法打开：$action');
      }
      return;
    }
    _showMessage('该按钮 action 需要 Rust JS 上下文执行，后续阶段接入。');
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final loginInfo = <String, String>{};
      for (final field in _spec.fields.where((field) => field.capturesInput)) {
        final value =
            field.type == SourceLoginUiFieldType.text ||
                    field.type == SourceLoginUiFieldType.password
                ? _controllers[field.name]?.text.trim() ?? ''
                : _values[field.name]?.trim() ?? '';
        loginInfo[field.name] = value;
      }
      final snapshot = await ref
          .read(sourceRuntimeSessionServiceProvider)
          .submitLoginResult(
            sourceId: _sourceId,
            loginInfoJson: jsonEncode(loginInfo),
          );
      if (!mounted) return;
      await showAdaptiveActionSurface<void>(
        context: context,
        maxWidth: 520,
        builder:
            (context) => SourceSessionStatusSheet(
              sourceName: widget.task.sourceName,
              snapshot: snapshot,
              showActions: false,
            ),
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('保存登录信息失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _initializeValues() {
    for (final field in _spec.fields) {
      if (field.type == SourceLoginUiFieldType.button) {
        continue;
      }
      final initial =
          field.defaultValue ??
          (field.options.isNotEmpty ? field.options.first : '');
      _values[field.name] = initial;
      if (field.type == SourceLoginUiFieldType.text ||
          field.type == SourceLoginUiFieldType.password) {
        _controllers[field.name] = TextEditingController(text: initial);
      }
    }
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
  }

  String? _requiredMessage(SourceLoginUiField field, String? value) {
    if (!field.required) {
      return null;
    }
    if ((value ?? '').trim().isEmpty) {
      return '请填写${field.label}';
    }
    return null;
  }

  String get _title {
    final name = widget.task.sourceName.trim();
    return name.isEmpty ? '书源登录' : '$name 登录';
  }

  String get _sourceId {
    final taskSourceId = widget.task.sourceId.trim();
    return taskSourceId.isNotEmpty ? taskSourceId : widget.sourceId.trim();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AppFeedback.showSnackBar(context, message: message);
  }
}

class _LoginUiNotice extends StatelessWidget {
  const _LoginUiNotice({required this.task});

  final SourceLoginTask task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCheck = (task.loginCheckJs ?? '').trim().isNotEmpty;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasCheck
                    ? '表单会保存为 loginInfo，后续请求由 Rust 网关读取。该源还配置了 loginCheckJs，自动校验将在 Rust 兼容阶段接入。'
                    : '表单会保存为 loginInfo，后续请求由 Rust 网关读取并完成书源登录逻辑。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
