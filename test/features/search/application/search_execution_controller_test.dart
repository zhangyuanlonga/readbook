import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/features/search/application/search_execution_controller.dart';
import 'package:shuxiang_reading_next/features/search/application/search_models.dart';

void main() {
  test('passes execution request to injected runner', () async {
    SearchExecutionRequest? capturedRequest;
    final progressReports = <SearchExecutionReport>[];
    final token = SearchCancellationToken();
    final progressReport = _report(keyword: '途中');
    final finalReport = _report(keyword: '三体');
    final controller = SearchExecutionController(
      runSearch: (request) async {
        capturedRequest = request;
        request.onProgress?.call(progressReport);
        return finalReport;
      },
    );

    final result = await controller.run(
      SearchExecutionRequest(
        keyword: '三体',
        contentMode: SearchContentMode.audio,
        preciseMatch: true,
        aggregateByTitleAuthor: false,
        sourceIds: const <String>['source_1'],
        groupNames: const <String>['分组 A'],
        cancellationToken: token,
        onProgress: progressReports.add,
      ),
    );

    expect(result, same(finalReport));
    expect(capturedRequest?.keyword, '三体');
    expect(capturedRequest?.contentMode, SearchContentMode.audio);
    expect(capturedRequest?.sourceIds, <String>['source_1']);
    expect(capturedRequest?.groupNames, <String>['分组 A']);
    expect(capturedRequest?.preciseMatch, isTrue);
    expect(capturedRequest?.aggregateByTitleAuthor, isFalse);
    expect(capturedRequest?.cancellationToken, same(token));
    expect(progressReports, <SearchExecutionReport>[progressReport]);
  });
}

SearchExecutionReport _report({required String keyword}) {
  return SearchExecutionReport(
    keyword: keyword,
    sourceCount: 1,
    successSourceCount: 1,
    books: <Book>[
      Book(
        id: 'book_$keyword',
        sourceId: 'source_1',
        title: keyword,
        detailUrl: 'https://example.com/$keyword',
      ),
    ],
    failures: const <SourceSearchFailure>[],
    sourceNames: const <String, String>{'source_1': '测试源'},
  );
}
