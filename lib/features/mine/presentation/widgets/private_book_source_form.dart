// UI-GOV-EXEMPT-FILE: list-performance layout-builder
// reason: Phase 10 reviewed this form; shrinkWrap and LayoutBuilder are bounded form-layout helpers.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/platform/app_platform_capabilities.dart';
import '../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../../app/widgets/foundation/foundation.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../source/application/external_import_catalog.dart';
import '../../application/book_source_import_payload.dart';
import '../../application/private_book_source_provider.dart';
import '../../application/private_book_source_service.dart';
import 'private_book_source_action_surfaces.dart';

const int _maxBookSourceImportBytes = 10 * 1024 * 1024;

Future<BookSourceImportMethod?> _selectBookSourceImportMethod(
  BuildContext context,
) {
  return showAdaptiveActionSurface<BookSourceImportMethod>(
    context: context,
    maxWidth: 460,
    padding: EdgeInsets.zero,
    builder: (context) => const BookSourceImportMethodSheet(),
  );
}

Future<_PreparedBookSourceImport> _prepareUrlImport(String url) async {
  final raw = await _loadRawImportFromUrl(url);
  return _prepareLoadedImport(method: BookSourceImportMethod.url, raw: raw);
}

Future<_PreparedBookSourceImport> _prepareLoadedImport({
  required BookSourceImportMethod method,
  required _RawBookSourceImport raw,
}) async {
  _ensureCreateImportSize(raw.text);
  final payload = await compute(parseBookSourceImportPayload, raw.text);
  final imported = _PreparedBookSourceImport(
    label: raw.label,
    payload: payload,
  );
  AppLogger.instance.info(
    'Book source JSON loaded',
    context: <String, Object?>{
      'method': method.name,
      'bytes': payload.sizeBytes,
      'lines': payload.lineCount,
    },
  );
  return imported;
}

Future<_RawBookSourceImport> _loadRawImportFromUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.trim().isEmpty) {
    throw const FormatException('请输入 http/https 链接');
  }
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
    ),
  );
  final response = await dio.get<String>(
    uri.toString(),
    options: Options(
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (_) => true,
    ),
  );
  final statusCode = response.statusCode ?? 0;
  if (statusCode < 200 || statusCode >= 300) {
    throw FormatException('链接请求失败（$statusCode）');
  }
  final text = response.data ?? '';
  if (text.trim().isEmpty) {
    throw const FormatException('链接返回内容为空');
  }
  return _RawBookSourceImport(text: text, label: uri.host);
}

Future<_RawBookSourceImport?> _loadRawImportFromFile() async {
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[
      ExternalImportCatalog.bookSourceJsonTypeGroup,
    ],
    confirmButtonText: '选择书源文件',
  );
  if (file == null) {
    return null;
  }
  final size = await file.length();
  if (size > _maxBookSourceImportBytes) {
    throw const FormatException('文件过大，最大支持 10 MB');
  }
  final text = await file.readAsString();
  final label = file.name.trim().isEmpty ? '本地文件' : file.name.trim();
  return _RawBookSourceImport(text: text, label: label);
}

Future<_RawBookSourceImport> _loadRawImportFromClipboard() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  if (text.trim().isEmpty) {
    throw const FormatException('剪贴板没有 JSON 文本');
  }
  return _RawBookSourceImport(text: text, label: '剪贴板');
}

void _ensureCreateImportSize(String value) {
  if (bookSourceUtf8SizeOf(value) > _maxBookSourceImportBytes) {
    throw const FormatException('文件过大，最大支持 10 MB');
  }
}

void _showImportSuccess(
  BuildContext context,
  _PreparedBookSourceImport imported,
) {
  AppFeedback.showSnackBar(
    context,
    message: '已加载书源 JSON：${formatBookSourceSize(imported.payload.sizeBytes)}',
    tone: AppFeedbackTone.success,
    useHaptics: false,
  );
}

void _showImportFailure(
  BuildContext context, {
  required BookSourceImportMethod method,
  required String message,
}) {
  AppLogger.instance.warn(
    'Book source JSON import failed',
    context: <String, Object?>{'method': method.name, 'message': message},
  );
  AppFeedback.showSnackBar(
    context,
    message: message,
    tone: AppFeedbackTone.error,
    useHaptics: false,
  );
}

class PrivateBookSourceForm extends ConsumerStatefulWidget {
  const PrivateBookSourceForm({
    super.key,
    this.item,
    this.initialImportMethod = BookSourceImportMethod.paste,
  });

