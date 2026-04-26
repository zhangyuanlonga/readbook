import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_body_region.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_viewport_builder.dart';

void main() {
  group('ReaderViewportBuilder', () {
    const builder = ReaderViewportBuilder();
    const palette = ReaderBodyRegionPalette(
      textColor: Colors.black,
      metaColor: Colors.black54,
      overlayColor: Colors.white,
      dividerColor: Colors.black12,
    );

    testWidgets('renders empty state card when no content exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.buildBody(
              state: const ReaderViewportBodyState(
                showBlockingLoading: false,
                showHiddenLoading: false,
                hasRenderableContent: false,
              ),
              palette: palette,
              tapAwareBuilder: ({required child}) => child,
              contentBuilder: () => const SizedBox.shrink(),
              onRetry: () {},
              onCopyDiagnostics: () {},
              onSwitchSource: () {},
              isLocalContent: false,
            ),
          ),
        ),
      );

      expect(find.text('暂无正文'), findsOneWidget);
    });

    testWidgets('renders error actions when error state is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.buildBody(
              state: const ReaderViewportBodyState(
                showBlockingLoading: false,
                showHiddenLoading: false,
                hasRenderableContent: true,
                errorText: '加载失败',
                canSwitchSource: true,
              ),
              palette: palette,
              tapAwareBuilder: ({required child}) => child,
              contentBuilder: () => const SizedBox.shrink(),
              onRetry: () {},
              onCopyDiagnostics: () {},
              onSwitchSource: () {},
              isLocalContent: true,
            ),
          ),
        ),
      );

      expect(find.text('重试'), findsOneWidget);
      expect(find.text('复制诊断信息'), findsOneWidget);
      expect(find.text('切换书源'), findsOneWidget);
    });
  });
}
