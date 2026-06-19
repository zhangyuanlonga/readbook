import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/source_access/source_access_provider.dart';
import 'package:shuxiang_reading_next/core/source_access/source_access_scope.dart';
import 'package:shuxiang_reading_next/core/source_access/source_access_service.dart';

void main() {
  test('does not fetch source access scope without access token', () async {
    final service = _FakeSourceAccessService();
    final container = ProviderContainer(
      overrides: <Override>[
        sourceAccessServiceProvider.overrideWithValue(service),
        sourceAccessTokenReaderProvider.overrideWithValue(() async => null),
      ],
    );
    addTearDown(container.dispose);

    final scope = await container.read(sourceAccessScopeProvider.future);

    expect(scope, isNull);
    expect(service.fetchCalls, 0);
  });

  test('fetches source access scope when access token exists', () async {
    final service = _FakeSourceAccessService();
    final container = ProviderContainer(
      overrides: <Override>[
        sourceAccessServiceProvider.overrideWithValue(service),
        sourceAccessTokenReaderProvider.overrideWithValue(
          () async => 'access-token',
        ),
      ],
    );
    addTearDown(container.dispose);

    final scope = await container.read(sourceAccessScopeProvider.future);

    expect(scope?.userId, 'user-a');
    expect(service.fetchCalls, 1);
  });
}

class _FakeSourceAccessService extends SourceAccessService {
  int fetchCalls = 0;

  @override
  Future<SourceAccessScope> fetchMyScope() async {
    fetchCalls += 1;
    return const SourceAccessScope(
      userId: 'user-a',
      role: 'member',
      membershipActive: true,
      vipLevel: 'vip',
      features: <String>['server_source_gateway'],
      groups: <SourceAccessGroupSummary>[],
      groupCodes: <String>[],
      sourceIds: <String>['source-a'],
      groupSourceIds: <String, List<String>>{},
      sourceScopeSource: 'test',
    );
  }
}
