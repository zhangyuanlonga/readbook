import 'http_models.dart';

enum ChallengeKind { captcha, login, blocked, unknown }

class ChallengeDetectionResult {
  const ChallengeDetectionResult({
    required this.isChallenge,
    this.kind,
    this.reason,
  });

  final bool isChallenge;
  final ChallengeKind? kind;
  final String? reason;
}

abstract class ChallengeDetector {
  ChallengeDetectionResult detect(RuntimeHttpResponse response);
}

class DefaultChallengeDetector implements ChallengeDetector {
  const DefaultChallengeDetector();

  static const List<String> _captchaMarkers = <String>[
    'captcha',
    'verify',
    'verification',
    'security check',
    'security verification',
    'human verification',
    '人机验证',
    '验证码',
    '安全验证',
  ];

  static const List<String> _loginMarkers = <String>[
    'login required',
    'please sign in',
    '请先登录',
    '账号登录',
  ];

  static const List<String> _blockedMarkers = <String>[
    'access denied',
    'forbidden',
    '访问异常',
    '请求过于频繁',
  ];

  @override
  ChallengeDetectionResult detect(RuntimeHttpResponse response) {
    final haystack =
        <String>[
          response.uri.toString(),
          response.text ?? '',
          response.headers['location'] ?? '',
        ].join(' ').toLowerCase();

    for (final marker in _captchaMarkers) {
      if (haystack.contains(marker)) {
        return const ChallengeDetectionResult(
          isChallenge: true,
          kind: ChallengeKind.captcha,
          reason: 'captcha_detected',
        );
      }
    }

    for (final marker in _loginMarkers) {
      if (haystack.contains(marker)) {
        return const ChallengeDetectionResult(
          isChallenge: true,
          kind: ChallengeKind.login,
          reason: 'login_required',
        );
      }
    }

    for (final marker in _blockedMarkers) {
      if (haystack.contains(marker)) {
        return const ChallengeDetectionResult(
          isChallenge: true,
          kind: ChallengeKind.blocked,
          reason: 'blocked_detected',
        );
      }
    }

    return const ChallengeDetectionResult(isChallenge: false);
  }
}
