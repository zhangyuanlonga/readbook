import '../../../core/errors/gateway_failure.dart';
import '../../../domain/entities/book.dart';

enum DiscoverSourceStatus { available, slow, unavailable }

class DiscoverSourceSummary {
  const DiscoverSourceSummary({
    required this.id,
    this.sourceUrl,
    required this.name,
    required this.categoryCount,
    required this.status,
    required this.latencyMs,
    required this.categories,
    this.executionContext,
    this.catalogSourceId,
    this.origin = 'cloud_catalog',
    this.accessReason,
    this.sourceType,
    this.groupName,
    this.sourceReport = const <String, Object?>{},
    this.failure,
  });

  final String id;
  final String? sourceUrl;
  final String name;
  final int categoryCount;
  final DiscoverSourceStatus status;
  final int? latencyMs;
  final List<DiscoverSourceCategory> categories;
  final String? executionContext;
  final String? catalogSourceId;
  final String origin;
  final String? accessReason;
  final String? sourceType;
  final String? groupName;
  final Map<String, Object?> sourceReport;
  final GatewayFailure? failure;
}

class DiscoverSourceCategory {
  const DiscoverSourceCategory({
    required this.id,
    required this.name,
    required this.ruleFindUrl,
    required this.books,
    this.kindType,
    this.action,
    this.defaultValue,
    this.filters = const <String, String>{},
  });

  final String id;
  final String name;
  final String ruleFindUrl;
  final List<DiscoverCategoryBook> books;
  final String? kindType;
  final String? action;
  final String? defaultValue;
  final Map<String, String> filters;
}

class DiscoverCategoryBook {
  const DiscoverCategoryBook({
    required this.id,
    required this.name,
    required this.detailUrl,
    required this.coverSeed,
    this.book,
    this.coverUrl,
    this.author,
  });

  final String id;
  final String name;
  final String detailUrl;
  final int coverSeed;
  final Book? book;
  final String? coverUrl;
  final String? author;
}
