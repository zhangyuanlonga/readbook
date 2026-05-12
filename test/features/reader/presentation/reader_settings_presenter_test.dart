import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_settings_presenter.dart';

void main() {
  group('ReaderSettingsPresenter', () {
    const presenter = ReaderSettingsPresenter();

    test('builds labels for presets and typography values', () {
      expect(
        presenter.bodyMarginDisplayValue(
          const ReaderSettings(
            bodyMarginTop: 6,
            bodyMarginBottom: 8,
            bodyMarginLeft: 16,
            bodyMarginRight: 20,
          ),
        ),
        '上6 下8 左16 右20',
      );
      expect(presenter.pageAnimationLabel(ReaderPageAnimationStyle.curl), '仿真');
      expect(
        presenter.fontSizeValueLabel(const ReaderSettings(fontSize: 20)),
        '20px',
      );
    });

    test('resolves current font label for system preset', () {
      expect(
        presenter.currentFontLabel(
          settings: const ReaderSettings(
            fontSource: ReaderFontSource.system,
            systemFontPreset: ReaderSystemFontPreset.serif,
          ),
          customFonts: const [],
        ),
        '衬线',
      );
    });
  });
}
