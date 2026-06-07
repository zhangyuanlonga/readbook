import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page_models.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_grid_book_card.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_list_book_card.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/widgets/bookshelf_progress_indicator.dart';

void main() {
  testWidgets('bookshelf cards stay bounded on mobile width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 168,
              height: 260,
              child: BookshelfGridBookCardShell(
                isPressed: false,
                pressDuration: Duration.zero,
                selectionMode: false,
                batchDeleting: false,
                openingOrBusy: false,
                onTapDown: _noop,
                onTapCancel: _noop,
                onTapUp: _noop,
                onLongPress: _noopAsync,
                onTap: _noopAsync,
                child: _CardContent(width: 150),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BookshelfGridBookCardShell)).width, 168);
  });

  testWidgets('bookshelf list card stays bounded on desktop width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 560,
              child: BookshelfListBookCardShell(
                isPressed: false,
                pressDuration: Duration.zero,
                margin: EdgeInsets.zero,
                cardColor: Colors.white,
                borderColor: Colors.black12,
                selectionMode: false,
                openingOrBusy: false,
                onTapDown: _noop,
                onTapCancel: _noop,
                onTapUp: _noop,
                onTap: _noopAsync,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: _CardContent(width: 520),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BookshelfListBookCardShell)).width, 560);
  });
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '很长很长很长的书名用于检查宽度约束',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          BookshelfAnimatedProgressSection(
            progressDisplay: const BookshelfProgressDisplay(
              progressValue: 0.42,
              summaryText: '读到第 12 / 30 章 · 剩余 18 章',
              trailingLabel: '42%',
              unreadLabel: '未读 18 章',
              hasProgress: true,
              hasUnreadChapters: true,
            ),
            summaryStyle: Theme.of(context).textTheme.bodySmall,
            trailingStyle: Theme.of(context).textTheme.bodySmall,
            fillColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ],
      ),
    );
  }
}

void _noop() {}

Future<void> _noopAsync() async {}