  final PrivateBookSourceItem? item;
  final BookSourceImportMethod initialImportMethod;

  @override
  ConsumerState<PrivateBookSourceForm> createState() =>
      PrivateBookSourceFormState();
}

class PrivateBookSourceFormState extends ConsumerState<PrivateBookSourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _groupController;
  late final TextEditingController _sourceController;
  late final TextEditingController _urlController;
  late final TextEditingController _previewController;
  late BookSourceImportMethod _selectedImportMethod;
  String _type = 'novel';
  bool _saving = false;
  bool _loadingSource = false;
  bool _groupEdited = false;
  bool _previewExpanded = false;
  String? _loadedUrl;
  String? _sourceLabel;
  String? _loadError;
  int _sourceLineCount = 0;
  int _sourceSizeBytes = 0;

  bool get _isEditing => widget.item != null;
  bool get _hasLoadedSource => _sourceController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _groupController = TextEditingController(text: item?.groupName ?? '');
    _sourceController = TextEditingController(
      text:
          item?.sourceJson.isNotEmpty == true
              ? item!.sourceJson
              : item?.sourceCode ?? '',
    );
    _urlController = TextEditingController();
    _previewController = TextEditingController();
    _selectedImportMethod = widget.initialImportMethod;
    _type =
        item?.supportedTypes.isNotEmpty == true
            ? item!.supportedTypes.first
            : 'novel';
    _loadInitialPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _groupController.dispose();
    _sourceController.dispose();
    _urlController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _isEditing ? '编辑书源' : '新增书源',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _saving ? '保存中' : '保存',
                      onPressed: (_saving || _loadingSource) ? null : _save,
                      color: colorScheme.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      icon:
                          _saving
                              ? const AppProgressIndicator(
                                size: 18,
                                strokeWidth: 2,
                                semanticLabel: '保存私人书源',
                              )
                              : const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _PrivateSourceSectionHeader(title: '基础信息'),
                const SizedBox(height: 12),
                _PrivateSourceField(
                  label: '名称',
                  child: TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _privateSourceInputDecoration(
                      hintText: '请输入书源名称',
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? '请填写名称'
                                : null,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final typeField = _PrivateSourceField(
                      label: '类型',
                      child: AppDropdownField<String>(
                        value: _type,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        options: const [
                          AppDropdownOption(value: 'novel', label: '小说'),
                          AppDropdownOption(value: 'comic', label: '漫画'),
                          AppDropdownOption(value: 'audio', label: '音频'),
                          AppDropdownOption(value: 'video', label: '视频'),
                        ],
                        onSelected: (value) {
                          if (value != null) {
                            setState(() {
                              _type = value;
                            });
                          }
                        },
                      ),
                    );
                    final groupField = _PrivateSourceField(
                      label: '分组',
                      child: _PrivateGroupAutocompleteField(
                        controller: _groupController,
                        groupsAsync: groupsAsync,
                        decoration: _privateSourceInputDecoration(
                          hintText: '选择已有分组，或输入新分组名',
                        ),
                        onChanged: () {
                          _groupEdited = true;
                        },
                      ),
                    );
                    if (constraints.maxWidth >= 560) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: typeField),
                          const SizedBox(width: 12),
                          Expanded(child: groupField),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        typeField,
                        const SizedBox(height: 12),
                        groupField,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _PrivateSourceField(
                  label: '描述',
                  child: TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: _privateSourceInputDecoration(
                      hintText: '可填写用途、来源或备注',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildImportSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PrivateSourceSectionHeader(
          title: '书源 JSON',
          trailing: AppButton(
            variant: AppButtonVariant.text,
            size: AppButtonSize.compact,
            onPressed: _saving || _loadingSource ? null : _changeImportMethod,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: _importMethodLabel(_selectedImportMethod),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildJsonMethodInput(context),
        if (_loadingSource) ...<Widget>[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Text(
            '正在读取书源 JSON',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_loadError != null) ...<Widget>[
          const SizedBox(height: 12),
          _ImportErrorBanner(message: _loadError!),
        ],
        if (_hasLoadedSource) ...<Widget>[
          const SizedBox(height: 12),
          _BookSourcePreviewCard(
            label: _sourceLabel ?? '已加载 JSON',
            previewController: _previewController,
            lineCount: _sourceLineCount,
            sizeBytes: _sourceSizeBytes,
            expanded: _previewExpanded,
            onToggleExpanded: () {
              setState(() {
                _previewExpanded = !_previewExpanded;
              });
            },
            onClear: _clearLoadedSource,
          ),
        ],
      ],
    );
  }

  Widget _buildJsonMethodInput(BuildContext context) {
    switch (_selectedImportMethod) {
      case BookSourceImportMethod.url:
        return _UrlJsonSourceInput(
          controller: _urlController,
          enabled: !_saving && !_loadingSource,
          hasLoadedSource: _hasLoadedSource,
        );
      case BookSourceImportMethod.file:
        return AppTaskActionCard(
          title: _hasLoadedSource ? '重新选择书源文件' : '添加书源文件',
          description: '支持选择 .json 或 .txt 文件。',
          icon: Icons.folder_open_rounded,
          dashedBorder: !_hasLoadedSource,
          onTap:
              _saving || _loadingSource
                  ? null
                  : () => unawaited(_loadFileSource()),
        );
      case BookSourceImportMethod.paste:
        return AppTaskActionCard(
          title: _hasLoadedSource ? '重新读取剪贴板' : '粘贴 JSON',
          description: '从系统剪贴板读取书源 JSON 文本。',
          icon: Icons.copy_rounded,
          dashedBorder: !_hasLoadedSource,
          onTap:
              _saving || _loadingSource
                  ? null
                  : () => unawaited(_loadClipboardSource()),
        );
    }
  }

  Future<void> _changeImportMethod() async {
    final method = await _selectBookSourceImportMethod(context);
    if (method == null || !mounted) {
      return;
    }
    setState(() {
      _selectedImportMethod = method;
      _loadedUrl = null;
      _clearLoadedSourceValues();
    });
  }

  Future<void> _loadFileSource() {
    final localFileImport =
        ref.read(appPlatformCapabilitiesProvider).localFileImport;
    if (!localFileImport.isSupported) {
      _setLoadError(localFileImport.reason ?? '当前平台暂不支持从本地文件选择器导入。');
      return Future<void>.value();
    }
    return _loadActionSource(
      method: BookSourceImportMethod.file,
      loader: _loadRawImportFromFile,
    );
  }

  Future<void> _loadClipboardSource() {
    return _loadActionSource(
      method: BookSourceImportMethod.paste,
      loader: _loadRawImportFromClipboard,
    );
  }

  Future<void> _loadActionSource({
    required BookSourceImportMethod method,
    required Future<_RawBookSourceImport?> Function() loader,
  }) async {
    if (_loadingSource) {
      return;
    }
    setState(() {
      _loadingSource = true;
      _loadError = null;
    });
    try {
      final raw = await loader();
      if (raw == null) {
        return;
      }
      final imported = await _prepareLoadedImport(method: method, raw: raw);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyPreparedImport(imported);
      });
      _showImportSuccess(context, imported);
    } on FormatException catch (error) {
      _handleImportFailure(method, error.message);
    } catch (error) {
      _handleImportFailure(
        method,
        '书源 JSON 读取失败：${_privateBookSourceMessageOf(error)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingSource = false;
        });
      }
    }
  }

  void _handleImportFailure(BookSourceImportMethod method, String message) {
    setState(() {
      _loadError = message;
    });
    _showImportFailure(context, method: method, message: message);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final sourceReady = await _ensureSourceReadyForSave();
      if (!sourceReady) {
        return;
      }
      if (!_formKey.currentState!.validate()) {
        return;
      }
      final input = PrivateBookSourceInput(
        name: _nameController.text.trim(),
        supportedTypes: <String>[_type],
        sourceCode: _sourceController.text.trim(),
        description: _descriptionController.text.trim(),
        groupName: _groupController.text.trim(),
      );
      final saved = await ref
          .read(privateBookSourceActionControllerProvider)
          .saveSource(item: widget.item, input: input);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: _privateBookSourceMessageOf(error),
        tone: AppFeedbackTone.error,
        useHaptics: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _ensureSourceReadyForSave() async {
    if (_selectedImportMethod == BookSourceImportMethod.url) {
      return _loadUrlSourceForSave();
    }
    return _validateLoadedSource();
  }

  Future<bool> _loadUrlSourceForSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _setLoadError('请输入书源链接');
      return false;
    }
    if (_sourceController.text.trim().isNotEmpty && _loadedUrl == url) {
      return _validateLoadedSource();
    }
    setState(() {
      _loadingSource = true;
      _loadError = null;
    });
    try {
      final imported = await _prepareUrlImport(url);
      if (!mounted) {
        return false;
      }
      setState(() {
        _loadedUrl = url;
        _applyPreparedImport(imported);
      });
      _showImportSuccess(context, imported);
      return true;
    } on FormatException catch (error) {
      setState(() {
        _loadError = error.message;
      });
      _showImportFailure(
        context,
        method: BookSourceImportMethod.url,
        message: error.message,
      );
      return false;
    } catch (error) {
      final message = '书源 JSON 读取失败：${_privateBookSourceMessageOf(error)}';
      setState(() {
        _loadError = message;
      });
      _showImportFailure(
        context,
        method: BookSourceImportMethod.url,
        message: message,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _loadingSource = false;
        });
      }
    }
  }

  bool _validateLoadedSource() {
    final raw = _sourceController.text.trim();
    if (raw.isEmpty) {
      _setLoadError('请先导入书源 JSON');
      return false;
    }
    if (!PrivateBookSourceInput.isValidJson(raw)) {
      _setLoadError('JSON 格式不正确');
      return false;
    }
    return true;
  }

  void _loadInitialPreview() {
    final raw = _sourceController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    try {
      final payload = BookSourceImportPayload.fromJsonText(raw);
      _applyLoadedPayload(payload, label: '已保存 JSON', fillMetadata: false);
    } catch (_) {
      _previewController.text = buildBookSourcePreview(raw);
      _sourceLabel = '已保存 JSON';
      _sourceLineCount = countBookSourceLines(raw);
      _sourceSizeBytes = bookSourceUtf8SizeOf(raw);
      _loadError = '已保存 JSON 格式异常，请重新导入';
    }
  }

  void _applyPreparedImport(_PreparedBookSourceImport imported) {
    _applyLoadedPayload(imported.payload, label: imported.label);
  }

  void _applyLoadedPayload(
    BookSourceImportPayload payload, {
    required String label,
    bool fillMetadata = true,
  }) {
    _sourceController.text = payload.sourceJson;
    _previewController.text = payload.previewText;
    _sourceLabel = label;
    _sourceLineCount = payload.lineCount;
    _sourceSizeBytes = payload.sizeBytes;
    _previewExpanded = false;
    _loadError = null;
    if (fillMetadata) {
      _fillMetadataFromPayload(payload);
    }
  }

  void _fillMetadataFromPayload(BookSourceImportPayload payload) {
    if (_nameController.text.trim().isEmpty &&
        payload.suggestedName.isNotEmpty) {
      _nameController.text = payload.suggestedName;
    }
    if (_descriptionController.text.trim().isEmpty &&
        payload.suggestedDescription.isNotEmpty) {
      _descriptionController.text = payload.suggestedDescription;
    }
    if (_isEditing || _groupEdited || _groupController.text.trim().isNotEmpty) {
      return;
    }
    if (payload.suggestedGroupName.isEmpty) {
      return;
    }
    _groupController.text = payload.suggestedGroupName;
  }

  void _clearLoadedSource() {
    setState(() {
      _clearLoadedSourceValues();
    });
  }

  void _clearLoadedSourceValues() {
    _sourceController.clear();
    _previewController.clear();
    _sourceLabel = null;
    _sourceLineCount = 0;
    _sourceSizeBytes = 0;
    _previewExpanded = false;
    _loadError = null;
  }

  void _setLoadError(String message) {
    setState(() {
      _loadError = message;
    });
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone: AppFeedbackTone.error,
      useHaptics: false,
    );
  }
}

