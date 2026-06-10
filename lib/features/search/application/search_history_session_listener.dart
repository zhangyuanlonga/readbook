import '../../../core/auth/session_change_listener.dart';
import 'search_history_service.dart';

class SearchHistorySessionListener implements SessionChangeListener {
  SearchHistorySessionListener({SearchHistoryService? searchHistoryService})
    : _searchHistoryService = searchHistoryService ?? SearchHistoryService();

  final SearchHistoryService _searchHistoryService;

  @override
  Future<void> onUserLogin(String userId) async {
    await _searchHistoryService.getAll();
  }

  @override
  Future<void> onUserLogout(String? userId) async {
    // Search history is user-scoped and intentionally retained across logout.
  }
}
