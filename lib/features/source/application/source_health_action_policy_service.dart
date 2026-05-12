import '../../../domain/entities/source_health.dart';

class SourceHealthActionPolicyService {
  const SourceHealthActionPolicyService();

  static const Duration _recentFailureWindow = Duration(hours: 12);

  bool shouldSuggestDisable(SourceHealthSnapshot snapshot) {
    return snapshot.level == SourceHealthLevel.unavailable ||
        snapshot.consecutiveFailures >= 2 ||
        snapshot.totalFailures >= 3;
  }

  bool shouldAutoDisable(SourceHealthSnapshot snapshot) {
    final lastFailureAt = snapshot.lastFailureAt;
    if (!snapshot.enabled || lastFailureAt == null) {
      return false;
    }
    if (DateTime.now().difference(lastFailureAt) > _recentFailureWindow) {
      return false;
    }
    if (snapshot.consecutiveFailures < 2) {
      return false;
    }
    return (snapshot.level == SourceHealthLevel.unavailable &&
            snapshot.totalFailures >= 3) ||
        (snapshot.browserRiskCount >= 2 && snapshot.totalFailures >= 3) ||
        (snapshot.timeoutCount >= 2 && snapshot.totalFailures >= 3) ||
        snapshot.consecutiveFailures >= 3;
  }

  String buildAutoDisableReason(SourceHealthSnapshot snapshot) {
    if (snapshot.browserRiskCount >= 2) {
      return '多次触发 browser/challenge 风险，已自动停用。';
    }
    if (snapshot.timeoutCount >= 2) {
      return '多次请求超时，已自动停用。';
    }
    if (snapshot.consecutiveFailures >= 2) {
      return '连续失败次数过高，已自动停用。';
    }
    return '近期失败次数过高，已自动停用。';
  }
}
