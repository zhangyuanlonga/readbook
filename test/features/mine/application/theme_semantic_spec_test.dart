import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/theme/app_advanced_theme_tokens.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/theme_semantic_spec.dart';

void main() {
  test('color card semantic fields keep fixed user-facing order', () {
    expect(
      colorCardThemeSemanticFields.map((field) => field.id),
      <ThemeSemanticFieldId>[
        ThemeSemanticFieldId.accent,
        ThemeSemanticFieldId.pageBackground,
        ThemeSemanticFieldId.modalBackground,
        ThemeSemanticFieldId.secondaryBackground,
        ThemeSemanticFieldId.primaryText,
        ThemeSemanticFieldId.secondaryText,
        ThemeSemanticFieldId.border,
      ],
    );
  });

  test(
    'modal background scope labels keep dialog and bottom sheet mapping',
    () {
      final spec = themeSemanticFieldSpecFor(
        ThemeSemanticFieldId.modalBackground,
      );
      expect(spec.scopeLabels, contains('Dialog'));
      expect(spec.scopeLabels, contains('BottomSheet'));
      expect(spec.scopeLabels, contains('菜单'));
    },
  );

  test('color card semantic previews map to palette and backdrop colors', () {
    final previews = buildColorCardThemeSemanticPreviews(
      palette: const ResolvedAdvancedThemePalette(
        backgroundColor: Color(0xFF111111),
        surfaceColor: Color(0xFF222222),
        searchFieldBackgroundColor: Color(0xFF333333),
        elevatedSurfaceColor: Color(0xFF444444),
        cardColor: Color(0xFF555555),
        cardTextColor: Color(0xFF666666),
        cardBorderColor: Color(0xFF777777),
        outlineColor: Color(0xFF888888),
        iconBackgroundColor: Color(0xFF999999),
        textPrimaryColor: Color(0xFFAAAAAA),
        textSecondaryColor: Color(0xFFBBBBBB),
        primaryColor: Color(0xFFCCCCCC),
        primaryContainerColor: Color(0xFFDDDDDD),
        secondaryColor: Color(0xFFEEEEEE),
        buttonTextColor: Color(0xFFFFFFFF),
        shadowColor: Color(0x66000000),
        noticeAccentColor: Color(0xFF12AB34),
        noticeSurfaceColor: Color(0xFF1234AB),
      ),
      backdrop: const ResolvedAdvancedThemeBackdrop(
        backgroundColor: Color(0xFF010203),
        surfaceColor: Color(0xFF020304),
        wallpaperPath: null,
        wallpaperOpacity: 1,
        wallpaperBlurSigma: 0,
        wallpaperFit: AppAdvancedThemeWallpaperFit.cover,
        wallpaperOverlayColor: Color(0xFF040506),
        wallpaperOverlayOpacity: 0.32,
      ),
    );

    expect(previews, hasLength(7));
    expect(previews[0].id, ThemeSemanticFieldId.accent);
    expect(previews[0].color, const Color(0xFFCCCCCC));
    expect(previews[1].id, ThemeSemanticFieldId.pageBackground);
    expect(previews[1].color, const Color(0xFF010203));
    expect(previews[2].id, ThemeSemanticFieldId.modalBackground);
    expect(previews[2].color, const Color(0xFF222222));
    expect(previews[3].id, ThemeSemanticFieldId.secondaryBackground);
    expect(previews[3].color, const Color(0xFF444444));
    expect(previews[6].id, ThemeSemanticFieldId.border);
    expect(previews[6].color, const Color(0xFF888888));
  });
}
