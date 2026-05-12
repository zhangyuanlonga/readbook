import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_runtime_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/cache/cache_manager.dart';
import 'package:shuxiang_reading_next/runtime/crypto/source_crypto.dart';
import 'package:shuxiang_reading_next/runtime/html/html_runtime.dart';
import 'package:shuxiang_reading_next/runtime/http/challenge_detector.dart';
import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('text-like action does not persist form before failed action', () async {
    final sourceLogin = SourceLoginContext(sourceId: 'source_runtime_test');
    final runtimeFacade = _FakeSourceRuntimeFacade(
      sourceLogin: sourceLogin,
      definition: _testRuntimeDefinition(
        loginAction:
            (_, __, {book, chapter, actionCode, isLongClick = false}) async =>
                false,
      ),
    );
    final service = SourceLoginRuntimeService(
      sourceRuntimeFacade: runtimeFacade,
    );

    await service.submit(
      'source_runtime_test',
      formData: const <String, String>{'账号': 'alice'},
      actionCode: 'validateAccount()',
      persistFormBeforeAction: false,
    );

    expect(await sourceLogin.getInfoMap(), isEmpty);
  });

  test('text-like action persists form after accepted action', () async {
    final sourceLogin = SourceLoginContext(sourceId: 'source_runtime_test');
    final runtimeFacade = _FakeSourceRuntimeFacade(
      sourceLogin: sourceLogin,
      definition: _testRuntimeDefinition(
        loginAction:
            (_, __, {book, chapter, actionCode, isLongClick = false}) async =>
                true,
      ),
    );
    final service = SourceLoginRuntimeService(
      sourceRuntimeFacade: runtimeFacade,
    );

    await service.submit(
      'source_runtime_test',
      formData: const <String, String>{'账号': 'alice'},
      actionCode: 'validateAccount()',
      persistFormBeforeAction: false,
    );

    expect((await sourceLogin.getInfoMap())['账号'], 'alice');
  });
}

class _FakeSourceRuntimeFacade extends SourceRuntimeFacade {
  _FakeSourceRuntimeFacade({
    required this.sourceLogin,
    required RuntimeSourceDefinition definition,
  }) : _registeredSource = RegisteredSource(
         runtime: const SourceRuntimeInfo(
           id: 'source_runtime_test',
           name: '测试登录源',
           group: '测试',
           revision: 'test',
         ),
         definition: definition,
       ),
       super(scriptSourceRepository: _FakeSourceRepo());

  final SourceLoginContext sourceLogin;
  final RegisteredSource _registeredSource;

  @override
  Future<RegisteredSource?> ensureRegisteredScriptSourceById(
    String sourceId,
  ) async {
    return _registeredSource;
  }

  @override
  SourceRuntimeContext createRuntimeContext(
    RegisteredSource source, {
    SourceUiContext ui = const SourceUiContext(),
  }) {
    final session = SourceSession(sourceId: source.runtime.id);
    return SourceRuntimeContext(
      source: source.runtime,
      http: SourceHttpContext(
        requestEngine: const _FakeRequestEngine(),
        session: session,
        manifest: source.definition.manifest,
        browserRuntime: const UnsupportedBrowserRuntime(),
        sourceLogin: sourceLogin,
      ),
      sourceLogin: sourceLogin,
      bookState: SourceBookStateContext(),
      browser: SourceBrowserContext(
        browserRuntime: const UnsupportedBrowserRuntime(),
        session: session,
      ),
      cookie: SourceCookieContext(session: session),
      cache: SourceCacheContext(
        cacheStore: CacheStoreContext(cacheManager: InMemoryCacheManager()),
        sourceId: source.runtime.id,
      ),
      html: const DefaultHtmlRuntime(),
      session: session,
      utils: SourceUtilsContext(),
      crypto: SourceCryptoContext(),
      ui: ui,
      log: (_) {},
    );
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

RuntimeSourceDefinition _testRuntimeDefinition({
  required SourceLoginActionHandler loginAction,
}) {
  return RuntimeSourceDefinition(
    manifest: const SourceManifest(
      name: '测试登录源',
      group: '测试',
      author: 'tester',
      description: '',
    ),
    search: (_, __) async => const <runtime_models.Book>[],
    detail: (_, book) async => book,
    chapters: (_, __) async => const <runtime_models.Chapter>[],
    content:
        (_, __, ___) async =>
            const runtime_models.Content(title: '', content: ''),
    supportsLogin: true,
    loginUi:
        (_, __, {book, chapter}) async => const <Object?>[
          <String, Object?>{'name': '账号', 'type': 'text'},
        ],
    loginAction: loginAction,
  );
}

class _FakeRequestEngine implements RequestEngine {
  const _FakeRequestEngine();

  @override
  Future<RuntimeHttpResponse> request(
    RuntimeHttpRequest request, {
    SourceSession? session,
  }) async {
    throw UnimplementedError();
  }

  @override
  bool isHtml(RuntimeHttpResponse response) => false;

  @override
  bool isJson(RuntimeHttpResponse response) => false;

  @override
  bool isRedirect(RuntimeHttpResponse response) => false;

  @override
  bool isChallenge(RuntimeHttpResponse response) => false;

  @override
  ChallengeDetectionResult detectChallenge(RuntimeHttpResponse response) {
    return const ChallengeDetectionResult(isChallenge: false);
  }
}
