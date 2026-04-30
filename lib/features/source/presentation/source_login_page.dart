import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../runtime/sources/source_contract.dart';
import '../application/source_login_browser_service.dart';
import '../application/source_login_runtime_service.dart';
import '../providers.dart';

class SourceLoginPage extends ConsumerStatefulWidget {
  const SourceLoginPage({
    super.key,
    required this.sourceId,
    this.sourceLoginRuntimeService,
    this.sourceLoginBrowserService,
    this.embedded = false,
    this.parentScrollController,
  });

  final String sourceId;
  final SourceLoginRuntimeService? sourceLoginRuntimeService;
  final SourceLoginBrowserService? sourceLoginBrowserService;
  final bool embedded;
  final ScrollController? parentScrollController;

  @override
  ConsumerState<SourceLoginPage> createState() => _SourceLoginPageState();
}

class _SourceLoginPageState extends ConsumerState<SourceLoginPage> {
  late final SourceLoginRuntimeService _sourceLoginRuntimeService;
  late final SourceLoginBrowserService _sourceLoginBrowserService;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorText;
  String? _statusText;
  _MessageTone _statusTone = _MessageTone.info;
  SourceLoginPresentation? _presentation;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final Map<String, String> _selectValues = <String, String>{};
  final Map<String, String> _toggleValues = <String, String>{};
  final Map<String, String> _baselineValues = <String, String>{};

