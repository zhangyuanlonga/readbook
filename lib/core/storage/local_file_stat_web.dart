import 'dart:typed_data';

class AppLocalFileStat {
  const AppLocalFileStat({required this.size, required this.modified});

  final int size;
  final DateTime modified;
}

Future<AppLocalFileStat?> statLocalFile(String? path) async => null;

Future<bool> localFileExists(String? path) async => false;

Future<Uint8List?> readLocalFileBytes(String? path) async => null;

Future<String?> readLocalFileText(String? path) async => null;
