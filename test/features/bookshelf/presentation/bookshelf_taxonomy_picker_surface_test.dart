import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_taxonomy_picker_surface.dart';

void main() {
  testWidgets('taxonomy picker renders create panel and actions', (
    tester,
  ) async {
    var created = false;
    var saved = false;
    var cancelled = false;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfTaxonomyPickerSurface(
            icon: Icons.label_rounded,
            title: '管理标签',
            subtitle: '为书籍选择标签',
            createLabel: '新建',
            onCreate: () => created = true,
            onSave: () => saved = true,
            onCancel: () => cancelled = true,
            createPanel: BookshelfInlineTaxonomyCreatePanel(
              kind: BookshelfTaxonomyKind.tag,
              nameController: controller,
              color: const Color(0xFF2563EB),
              errorText: null,
              onColorChanged: (_) {},
              onNameChanged: (_) {},
              onSubmit: () {},
              onCancel: () {},
              formatColorLabel: (value) => '#${value.toRadixString(16)}',
            ),
            child: const BookshelfTagPicker(
              items: <BookshelfTaxonomyItem>[],
              selectedTags: <String>[],
              normalizeTags: _identityTags,
              onChanged: _ignoreTags,
            ),
          ),
        ),
      ),
    );

    expect(find.text('管理标签'), findsOneWidget);
    expect(find.text('标签名称'), findsOneWidget);
    expect(find.text('未打标签'), findsOneWidget);

    await tester.tap(find.text('新建'));
    await tester.tap(find.text('保存'));
    await tester.tap(find.text('取消').last);

    expect(created, isTrue);
    expect(saved, isTrue);
    expect(cancelled, isTrue);
  });

  testWidgets('taxonomy option chip toggles tags', (tester) async {
    List<String>? changedTags;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfTagPicker(
            items: const <BookshelfTaxonomyItem>[
              BookshelfTaxonomyItem(name: '科幻', colorValue: 0xFF2563EB),
            ],
            selectedTags: const <String>[],
            normalizeTags: _identityTags,
            onChanged: (tags) => changedTags = tags,
          ),
        ),
      ),
    );

    await tester.tap(find.text('科幻'));

    expect(changedTags, <String>['科幻']);
  });
}

List<String> _identityTags(Iterable<String> values) => values.toList();

void _ignoreTags(List<String> values) {}
