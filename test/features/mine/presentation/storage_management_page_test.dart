import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shuxiang_reading_next/app/widgets/adaptive_bottom_sheet.dart';
import 'package:shuxiang_reading_next/app/widgets/foundation/foundation.dart';
import 'package:shuxiang_reading_next/core/cache/app_cache_governance_service.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/storage_management_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/storage_management_page.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('StorageManagementPage moves from skeleton to content', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service = _FakeStorageManagementGateway();
    final pendingSnapshot = Completer<StorageManagementSnapshot>();
    service.nextSnapshot = pendingSnapshot.future;

    await tester.pumpWidget(_buildPage(service: service));

    expect(find.byType(AppSkeletonList), findsOneWidget);

    pendingSnapshot.complete(_snapshot());
    await tester.pumpAndSettle();

    expect(find.text('数据库'), findsOneWidget);
    expect(find.text('缓存占用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('清理所有缓存'), 320);
    expect(find.text('清理所有缓存'), findsOneWidget);
  });

  testWidgets('StorageManagementPage confirms and reports cache clearing', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service = _FakeStorageManagementGateway();

    await tester.pumpWidget(_buildPage(service: service));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('清理所有缓存'), 320);
    await tester.tap(find.text('清理所有缓存'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveActionSurface), findsOneWidget);
    expect(find.text('清理所有可重建缓存'), findsOneWidget);

    await tester.tap(find.text('确认清理'));
    await tester.pumpAndSettle();

    expect(service.clearRebuildableCachesCalls, 1);
    expect(find.text('缓存已清理。'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('StorageManagementPage reports cache scope failures', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service =
        _FakeStorageManagementGateway()
          ..nextDeleteResult = AppCacheDeleteResult.backendError(
            scope: AppCacheScope.coverImage,
            backend: 'test',
          );

    await tester.pumpWidget(_buildPage(service: service));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('封面图片缓存'), 320);
    await tester.tap(find.text('清理'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认清理'));
    await tester.pumpAndSettle();

    expect(service.clearScopeCalls, 1);
    expect(find.text('封面图片缓存清理失败，请稍后重试。'), findsOneWidget);
    expect(find.text('清理失败，请稍后重试。'), findsOneWidget);
  });
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildPage({required StorageManagementGateway service}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => StorageManagementPage(service: service),
      ),
      GoRoute(
        path: '/system-settings',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [activeAdvancedThemeProvider.overrideWith((ref) async => null)],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 800), devicePixelRatio: 1),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

StorageManagementSnapshot _snapshot() {
  return const StorageManagementSnapshot(
    database: StorageFootprint(label: '数据库', bytes: 1024 * 1024, fileCount: 1),
    localBooks: StorageFootprint(label: '本地图书', bytes: 2048, fileCount: 2),
    userAssets: StorageFootprint(label: '用户资源', bytes: 4096, fileCount: 3),
    totalManagedAssetBytes: 6144,
    cacheSnapshot: AppCacheGovernanceSnapshot(
      entries: [
        AppCacheGovernanceEntry(
          scope: AppCacheScope.coverImage,
          label: '封面图片缓存',
          currentEntries: 12,
          currentBytes: 8192,
          deletable: true,
          rebuildable: true,
          backend: 'test',
        ),
      ],
    ),
  );
}

class _FakeStorageManagementGateway implements StorageManagementGateway {
  Future<StorageManagementSnapshot>? nextSnapshot;
  int clearRebuildableCachesCalls = 0;
  int clearScopeCalls = 0;
  int cleanOrphansCalls = 0;
  AppCacheDeleteResult? nextDeleteResult;

  @override
  Future<StorageManagementSnapshot> loadSnapshot() {
    final snapshot = nextSnapshot;
    nextSnapshot = null;
    return snapshot ?? Future<StorageManagementSnapshot>.value(_snapshot());
  }

  @override
  Future<void> clearRebuildableCaches() async {
    clearRebuildableCachesCalls += 1;
  }

  @override
  Future<AppCacheDeleteResult> clearCacheScope(AppCacheScope scope) async {
    clearScopeCalls += 1;
    final result = nextDeleteResult;
    nextDeleteResult = null;
    return result ??
        AppCacheDeleteResult.deleted(scope: scope, backend: 'test');
  }

  @override
  Future<AppDatabaseMaintenanceReport> clearOrphanedDatabaseData() async {
    cleanOrphansCalls += 1;
    return const AppDatabaseMaintenanceReport(
      orphanedLocalReadingProgresses: 1,
      orphanedLocalReadingRecords: 0,
      orphanedLocalReadingRecordSessions: 0,
      orphanedLocalReadingBookStatuses: 0,
      orphanedLocalTocSnapshots: 0,
      orphanedLocalMetadataOverrides: 0,
      staleSearchSourceHits: 0,
    );
  }
}
