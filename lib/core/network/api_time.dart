DateTime? parseApiTimeUtc(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return null;
  }
  return parsed.toUtc();
}

DateTime? parseApiTimeLocal(String? value) {
  final utc = parseApiTimeUtc(value);
  return utc?.toLocal();
}
