class ReaderZhLayoutPolicy {
  const ReaderZhLayoutPolicy();

  static const String version = 'zh_layout_v1';
  static const String _lineStartProhibited = '，。！？；：、)]}）】》」』”’…';
  static const String _lineEndProhibited = '([{（【《「『“‘';

  bool isLineStartProhibited(String char) {
    return _lineStartProhibited.contains(char);
  }

  bool isLineEndProhibited(String char) {
    return _lineEndProhibited.contains(char);
  }

  int adjustBreakOffset({
    required String text,
    required int start,
    required int proposedEnd,
  }) {
    if (text.isEmpty) {
      return 0;
    }
    final minEnd = (start + 1).clamp(1, text.length);
    var end = proposedEnd.clamp(minEnd, text.length);
    if (end >= text.length) {
      return text.length;
    }

    while (end > minEnd && isLineStartProhibited(_charAt(text, end))) {
      end -= 1;
    }
    while (end > minEnd && isLineEndProhibited(_charAt(text, end - 1))) {
      end -= 1;
    }
    end = _avoidAsciiWordSplit(
      text: text,
      start: start,
      end: end,
      minEnd: minEnd,
    );
    return end.clamp(minEnd, text.length);
  }

  int _avoidAsciiWordSplit({
    required String text,
    required int start,
    required int end,
    required int minEnd,
  }) {
    if (end <= minEnd || end >= text.length) {
      return end;
    }
    final previous = _charAt(text, end - 1);
    final next = _charAt(text, end);
    if (!_isAsciiWordChar(previous) || !_isAsciiWordChar(next)) {
      return end;
    }

    for (var index = end - 1; index >= minEnd; index--) {
      if (!_isAsciiWordChar(_charAt(text, index))) {
        return index + 1;
      }
    }
    return end;
  }

  bool _isAsciiWordChar(String char) {
    if (char.isEmpty) {
      return false;
    }
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 95;
  }

  String _charAt(String text, int index) {
    if (index < 0 || index >= text.length) {
      return '';
    }
    return String.fromCharCode(text.codeUnitAt(index));
  }
}