class _PreparedBookSourceImport {
  const _PreparedBookSourceImport({required this.label, required this.payload});

  final String label;
  final BookSourceImportPayload payload;
}

class _RawBookSourceImport {
  const _RawBookSourceImport({required this.text, required this.label});

  final String text;
  final String label;
}

InputDecoration _privateSourceInputDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? helperText,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    helperText: helperText,
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

class _PrivateSourceSectionHeader extends StatelessWidget {
  const _PrivateSourceSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PrivateSourceField extends StatelessWidget {
  const _PrivateSourceField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

String _importMethodLabel(BookSourceImportMethod method) {
  return switch (method) {
    BookSourceImportMethod.url => '链接',
    BookSourceImportMethod.file => '文件',
    BookSourceImportMethod.paste => '粘贴',
  };
}

class _UrlJsonSourceInput extends StatelessWidget {
  const _UrlJsonSourceInput({
    required this.controller,
    required this.enabled,
    required this.hasLoadedSource,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool hasLoadedSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PrivateSourceField(
          label: '链接',
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: _privateSourceInputDecoration(
              hintText: 'https://example.com/source.json',
              prefixIcon: const Icon(Icons.link_rounded),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasLoadedSource
              ? '当前链接已解析；修改链接后保存会重新解析。'
              : '填写链接后点击保存，系统会下载并解析 JSON。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImportErrorBanner extends StatelessWidget {
  const _ImportErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSourcePreviewCard extends StatelessWidget {
  const _BookSourcePreviewCard({
    required this.label,
    required this.previewController,
    required this.lineCount,
    required this.sizeBytes,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClear,
  });

  final String label;
  final TextEditingController previewController;
  final int lineCount;
  final int sizeBytes;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.code_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$lineCount 行 · ${formatBookSourceSize(sizeBytes)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: expanded ? '收起预览' : '查看预览',
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.visibility_outlined,
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: '清除',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if (expanded) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: previewController,
                readOnly: true,
                minLines: 6,
                maxLines: 12,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
                decoration: _privateSourceInputDecoration(
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrivateGroupAutocompleteField extends StatefulWidget {
  const _PrivateGroupAutocompleteField({
    required this.controller,
    required this.groupsAsync,
    required this.onChanged,
    this.decoration = const InputDecoration(),
  });

  final TextEditingController controller;
  final AsyncValue<List<PrivateBookSourceGroup>> groupsAsync;
  final VoidCallback onChanged;
  final InputDecoration decoration;

  @override
  State<_PrivateGroupAutocompleteField> createState() =>
      _PrivateGroupAutocompleteFieldState();
}

class _PrivateGroupAutocompleteFieldState
    extends State<_PrivateGroupAutocompleteField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        widget.groupsAsync.valueOrNull ?? const <PrivateBookSourceGroup>[];
    final groupNames = _uniqueGroupNames(groups);
    final loading = widget.groupsAsync.isLoading && groups.isEmpty;
    final hasError = widget.groupsAsync.hasError && groups.isEmpty;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final rawKeyword = value.text.trim();
        final keyword = rawKeyword.toLowerCase();
        if (keyword.isEmpty) {
          return groupNames.take(12);
        }
        final matches =
            groupNames
                .where((name) => name.toLowerCase().contains(keyword))
                .take(12)
                .toList();
        final exists = groupNames.any((name) => name.toLowerCase() == keyword);
        if (!exists) {
          matches.add(rawKeyword);
        }
        return matches;
      },
      onSelected: (_) => widget.onChanged(),
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: widget.decoration.copyWith(
            hintText: widget.decoration.hintText ?? '选择已有分组，或输入新分组名',
            helperText:
                widget.decoration.helperText ??
                (loading
                    ? '正在读取分组'
                    : hasError
                    ? '分组读取失败，可直接输入新分组名'
                    : null),
            suffixIcon:
                widget.decoration.suffixIcon ??
                IconButton(
                  tooltip: '查看已有分组',
                  onPressed:
                      groupNames.isEmpty
                          ? null
                          : () {
                            focusNode.requestFocus();
                            textController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: textController.text.length,
                            );
                          },
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                ),
          ),
          onChanged: (_) => widget.onChanged(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final maxWidth = MediaQuery.sizeOf(context).width - 32;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            elevation: 2,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: maxWidth.clamp(260.0, 420.0),
              constraints: const BoxConstraints(maxHeight: 248),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder:
                    (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.28,
                        ),
                      ),
                    ),
                itemBuilder: (context, index) {
                  final name = items[index];
                  final exists = groupNames.any(
                    (groupName) =>
                        groupName.toLowerCase() == name.toLowerCase(),
                  );
                  return _PrivateGroupOptionRow(
                    key: ValueKey<String>('private_group_option_$name'),
                    name: name,
                    exists: exists,
                    onTap: () => onSelected(name),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivateGroupOptionRow extends StatelessWidget {
  const _PrivateGroupOptionRow({
    super.key,
    required this.name,
    required this.exists,
    required this.onTap,
  });

  final String name;
  final bool exists;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color:
                    exists
                        ? colorScheme.primaryContainer.withValues(alpha: 0.48)
                        : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.82,
                        ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                exists
                    ? Icons.folder_outlined
                    : Icons.create_new_folder_outlined,
                size: 19,
                color:
                    exists ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exists ? '已有私人分组' : '保存时创建',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _uniqueGroupNames(List<PrivateBookSourceGroup> groups) {
  final seen = <String>{};
  final names = <String>[];
  for (final group in groups) {
    final name = group.displayName.trim();
    if (name.isEmpty || !seen.add(name)) {
      continue;
    }
    names.add(name);
  }
  names.sort();
  return names;
}

String _privateBookSourceMessageOf(Object error) {
  if (error is ApiException) {
    return error.briefMessage;
  }
  return error.toString();
}
