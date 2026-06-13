import 'package:flutter/material.dart';

import '../application/private_book_source_service.dart';

enum PrivateBookSourceBadgeTone {
  primary,
  secondary,
  neutral,
  success,
  warning,
  danger,
}

class PrivateBookSourceBadgeSpec {
  const PrivateBookSourceBadgeSpec({required this.label, required this.tone});

  final String label;
  final PrivateBookSourceBadgeTone tone;
}

class PrivateBookSourcePresentation {
  const PrivateBookSourcePresentation._();

  static List<PrivateBookSourceBadgeSpec> badgesFor(
    PrivateBookSourceItem item,
  ) {
    final normalizationStatus = item.normalizationStatus.trim();
    final normalizationMessage = item.normalizationError.trim();
    final testStatus = item.lastTestStatus.trim();
    final testMessage = item.lastTestMessage.trim();
    return <PrivateBookSourceBadgeSpec>[
      PrivateBookSourceBadgeSpec(
        label: typeLabel(item.supportedTypes),
        tone: PrivateBookSourceBadgeTone.primary,
      ),
      PrivateBookSourceBadgeSpec(
        label: groupLabel(item.groupName),
        tone: PrivateBookSourceBadgeTone.neutral,
      ),
      PrivateBookSourceBadgeSpec(
        label: reviewLabel(item.reviewStatus, item.visibility),
        tone:
            item.visibility == 'private'
                ? PrivateBookSourceBadgeTone.primary
                : _reviewTone(item.reviewStatus),
      ),
      if (_showNormalizationBadge(normalizationStatus))
        PrivateBookSourceBadgeSpec(
          label:
              '配置 ${normalizationLabel(normalizationStatus)}'
              '${normalizationMessage.isEmpty ? '' : ' $normalizationMessage'}',
          tone: _normalizationTone(normalizationStatus),
        ),
      if (testStatus.isNotEmpty || testMessage.isNotEmpty)
        PrivateBookSourceBadgeSpec(
          label:
              '检测 ${testLabel(testStatus)}'
              '${testMessage.isEmpty ? '' : ' $testMessage'}',
          tone: testTone(testStatus),
        ),
      if (item.description.trim().isNotEmpty)
        PrivateBookSourceBadgeSpec(
          label: item.description.trim(),
          tone: PrivateBookSourceBadgeTone.neutral,
        ),
    ];
  }

  static String typeLabel(List<String> types) {
    if (types.isEmpty) {
      return '小说';
    }
    return types
        .map((type) {
          return switch (type) {
            'novel' => '小说',
            'comic' => '漫画',
            'audio' => '音频',
            'video' => '视频',
            _ => type,
          };
        })
        .join('、');
  }

  static String groupLabel(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '未分组' : normalized;
  }

  static String reviewLabel(String value, String visibility) {
    if (visibility == 'private') {
      return '私人';
    }
    if (visibility == 'shared') {
      return switch (value) {
        'pending' => '共享 · 待审核',
        'approved' => '共享',
        'rejected' => '共享 · 已拒绝',
        _ => '共享',
      };
    }
    return switch (value) {
      'pending' => '待审核',
      'approved' => '已通过',
      'rejected' => '已拒绝',
      _ => value.isEmpty ? '待审核' : value,
    };
  }

  static String testLabel(String value) {
    return switch (value) {
      'passed' || 'pass' || 'success' => '通过',
      'failed' || 'fail' || 'error' => '失败',
      'unknown' => '未检测',
      'pending' => '待检测',
      _ => value.isEmpty ? '未检测' : value,
    };
  }

  static PrivateBookSourceBadgeTone testTone(String status) {
    return switch (status) {
      'passed' || 'pass' || 'success' => PrivateBookSourceBadgeTone.success,
      'failed' || 'fail' || 'error' => PrivateBookSourceBadgeTone.danger,
      'unknown' || 'pending' || '' => PrivateBookSourceBadgeTone.neutral,
      _ => PrivateBookSourceBadgeTone.warning,
    };
  }

  static String normalizationLabel(String status) {
    return switch (status) {
      'done' => '正常',
      'pending' => '待规整',
      'failed' => '配置异常',
      _ => status.isEmpty ? '未知' : status,
    };
  }

  static String normalizationSearchLabel(String status) {
    return switch (status) {
      'pending' => '待规整',
      'failed' => '配置异常',
      'done' => '配置正常',
      _ => status,
    };
  }

  static String formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static Color toneForeground(
    PrivateBookSourceBadgeTone tone,
    ColorScheme colorScheme,
  ) {
    return switch (tone) {
      PrivateBookSourceBadgeTone.primary => colorScheme.primary,
      PrivateBookSourceBadgeTone.secondary => colorScheme.secondary,
      PrivateBookSourceBadgeTone.neutral => colorScheme.onSurfaceVariant,
      PrivateBookSourceBadgeTone.success => Colors.green,
      PrivateBookSourceBadgeTone.warning => Colors.orange,
      PrivateBookSourceBadgeTone.danger => colorScheme.error,
    };
  }

  static bool _showNormalizationBadge(String status) {
    return status.isNotEmpty && status != 'done';
  }

  static PrivateBookSourceBadgeTone _reviewTone(String status) {
    return switch (status) {
      'approved' => PrivateBookSourceBadgeTone.success,
      'rejected' => PrivateBookSourceBadgeTone.danger,
      'pending' => PrivateBookSourceBadgeTone.warning,
      _ => PrivateBookSourceBadgeTone.neutral,
    };
  }

  static PrivateBookSourceBadgeTone _normalizationTone(String status) {
    return switch (status) {
      'failed' => PrivateBookSourceBadgeTone.danger,
      'pending' => PrivateBookSourceBadgeTone.warning,
      _ => PrivateBookSourceBadgeTone.neutral,
    };
  }
}
