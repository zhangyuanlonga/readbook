import 'package:shuxiang_reading_next/features/source/presentation/script_source_editor_page.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_script_compiler.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_script_template.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  group('ScriptSourceEditorPage helpers', () {
    test('official template passes draft validation', () {
      expect(validateScriptSourceDraft(sourceScriptOfficialTemplateV1), isNull);
    });

    test('json draft shows redirect hint', () {
      final message = validateScriptSourceDraft('{"name":"旧规则"}');
      expect(message, isNotNull);
      expect(message, contains('JSON 配置'));
      expect(message, contains('当前版本只支持脚本源'));
    });

    test('draft without meta.name shows direct fix hint', () {
      const code = '''
export default {
  meta: {
    group: '调试',
  },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title, content: '' }; },
};
''';
      final message = validateScriptSourceDraft(code);
      expect(message, isNotNull);
      expect(message, contains('meta.name'));
    });

    test('compile exception for missing methods becomes friendly text', () {
      const error = SourceScriptCompileException(
        '书源缺少必须方法，至少需要 search/detail/chapters/content。',
      );
      expect(toFriendlyScriptEditorError(error), contains('至少需要实现'));
    });

    testWidgets('页面在手机和平板尺寸下可正常渲染', (tester) async {
      await runAdaptivePageSmokeMatrix(
        tester,
        pageBuilder: () => const ScriptSourceEditorPage(),
        pageName: 'ScriptSourceEditorPage',
      );
    });
  });
}
