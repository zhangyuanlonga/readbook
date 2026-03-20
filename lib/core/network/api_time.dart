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

String formatApiTimeUtc(DateTime value) {
  final utc = value.toUtc();

  String twoDigits(int number) => number.toString().padLeft(2, '0');
  String fourDigits(int number) => number.toString().padLeft(4, '0');

  return '${fourDigits(utc.year)}-${twoDigits(utc.month)}-'
      '${twoDigits(utc.day)}T${twoDigits(utc.hour)}:'
      '${twoDigits(utc.minute)}:${twoDigits(utc.second)}Z';
}
