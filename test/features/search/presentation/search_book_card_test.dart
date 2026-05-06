import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/features/book/application/book_display_state.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/search_book_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders with minimal search book fields', (tester) async {
    final book = const Book(
      id: 'book_1',
      sourceId: 'source_a',
      title: '凡人修仙传',
      detailUrl: 'https://example.com/book/1',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SearchBookCard(
              book: book,
              presentation: const BookDisplayState(displayTitle: '凡人修仙传'),
              sourceName: '测试源',
              heroTag: 'hero_book_1',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('凡人修仙传'), findsWidgets);
    expect(find.text('来源: 测试源'), findsOneWidget);
    expect(find.textContaining('作者:'), findsNothing);
    expect(find.textContaining('最新章节:'), findsNothing);
  });
}
