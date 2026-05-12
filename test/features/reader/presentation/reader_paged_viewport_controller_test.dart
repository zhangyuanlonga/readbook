import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_paged_viewport_controller.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_paged_viewport_support.dart';

void main() {
  group('ReaderPagedViewportController', () {
    const controller = ReaderPagedViewportController();

    test('updates curl preview state from swipe delta', () {
      final state = controller.updateCurlPreviewProgress(
        viewportSize: const Size(400, 800),
        isCurlAutoTurning: false,
        swipeDragStartDx: 300,
        swipeDragCurrentDx: 120,
        pageCount: 5,
        currentPageIndex: 2,
        currentState: const ReaderPagedViewportCurlState(),
      );

      expect(state.isPreview, isTrue);
      expect(state.direction, 1);
      expect(state.fromIndex, 2);
      expect(state.toIndex, 3);
    });

    test('starts auto turn with resolved next page', () {
      final state = controller.startAutoTurn(
        direction: -1,
        currentPageIndex: 3,
        pageCount: 6,
      );

      expect(state.isAnimating, isTrue);
      expect(state.fromIndex, 3);
      expect(state.toIndex, 2);
    });

    test('delegates pagination ensure plan to engine', () {
      const spec = ReaderPaginationSpec(
        contentWidth: 320,
        contentHeight: 640,
        contentRectLeft: 16,
        contentRectTop: 70,
        pagePaddingTop: 18,
        pagePaddingRight: 18,
        pagePaddingBottom: 18,
        pagePaddingLeft: 18,
        pinnedHeaderHeight: 52,
        fontSize: 18,
        lineHeight: 1.7,
        paragraphSpacing: 14,
        paragraphIndent: 0,
        letterSpacing: 0,
        textFullJustifyEnabled: false,
        bodyTextItalicEnabled: false,
        fontWeightLevel: ReaderFontWeightLevel.regular,
        fontWeightValue: null,
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.defaultSans,
        fontFamilyKey: null,
      );
      const request = ReaderPaginationEnsureRequest(
        spec: spec,
        signature: 'sig',
        currentState: ReaderPaginationSessionState(),
        hasExistingPages: false,
        currentProgressRatio: 0.2,
      );
      final plan = controller.buildEnsurePlan(
        engine: const ReaderPaginationEngine(),
        request: request,
      );

      expect(plan.shouldPaginate, isTrue);
      expect(plan.signature, 'sig');
    });
  });
}
