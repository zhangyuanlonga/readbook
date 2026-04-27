import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/search_book_presentation_service.dart';

final searchBookPresentationServiceProvider =
    Provider<SearchBookPresentationService>((ref) {
      return SearchBookPresentationService();
    });
