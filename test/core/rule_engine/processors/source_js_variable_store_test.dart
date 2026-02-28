import 'package:flutter_appread/core/rule_engine/processors/source_js_variable_store.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceJsVariableStore', () {
    test('loads persisted variables with runtime aliases', () {
      final source = SourceDefinition(
        id: 's1',
        name: '源1',
        baseUrl: 'https://example.com',
        originalSource: <String, dynamic>{
          SourceJsVariableStore.storageKey: <String, dynamic>{'token': 'abc'},
        },
      );

      final variables = SourceJsVariableStore.load(source);
      expect(variables, <String, String>{'token': 'abc', r'$.token': 'abc'});
    });

    test('merges updates into source original payload', () {
      final source = SourceDefinition(
        id: 's2',
        name: '源2',
        baseUrl: 'https://example.com',
        originalSource: <String, dynamic>{
          SourceJsVariableStore.storageKey: <String, dynamic>{'token': 'abc'},
        },
      );

      final next = SourceJsVariableStore.merge(
        source: source,
        updates: <String, String>{r'$.token': 'xyz', 'channel': 'android'},
      );

      expect(next.originalSource, isNotNull);
      expect(
        next.originalSource![SourceJsVariableStore.storageKey],
        <String, String>{'token': 'xyz', 'channel': 'android'},
      );
    });

    test('loads and merges book-scoped variables', () {
      final source = SourceDefinition(
        id: 's3',
        name: '源3',
        baseUrl: 'https://example.com',
        originalSource: <String, dynamic>{
          SourceJsVariableStore.bookStorageKey: <String, dynamic>{
            'book-a': <String, dynamic>{'token': 'book-token-a'},
          },
        },
      );

      final loaded = SourceJsVariableStore.loadBook(source, bookId: 'book-a');
      expect(loaded, <String, String>{
        'token': 'book-token-a',
        r'$.token': 'book-token-a',
      });

      final next = SourceJsVariableStore.mergeBook(
        source: source,
        bookId: 'book-a',
        updates: <String, String>{'pageToken': 'p-1'},
      );
      expect(
        next.originalSource![SourceJsVariableStore.bookStorageKey],
        <String, dynamic>{
          'book-a': <String, String>{
            'token': 'book-token-a',
            'pageToken': 'p-1',
          },
        },
      );
    });
  });
}
