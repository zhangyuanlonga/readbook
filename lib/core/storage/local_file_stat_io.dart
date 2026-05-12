import 'dart:io';
import 'dart:typed_data';

class AppLocalFileStat {
  const AppLocalFileStat({required this.size, required this.modified});

  final int size;
  final DateTime modified;
}

Future<AppLocalFileStat?> statLocalFile(String? path) async {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  try {
    final file = File(normalized);
    if (!await file.exists()) {
      return null;
    }
    final stat = await file.stat();
    return AppLocalFileStat(size: stat.size, modified: stat.modified);
  } catch (_) {
    return null;
  }
}

Future<bool> localFileExists(String? path) async {
  return await statLocalFile(path) != null;
}

Future<Uint8List?> readLocalFileBytes(String? path) async {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  try {
    final file = File(normalized);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<String?> readLocalFileText(String? path) async {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  try {
    final file = File(normalized);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsString();
  } catch (_) {
    return null;
  }
}
