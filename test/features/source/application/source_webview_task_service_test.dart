import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_webview_task_service.dart';

void main() {
  group('SourceWebViewTask', () {
    test('parses backend task envelope data', () {
      final task = SourceWebViewTask.fromJson({
        'taskId': 'task-1',
        'sourceId': 'src',
        'sourceName': '测试源',
        'stage': 'content',
        'mode': 'html',
        'request': {
          'url': 'https://example.com/chapter/1',
          'method': 'post',
          'headers': {'User-Agent': 'reader'},
          'body': 'a=1',
          'webJs': 'document.body.innerHTML',
          'webViewDelayTime': '1200',
        },
        'baseUrl': 'https://example.com/chapter/1',
        'javaScript': 'document.documentElement.outerHTML',
        'sourceRegex': r'https://cdn\.example/.+',
        'delayMs': '800',
        'timeoutMs': 60000,
      });

      expect(task.taskId, 'task-1');
      expect(task.sourceName, '测试源');
      expect(task.request.method, 'POST');
      expect(task.request.headers, {'User-Agent': 'reader'});
      expect(task.request.webViewDelayTime, 1200);
      expect(task.delayMs, 800);
    });
  });

  group('SourceWebViewResult', () {
    test('serializes optional html, matched url and browser state', () {
      final result = SourceWebViewResult(
        taskId: 'task-1',
        sourceId: 'src',
        stage: 'content',
        mode: 'html',
        html: '<html></html>',
        matchedUrl: 'https://cdn.example/book.txt',
        finalUrl: 'https://example.com/chapter/1',
        cookies: 'sid=abc',
        localStorage: {'token': 'local'},
      );

      expect(result.toJson(), {
        'taskId': 'task-1',
        'sourceId': 'src',
        'stage': 'content',
        'mode': 'html',
        'html': '<html></html>',
        'matchedUrl': 'https://cdn.example/book.txt',
        'finalUrl': 'https://example.com/chapter/1',
        'cookies': 'sid=abc',
        'localStorage': {'token': 'local'},
      });
    });
  });

  group('SourceWebViewBookRef', () {
    test('strips server gateway prefix before sending to backend', () {
      final json =
          SourceWebViewBookRef(
            sourceId: 'server-gateway:src',
            bookId: 'book-1',
            detailUrl: 'https://example.com/book/1',
            tocUrl: 'https://example.com/toc/1',
          ).toJson();

      expect(json['sourceId'], 'src');
      expect(json['bookId'], 'book-1');
      expect(json['detailUrl'], 'https://example.com/book/1');
      expect(json['tocUrl'], 'https://example.com/toc/1');
    });
  });
}
