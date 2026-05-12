import '../../../runtime/sources/source_registry.dart';
import 'source_login_runtime_service.dart';
import 'source_runtime_facade.dart';

enum SourceLoginEntryMode { form, web, unsupported }

class SourceLoginEntryResolution {
  const SourceLoginEntryResolution({
    required this.mode,
    required this.sourceId,
    required this.sourceName,
    this.message,
  });

  final SourceLoginEntryMode mode;
  final String sourceId;
  final String sourceName;
  final String? message;

  bool get isSupported => mode != SourceLoginEntryMode.unsupported;
}

class SourceLoginEntryResolver {
  const SourceLoginEntryResolver({
    required SourceRuntimeFacade sourceRuntimeFacade,
    required SourceLoginRuntimeService sourceLoginRuntimeService,
  }) : _sourceRuntimeFacade = sourceRuntimeFacade,
       _sourceLoginRuntimeService = sourceLoginRuntimeService;

  final SourceRuntimeFacade _sourceRuntimeFacade;
  final SourceLoginRuntimeService _sourceLoginRuntimeService;

  Future<SourceLoginEntryResolution> resolve(String sourceId) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return const SourceLoginEntryResolution(
        mode: SourceLoginEntryMode.unsupported,
        sourceId: '',
        sourceName: '书源登录',
        message: '书源标识为空，无法打开登录入口。',
      );
    }

    final registered = await _sourceRuntimeFacade
        .ensureRegisteredScriptSourceById(normalizedSourceId);
    if (registered == null || !registered.definition.supportsLogin) {
      return SourceLoginEntryResolution(
        mode: SourceLoginEntryMode.unsupported,
        sourceId: normalizedSourceId,
        sourceName: registered?.runtime.name ?? '书源登录',
        message: '当前书源未声明登录能力。',
      );
    }

    final presentation = await _sourceLoginRuntimeService.loadPresentation(
      normalizedSourceId,
    );
    if (presentation != null) {
      return SourceLoginEntryResolution(
        mode: SourceLoginEntryMode.form,
        sourceId: normalizedSourceId,
        sourceName: presentation.sourceName,
      );
    }

    if (_supportsWebLogin(registered)) {
      return SourceLoginEntryResolution(
        mode: SourceLoginEntryMode.web,
        sourceId: normalizedSourceId,
        sourceName: registered.runtime.name,
      );
    }

    return SourceLoginEntryResolution(
      mode: SourceLoginEntryMode.unsupported,
      sourceId: normalizedSourceId,
      sourceName: registered.runtime.name,
      message: '当前书源已声明登录能力，但未提供可用的表单面板或网页登录入口。',
    );
  }

  bool _supportsWebLogin(RegisteredSource source) {
    final rawUrl = source.definition.webLoginUrl?.trim() ?? '';
    return rawUrl.isNotEmpty;
  }
}
