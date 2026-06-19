import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/theme_semantic_spec.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_editor_models.dart';

void main() {
  group('AdvancedThemeColorCodec', () {
    test('parses and formats rgb and argb hex values', () {
      expect(AdvancedThemeColorCodec.parseHexColor('#123456'), 0xFF123456);
      expect(AdvancedThemeColorCodec.parseHexColor('80123456'), 0x80123456);
      expect(AdvancedThemeColorCodec.parseHexColor('#XYZ'), isNull);
      expect(AdvancedThemeColorCodec.formatHex(0xFF123456), '#123456');
      expect(AdvancedThemeColorCodec.formatHex(0x80123456), '#80123456');
      expect(AdvancedThemeColorCodec.formatHex(null), '');
    });

    test('resolves missing colors to fallback', () {
      expect(
        AdvancedThemeColorCodec.resolvedColor(null, Colors.red),
        Colors.red,
      );
      expect(
        AdvancedThemeColorCodec.resolvedColor(0xFF123456, Colors.red),
        const Color(0xFF123456),
      );
    });
  });

  group('AdvancedThemeColorSlot', () {
    test('maps semantic fields into editor slots', () {
      expect(
        AdvancedThemeColorSlot.fromSemanticField(
          ThemeSemanticFieldId.cardBorder,
        ),
        AdvancedThemeColorSlot.cardBorder,
      );
      expect(
        AdvancedThemeColorSlot.fromSemanticField(
          ThemeSemanticFieldId.wallpaperOverlay,
        ),
        AdvancedThemeColorSlot.wallpaperOverlay,
      );
    });
  });

  test('AdvancedThemeColorFieldSpec builds tooltip with scopes', () {
    const spec = AdvancedThemeColorFieldSpec(
      slot: AdvancedThemeColorSlot.primary,
      label: '强调',
      description: '主要操作',
      scopeLabels: <String>['按钮', ' 链接 ', ''],
    );

    expect(spec.tooltipMessage, '主要操作\n影响范围：按钮 / 链接');
  });
}
