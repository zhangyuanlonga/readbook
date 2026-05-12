import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_entry_resolver.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_runtime_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('SourceLoginEntryResolver', () {
    test('prefers form mode when loginUi presentation is available', () async {
      final runtimeFacade = _FakeSourceRuntimeFacade(
        registeredSource: _registeredSource(
          supportsLogin: true,
          webLoginUrl: 'https://example.com/login',
        ),
      );
      final runtimeService = _FakeSourceLoginRuntimeService(
        runtimeFacade,
        presentation: const SourceLoginPresentation(
          sourceId: 'source_form',
          sourceName: '表单登录源',
          fields: <SourceLoginField>[],
          formData: <String, String>{},
        ),
      );
      final resolver = SourceLoginEntryResolver(
        sourceRuntimeFacade: runtimeFacade,
        sourceLoginRuntimeService: runtimeService,
      );

      final resolution = await resolver.resolve('source_form');

      expect(resolution.mode, SourceLoginEntryMode.form);
      expect(resolution.sourceName, '表单登录源');
    });

    test(
      'falls back to web mode when only web login url is available',
      () async {
        final runtimeFacade = _FakeSourceRuntimeFacade(
          registeredSource: _registeredSource(
            supportsLogin: true,
            webLoginUrl: '/login',
            name: '网页登录源',
          ),
        );
        final runtimeService = _FakeSourceLoginRuntimeService(runtimeFacade);
        final resolver = SourceLoginEntryResolver(
          sourceRuntimeFacade: runtimeFacade,
          sourceLoginRuntimeService: runtimeService,
        );

        final resolution = await resolver.resolve('source_web');

        expect(resolution.mode, SourceLoginEntryMode.web);
        expect(resolution.sourceName, '网页登录源');
      },
    );

    test('returns unsupported when no usable login entry exists', () async {
      final runtimeFacade = _FakeSourceRuntimeFacade(
        registeredSource: _registeredSource(
          supportsLogin: true,
          webLoginUrl: null,
          name: '脚本登录源',
        ),
      );
      final runtimeService = _FakeSourceLoginRuntimeService(runtimeFacade);
      final resolver = SourceLoginEntryResolver(
        sourceRuntimeFacade: runtimeFacade,
        sourceLoginRuntimeService: runtimeService,
      );

      final resolution = await resolver.resolve('source_script');

      expect(resolution.mode, SourceLoginEntryMode.unsupported);
      expect(resolution.message, isNotEmpty);
    });
  });
}

class _FakeSourceLoginRuntimeService extends SourceLoginRuntimeService {
  _FakeSourceLoginRuntimeService(
    SourceRuntimeFacade runtimeFacade, {
    this.presentation,
  }) : super(sourceRuntimeFacade: runtimeFacade);

  final SourceLoginPresentation? presentation;

  @override
  Future<SourceLoginPresentation?> loadPresentation(
    String sourceId, {
    ui = const SourceUiContext(),
    book,
    chapter,
  }) async {
    return presentation;
  }
}

class _FakeSourceRuntimeFacade extends SourceRuntimeFacade {
  _FakeSourceRuntimeFacade({this.registeredSource})
    : super(scriptSourceRepository: _FakeSourceRepo());

  final RegisteredSource? registeredSource;

  @override
  Future<RegisteredSource?> ensureRegisteredScriptSourceById(
    String sourceId,
  ) async {
    return registeredSource;
  }
}

class _FakeSourceRepo implements ScriptSourceRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<ScriptSource>> getAll() async => const <ScriptSource>[];

  @override
  Future<ScriptSource?> getById(String id) async => null;

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {}

  @override
  Future<void> upsert(ScriptSource source) async {}

  @override
  Stream<List<ScriptSource>> watchAll() =>
      const Stream<List<ScriptSource>>.empty();
}

RegisteredSource _registeredSource({
  required bool supportsLogin,
  required String? webLoginUrl,
  String name = '测试书源',
}) {
  return RegisteredSource(
    runtime: SourceRuntimeInfo(
      id: 'source_web',
      name: name,
      group: '测试',
      revision: 'test',
    ),
    definition: RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: '测试',
        author: 'tester',
        description: '',
        homepage: 'https://example.com',
      ),
      search: (_, __) async => const <runtime_models.Book>[],
      detail: (_, book) async => book,
      chapters: (_, __) async => const <runtime_models.Chapter>[],
      content: (_, __, ___) async => throw UnimplementedError(),
      supportsLogin: supportsLogin,
      webLoginUrl: webLoginUrl,
    ),
  );
}
