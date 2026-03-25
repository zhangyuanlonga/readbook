String normalizeHtmlText(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}