  @override
  void initState() {
    super.initState();
    _sourceLoginRuntimeService =
        widget.sourceLoginRuntimeService ??
        ref.read(sourceLoginRuntimeServiceProvider);
    _sourceLoginBrowserService =
        widget.sourceLoginBrowserService ??
        ref.read(sourceLoginBrowserServiceProvider);
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
      _statusText = null;
    });

    try {
      final presentation = await _sourceLoginRuntimeService.loadPresentation(
        widget.sourceId,
        ui: _buildUiContext(),
      );
      if (!mounted) {
        return;
      }
      if (presentation == null) {
        setState(() {
          _presentation = null;
          _errorText = '当前书源未声明登录面板。';
          _isLoading = false;
        });
        return;
      }

      _syncFormState(presentation);
      setState(() {
        _presentation = presentation;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _presentation = null;
        _errorText = error is AppException ? error.briefMessage : '登录配置加载失败。';
        _isLoading = false;
      });
    }
  }

  void _syncFormState(SourceLoginPresentation presentation) {
    final nextFieldNames =
        presentation.fields.map((field) => field.name).toSet();
    final staleKeys = _controllers.keys
        .where((key) => !nextFieldNames.contains(key))
        .toList(growable: false);
    for (final key in staleKeys) {
      _controllers.remove(key)?.dispose();
      _focusNodes.remove(key)?.dispose();
      _selectValues.remove(key);
      _toggleValues.remove(key);
      _baselineValues.remove(key);
    }

    for (final field in presentation.fields) {
      if (field.type == SourceLoginFieldType.button) {
        continue;
      }
      final currentValue = presentation.formData[field.name] ?? '';
      switch (field.type) {
        case SourceLoginFieldType.text:
        case SourceLoginFieldType.password:
        case SourceLoginFieldType.textarea:
          final controller = _controllers.putIfAbsent(
            field.name,
            () => TextEditingController(text: currentValue),
          );
          _focusNodes.putIfAbsent(field.name, () {
            final node = FocusNode();
            node.addListener(() {
              if (!node.hasFocus) {
                _handleTextFieldCommitByName(field.name);
              }
            });
            return node;
          });
          if (controller.text != currentValue) {
            controller.text = currentValue;
          }
          _baselineValues[field.name] = currentValue;
          break;
        case SourceLoginFieldType.select:
          _selectValues[field.name] = currentValue;
          _baselineValues[field.name] = currentValue;
          break;
        case SourceLoginFieldType.toggle:
          _toggleValues[field.name] =
              currentValue.isNotEmpty
                  ? currentValue
                  : (field.defaultValue ?? _toggleDefaultValue(field));
          _baselineValues[field.name] = _toggleValues[field.name] ?? '';
          break;
        case SourceLoginFieldType.note:
        case SourceLoginFieldType.divider:
        case SourceLoginFieldType.button:
          break;
      }
    }
  }

  Map<String, String> _currentFormData() {
    final data = <String, String>{};
    final presentation = _presentation;
    if (presentation == null) {
      return data;
    }
    for (final field in presentation.fields) {
      if (field.type == SourceLoginFieldType.button) {
        continue;
      }
      switch (field.type) {
        case SourceLoginFieldType.text:
        case SourceLoginFieldType.password:
        case SourceLoginFieldType.textarea:
          data[field.name] = _controllers[field.name]?.text.trim() ?? '';
          break;
        case SourceLoginFieldType.select:
          data[field.name] = _selectValues[field.name] ?? '';
          break;
        case SourceLoginFieldType.toggle:
          data[field.name] = _toggleValues[field.name] ?? '';
          break;
        case SourceLoginFieldType.note:
        case SourceLoginFieldType.divider:
        case SourceLoginFieldType.button:
          break;
      }
    }
    return data;
  }

  Future<void> _submit({String? actionCode, bool isLongClick = false}) async {
    final presentation = _presentation;
    if (presentation == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _sourceLoginRuntimeService.submit(
        widget.sourceId,
        formData: _currentFormData(),
        ui: _buildUiContext(),
        actionCode: actionCode,
        isLongClick: isLongClick,
      );
      if (!mounted) {
        return;
      }
      _syncFormState(result.presentation);
      setState(() {
        _presentation = result.presentation;
        _statusText = result.message ?? (actionCode == null ? '操作已完成。' : null);
        _statusTone = _MessageTone.success;
      });
      final message = result.message;
      if (!widget.embedded &&
          message != null &&
          message.isNotEmpty &&
          mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is AppException ? error.briefMessage : '登录操作执行失败。';
      setState(() {
        _statusText = message;
        _statusTone = _MessageTone.error;
      });
      if (!widget.embedded) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final body = LayoutBuilder(
      builder: (context, _) {
        final maxWidth = AppLayout.pageContentMaxWidth(
          context,
          maxWidth: AppLayout.systemSettingsContentMaxWidth,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                      controller: widget.parentScrollController,
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        16,
                        horizontal,
                        24,
                      ),
                      children: [
                        if (_errorText != null)
                          _buildMessageCard(
                            context,
                            _errorText!,
                            tone: _MessageTone.error,
                          )
                        else ...[
                          if (_statusText != null) ...[
                            _buildMessageCard(
                              context,
                              _statusText!,
                              tone: _statusTone,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildFieldGrid(context),
                        ],
                      ],
                    ),
          ),
        );
      },
    );

    if (widget.embedded) {
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _presentation?.sourceName ?? '书源登录',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => _submit(),
                    tooltip: '确认',
                    icon:
                        _isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_presentation?.sourceName ?? '书源登录'),
        actions: [
          IconButton(
            onPressed: _isSubmitting ? null : () => _submit(),
            tooltip: '确认',
            icon:
                _isSubmitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }

  SourceUiContext _buildUiContext() {
    return SourceUiContext(
      toastHandler: (message) => _showToast(message),
      longToastHandler: (message) => _showLongToast(message),
      openUrlHandler:
          ({required url, title}) => _openUrl(url: url, title: title),
      alertHandler:
          ({required message, title, confirmText}) => _showAlert(
            message: message,
            title: title,
            confirmText: confirmText,
          ),
      confirmHandler:
          ({required message, title, confirmText, cancelText}) =>
              _confirmAction(
                message: message,
                title: title,
                confirmText: confirmText,
                cancelText: cancelText,
              ),
      promptHandler:
          ({
            required message,
            title,
            initialValue,
            confirmText,
            cancelText,
            obscureText = false,
          }) => _promptValue(
            message: message,
            title: title,
            initialValue: initialValue,
            confirmText: confirmText,
            cancelText: cancelText,
            obscureText: obscureText,
          ),
      openBrowserAwaitHandler: ({
        required String url,
        String? title,
        bool refetchAfterSuccess = true,
        String? html,
      }) async {
        final response = await _sourceLoginBrowserService.openBrowserAwait(
          sourceId: widget.sourceId,
          url: url,
          title: title,
          refetchAfterSuccess: refetchAfterSuccess,
          html: html,
        );
        return response.toUiPayload();
      },
      verificationCodeHandler: (imageUrl) => _promptVerificationCode(imageUrl),
    );
  }

  Future<void> _openUrl({required String url, String? title}) async {
    final normalizedUrl = url.trim();
    if (!mounted || normalizedUrl.isEmpty) {
      return;
    }
    await _sourceLoginBrowserService.openUrl(
      sourceId: widget.sourceId,
      url: normalizedUrl,
      title: title,
    );
  }

  Future<bool> _confirmAction({
    required String message,
    String? title,
    String? confirmText,
    String? cancelText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            (title?.trim().isNotEmpty ?? false) ? title!.trim() : '确认操作',
          ),
          content: Text(message.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                (cancelText?.trim().isNotEmpty ?? false)
                    ? cancelText!.trim()
                    : '取消',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                (confirmText?.trim().isNotEmpty ?? false)
                    ? confirmText!.trim()
                    : '确认',
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showAlert({
    required String message,
    String? title,
    String? confirmText,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            (title?.trim().isNotEmpty ?? false) ? title!.trim() : '提示',
          ),
          content: Text(message.trim()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                (confirmText?.trim().isNotEmpty ?? false)
                    ? confirmText!.trim()
                    : '知道了',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptValue({
    required String message,
    String? title,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    try {
      return await showDialog<String?>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              (title?.trim().isNotEmpty ?? false) ? title!.trim() : '输入内容',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.trim().isNotEmpty) ...[
                  Text(message.trim()),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text(
                  (cancelText?.trim().isNotEmpty ?? false)
                      ? cancelText!.trim()
                      : '取消',
                ),
              ),
              FilledButton(
                onPressed:
                    () =>
                        Navigator.of(dialogContext).pop(controller.text.trim()),
                child: Text(
                  (confirmText?.trim().isNotEmpty ?? false)
                      ? confirmText!.trim()
                      : '确认',
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showToast(String message) async {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.trim())));
  }

  Future<void> _showLongToast(String message) async {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.trim()),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<String> _promptVerificationCode(String imageUrl) async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('输入验证码'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVerificationImage(imageUrl),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed:
                    () =>
                        Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
      return (result ?? '').trim();
    } finally {
      controller.dispose();
    }
  }

  Widget _buildVerificationImage(String imageUrl) {
    final trimmed = imageUrl.trim();
    if (trimmed.startsWith('data:image')) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex > 0) {
        final bytes = base64Decode(trimmed.substring(commaIndex + 1));
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.contain,
          height: 120,
        );
      }
    }
    return Image.network(trimmed, fit: BoxFit.contain, height: 120);
  }

  Widget _buildField(BuildContext context, SourceLoginField field) {
    final label =
        field.label?.trim().isNotEmpty == true
            ? field.label!.trim()
            : field.name;
    return switch (field.type) {
      SourceLoginFieldType.text => TextField(
        controller: _controllers[field.name],
        focusNode: _focusNodes[field.name],
        enabled: !_isSubmitting,
        onEditingComplete: () => _handleTextFieldCommit(field),
        decoration: _buildInputDecoration(context, label: label),
      ),
      SourceLoginFieldType.password => TextField(
        controller: _controllers[field.name],
        focusNode: _focusNodes[field.name],
        enabled: !_isSubmitting,
        obscureText: true,
        onEditingComplete: () => _handleTextFieldCommit(field),
        decoration: _buildInputDecoration(context, label: label),
      ),
      SourceLoginFieldType.textarea => TextField(
        controller: _controllers[field.name],
        focusNode: _focusNodes[field.name],
        enabled: !_isSubmitting,
        minLines: 4,
        maxLines: 8,
        onEditingComplete: () => _handleTextFieldCommit(field),
        decoration: _buildInputDecoration(
          context,
          label: label,
          alignLabelWithHint: true,
        ),
      ),
      SourceLoginFieldType.select => DropdownButtonFormField<String>(
        initialValue: _selectValues[field.name],
        decoration: _buildInputDecoration(context, label: label),
        items: field.options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(growable: false),
        onChanged:
            _isSubmitting
                ? null
                : (value) async {
                  setState(() {
                    _selectValues[field.name] = value ?? '';
                    _baselineValues[field.name] = value ?? '';
                  });
                  if ((field.action ?? '').trim().isNotEmpty) {
                    await _submit(actionCode: field.action);
                  }
                },
      ),
      SourceLoginFieldType.toggle => _buildToggleField(context, field, label),
      SourceLoginFieldType.note => _buildNoteField(context, label),
      SourceLoginFieldType.divider => _buildDividerField(context, label),
      SourceLoginFieldType.button => _buildActionButton(context, field, label),
    };
  }

  Widget _buildFieldGrid(BuildContext context) {
    final presentation = _presentation;
    if (presentation == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final availableWidth = constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: presentation.fields
              .map((field) {
                final width = _fieldWidth(
                  maxWidth: availableWidth,
                  spacing: spacing,
                  field: field,
                );
                final child = SizedBox(
                  width: width,
                  child: _buildFieldShell(
                    context,
                    field,
                    child: _buildField(context, field),
                  ),
                );
                return child;
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildFieldShell(
    BuildContext context,
    SourceLoginField field, {
    required Widget child,
  }) {
    final alignment = _fieldAlignment(field.style.layoutJustifySelf);
    if (field.type == SourceLoginFieldType.divider ||
        field.type == SourceLoginFieldType.note) {
      return Align(alignment: alignment, child: child);
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: alignment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            field.type == SourceLoginFieldType.button ? 4 : 0,
          ),
          child: child,
        ),
      ),
    );
  }

  double _fieldWidth({
    required double maxWidth,
    required double spacing,
    required SourceLoginField field,
  }) {
    final basis = field.style.layoutFlexBasisPercent;
    if (basis == null || basis <= 0 || basis >= 1) {
      return maxWidth;
    }
    final width = (maxWidth * basis) - spacing;
    return width.clamp(140.0, maxWidth).toDouble();
  }

  Alignment _fieldAlignment(String? justifySelf) {
    switch ((justifySelf ?? '').trim().toLowerCase()) {
      case 'center':
        return Alignment.center;
      case 'flex_end':
      case 'end':
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  String _toggleDefaultValue(SourceLoginField field) {
    if (field.options.isNotEmpty) {
      return field.options.first.value;
    }
    return 'off';
  }

  Widget _buildNoteField(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildDividerField(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        if (label.trim().isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String label,
    bool alignLabelWithHint = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.75),
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildToggleField(
    BuildContext context,
    SourceLoginField field,
    String label,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final value =
        _toggleValues[field.name]?.trim().isNotEmpty == true
            ? _toggleValues[field.name]!
            : _toggleDefaultValue(field);
    final options =
        field.options.isNotEmpty
            ? field.options
            : const <SourceLoginFieldOption>[
              SourceLoginFieldOption(label: '关闭', value: 'off'),
              SourceLoginFieldOption(label: '开启', value: 'on'),
            ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: options
                  .map((option) {
                    final selected = option.value == value;
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap:
                            _isSubmitting
                                ? null
                                : () async {
                                  final next = option.value;
                                  setState(() {
                                    _toggleValues[field.name] = next;
                                    _baselineValues[field.name] = next;
                                  });
                                  if ((field.action ?? '').trim().isNotEmpty) {
                                    await _submit(actionCode: field.action);
                                  }
                                },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? colorScheme.primaryContainer
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            option.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              color:
                                  selected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    SourceLoginField field,
    String label,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isSubmitting ? null : () => _submit(actionCode: field.action),
        onLongPress:
            _isSubmitting
                ? null
                : () => _submit(actionCode: field.action, isLongClick: true),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTextFieldCommit(SourceLoginField field) async {
    final action = (field.action ?? '').trim();
    if (action.isEmpty || _isSubmitting) {
      return;
    }
    final current = _controllers[field.name]?.text.trim() ?? '';
    final previous = _baselineValues[field.name] ?? '';
    if (current == previous) {
      return;
    }
    _baselineValues[field.name] = current;
    await _submit(actionCode: action);
  }

  Future<void> _handleTextFieldCommitByName(String fieldName) async {
    SourceLoginField? field;
    for (final item in _presentation?.fields ?? const <SourceLoginField>[]) {
      if (item.name == fieldName &&
          (item.type == SourceLoginFieldType.text ||
              item.type == SourceLoginFieldType.password ||
              item.type == SourceLoginFieldType.textarea)) {
        field = item;
        break;
      }
    }
    if (field == null) {
      return;
    }
    await _handleTextFieldCommit(field);
  }

  Widget _buildMessageCard(
    BuildContext context,
    String message, {
    _MessageTone tone = _MessageTone.info,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      _MessageTone.info => (
        colorScheme.surfaceContainerLow,
        colorScheme.onSurfaceVariant,
      ),
      _MessageTone.success => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      _MessageTone.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: foreground, height: 1.35),
      ),
    );
  }
}

enum _MessageTone { info, success, error }
