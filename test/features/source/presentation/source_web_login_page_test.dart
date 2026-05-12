import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_runtime_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/features/source/presentation/source_web_login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets('loads web login request and completes with latest url', (
    tester,
  ) async {
    final service = _FakeWebLoginRuntimeService();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SourceWebLoginPage(
            sourceId: 'source_web',
            sourceLoginRuntimeService: service,
            webLoginViewBuilder: (context, request, onUrlChanged) {
              return Column(
                children: [
                  Text('网页登录:${request.sourceName}'),
                  TextButton(
                    onPressed: () => onUrlChanged('https://example.com/done'),
                    child: const Text('更新地址'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网页登录:网页登录源'), findsOneWidget);

    await tester.tap(find.text('更新地址'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('完成登录'));
    await tester.pumpAndSettle();

    expect(service.completedUri?.toString(), 'https://example.com/done');
  });
}

class _FakeWebLoginRuntimeService extends SourceLoginRuntimeService {
  _FakeWebLoginRuntimeService()
    : super(sourceRuntimeFacade: _FakeSourceRuntimeFacade());

  Uri? completedUri;

  @override
  Future<SourceWebLoginRequest?> prepareWebLogin(String sourceId) async {
    return SourceWebLoginRequest(
      sourceId: 'source_web',
      sourceName: '网页登录源',
      uri: Uri.parse('https://example.com/login'),
      headers: <String, String>{'User-Agent': 'test-agent'},
    );
  }

  @override
  Future<void> completeWebLogin(
    String sourceId, {
    required Uri currentUri,
  }) async {
    completedUri = currentUri;
  }
}

class _FakeSourceRuntimeFacade extends SourceRuntimeFacade {
  _FakeSourceRuntimeFacade() : super(scriptSourceRepository: _FakeSourceRepo());
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
