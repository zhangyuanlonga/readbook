import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:http/http.dart' as http;

const _pdfiumRelease = 'chromium%2F7811';
const _assetName = 'libpdfium';
const _defaultMirrorBaseUrl =
    'https://gh-proxy.com/https://github.com/bblanchon/pdfium-binaries/releases/download';
const _githubBaseUrl =
    'https://github.com/bblanchon/pdfium-binaries/releases/download';
const _downloadTimeout = Duration(seconds: 20);

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (input.config.code.targetOS == OS.iOS) return;

    final target = _PdfiumTarget.fromCodeConfig(input.config.code);
    final outputSubdir = _pdfiumRelease.replaceAll('%2F', '_');
    final outputFile = input.outputDirectoryShared.resolve(
      '$outputSubdir/${target.archivePlatform}-${target.archiveArch}/${target.libraryFileName}',
    );

    await _downloadPdfium(
      outputFile: outputFile,
      target: target,
      pdfiumRelease: _pdfiumRelease,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: outputFile,
      ),
    );
  });
}

Future<void> _downloadPdfium({
  required Uri outputFile,
  required _PdfiumTarget target,
  required String pdfiumRelease,
}) async {
  final output = File.fromUri(outputFile);
  if (await output.exists()) return;

  final archivePath =
      '$pdfiumRelease/pdfium-${target.archivePlatform}-${target.archiveArch}.tgz';
  final archiveUris = _resolveArchiveUris(archivePath);

  http.Response? response;
  Object? lastError;
  Uri? resolvedArchiveUri;
  final client = http.Client();
  try {
    for (final archiveUri in archiveUris) {
      try {
        final candidateResponse = await client
            .get(archiveUri)
            .timeout(_downloadTimeout);
        if (candidateResponse.statusCode == 200) {
          response = candidateResponse;
          resolvedArchiveUri = archiveUri;
          break;
        }
        lastError = Exception(
          'Unexpected status ${candidateResponse.statusCode} from $archiveUri',
        );
      } on TimeoutException catch (error) {
        lastError = error;
      } on Object catch (error) {
        lastError = error;
      }
    }
  } finally {
    client.close();
  }

  if (response == null || resolvedArchiveUri == null) {
    throw Exception('Failed to download PDFium: $lastError');
  }

  final archive = TarDecoder().decodeBytes(
    GZipDecoder().decodeBytes(response.bodyBytes),
  );
  final member = archive.findFile(target.archiveLibraryPath);
  if (member == null) {
    throw Exception(
      'PDFium archive $resolvedArchiveUri does not contain ${target.archiveLibraryPath}.',
    );
  }

  await output.parent.create(recursive: true);
  await output.writeAsBytes(member.content as List<int>);
}

List<Uri> _resolveArchiveUris(String archivePath) {
  final configuredBaseUrl = Platform.environment['PDFIUM_DOWNLOAD_BASE_URL']
      ?.trim();
  final candidates = <String>[
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty)
      configuredBaseUrl,
    _defaultMirrorBaseUrl,
    _githubBaseUrl,
  ];

  return candidates
      .toSet()
      .map((baseUrl) {
        final normalizedBaseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
        return Uri.parse('$normalizedBaseUrl/$archivePath');
      })
      .toList(growable: false);
}

final class _PdfiumTarget {
  const _PdfiumTarget({
    required this.archivePlatform,
    required this.archiveArch,
    required this.archiveLibraryPath,
    required this.libraryFileName,
  });

  final String archivePlatform;
  final String archiveArch;
  final String archiveLibraryPath;
  final String libraryFileName;

  static _PdfiumTarget fromCodeConfig(CodeConfig config) {
    final arch = switch (config.targetArchitecture) {
      Architecture.ia32 => 'x86',
      Architecture.x64 => 'x64',
      Architecture.arm => 'arm',
      Architecture.arm64 => 'arm64',
      _ => throw UnsupportedError(
        'Unsupported PDFium architecture: ${config.targetArchitecture}',
      ),
    };

    return switch (config.targetOS) {
      OS.android => _PdfiumTarget(
        archivePlatform: 'android',
        archiveArch: arch,
        archiveLibraryPath: 'lib/libpdfium.so',
        libraryFileName: 'libpdfium.so',
      ),
      OS.windows => _PdfiumTarget(
        archivePlatform: 'win',
        archiveArch: arch,
        archiveLibraryPath: 'bin/pdfium.dll',
        libraryFileName: 'pdfium.dll',
      ),
      OS.linux => _PdfiumTarget(
        archivePlatform: 'linux',
        archiveArch: arch,
        archiveLibraryPath: 'lib/libpdfium.so',
        libraryFileName: 'libpdfium.so',
      ),
      OS.macOS => _PdfiumTarget(
        archivePlatform: 'mac',
        archiveArch: arch,
        archiveLibraryPath: 'lib/libpdfium.dylib',
        libraryFileName: 'libpdfium.dylib',
      ),
      _ => throw UnsupportedError(
        'Unsupported PDFium platform: ${config.targetOS}',
      ),
    };
  }
}
