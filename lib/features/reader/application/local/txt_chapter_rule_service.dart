import 'txt_auto_chapter_patterns.dart';

class TxtChapterRuleService {
  const TxtChapterRuleService();

  /// TXT 章节规则现在统一使用内置规则。
  ///
  /// 早期曾支持用户自定义章节正则，并将配置写入 SharedPreferences。
  /// 该入口已经没有产品 UI 承接，继续读取旧配置会让同一本书在不同设备、
  /// 不同历史配置下解析结果不一致。因此本地阅读规范化后，TXT 只使用
  /// 版本内置规则；需要新增规则时通过代码和测试一起发布。
  Future<List<TxtAutoChapterPattern>> loadEnabledPatterns() async {
    return builtInEnabledTxtChapterPatterns();
  }
}

List<TxtAutoChapterPattern> builtInEnabledTxtChapterPatterns() {
  return defaultTxtAutoChapterPatterns
      .where((rule) => rule.enabled && rule.pattern.trim().isNotEmpty)
      .toList(growable: false);
}
