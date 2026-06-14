import 'package:file_selector/file_selector.dart';

import 'external_source_import_bridge.dart';

class ExternalImportCatalog {
  ExternalImportCatalog._();

  static const XTypeGroup localBookTypeGroup = XTypeGroup(
    label: 'Book Files',
    extensions: <String>[
      'txt',
      'epub',
      'md',
      'markdown',
      'html',
      'htm',
      'pdf',
      'mobi',
      'azw',
      'azw3',
    ],
    mimeTypes: <String>[
      'text/plain',
      'application/epub+zip',
      'text/markdown',
      'text/x-markdown',
      'text/html',
      'application/pdf',
      'application/x-mobipocket-ebook',
      'application/vnd.amazon.ebook',
      'application/vnd.amazon.mobi8-ebook',
      'application/octet-stream',
    ],
    uniformTypeIdentifiers: <String>[
      'public.plain-text',
      'public.text',
      'org.idpf.epub-container',
      'com.jiangyan.selune.markdown',
      'public.html',
      'com.adobe.pdf',
      'com.jiangyan.selune.mobi',
      'com.jiangyan.selune.azw',
      'com.jiangyan.selune.azw3',
      'public.data',
    ],
  );

  static const XTypeGroup bookSourceJsonTypeGroup = XTypeGroup(
    label: 'Book source JSON',
    extensions: <String>['json', 'txt'],
    mimeTypes: <String>['application/json', 'text/json', 'text/plain'],
    uniformTypeIdentifiers: <String>[
      'public.json',
      'public.plain-text',
      'public.text',
    ],
  );

  static const XTypeGroup advancedThemeZipTypeGroup = XTypeGroup(
    label: 'Advanced theme bundle',
    extensions: <String>['zip'],
    mimeTypes: <String>['application/zip', 'application/x-zip-compressed'],
    uniformTypeIdentifiers: <String>['public.zip-archive'],
  );

  static const XTypeGroup advancedThemeImportTypeGroup = XTypeGroup(
    label: 'Advanced theme package',
    extensions: <String>['zip', 'json'],
    mimeTypes: <String>[
      'application/zip',
      'application/x-zip-compressed',
      'application/json',
      'text/json',
    ],
    uniformTypeIdentifiers: <String>['public.zip-archive', 'public.json'],
  );

  static const XTypeGroup advancedThemeRedTypeGroup = XTypeGroup(
    label: 'Red theme package',
    extensions: <String>['red'],
    mimeTypes: <String>['application/octet-stream', 'application/zip'],
    uniformTypeIdentifiers: <String>['public.data'],
  );

  static const XTypeGroup advancedThemeRgShareTypeGroup = XTypeGroup(
    label: 'RGShare theme package',
    extensions: <String>['rgshare'],
    mimeTypes: <String>['application/octet-stream', 'application/zip'],
    uniformTypeIdentifiers: <String>['public.data'],
  );

  static const XTypeGroup fontTypeGroup = XTypeGroup(
    label: 'Font Files',
    extensions: <String>['ttf', 'otf'],
    mimeTypes: <String>[
      'font/ttf',
      'font/otf',
      'application/font-sfnt',
      'application/x-font-ttf',
      'application/x-font-opentype',
      'application/octet-stream',
    ],
    uniformTypeIdentifiers: <String>[
      'public.truetype-ttf-font',
      'public.opentype-font',
      'public.data',
    ],
  );

  static String routeForPayloadType(ExternalImportPayloadType type) {
    return switch (type) {
      ExternalImportPayloadType.localBook => '/bookshelf',
      ExternalImportPayloadType.advancedTheme => '/appearance/advanced-themes',
      ExternalImportPayloadType.font => '/font-management',
    };
  }

  static bool supportsFileLabel(ExternalImportPayloadType type, String label) {
    final extension = _normalizedExtension(label);
    if (extension.isEmpty) {
      return false;
    }
    return switch (type) {
      ExternalImportPayloadType.localBook => _localBookExtensions.contains(
        extension,
      ),
      ExternalImportPayloadType.advancedTheme => _advancedThemeExtensions
          .contains(extension),
      ExternalImportPayloadType.font => _fontExtensions.contains(extension),
    };
  }

  static bool supportsMimeType(
    ExternalImportPayloadType type,
    String? mimeType,
  ) {
    final normalized = mimeType?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    return switch (type) {
      ExternalImportPayloadType.localBook => _localBookMimeTypes.contains(
        normalized,
      ),
      ExternalImportPayloadType.advancedTheme => _advancedThemeMimeTypes
          .contains(normalized),
      ExternalImportPayloadType.font => _fontMimeTypes.contains(normalized),
    };
  }

  static bool supportsFileMetadata(
    ExternalImportPayloadType type, {
    required String label,
    String? mimeType,
  }) {
    if (supportsFileLabel(type, label)) {
      return true;
    }
    final normalizedMimeType = mimeType?.trim().toLowerCase();
    if (normalizedMimeType == 'application/octet-stream') {
      return false;
    }
    return supportsMimeType(type, normalizedMimeType);
  }

  static String unsupportedFileMessage(
    ExternalImportPayloadType type,
    String label,
  ) {
    return switch (type) {
      ExternalImportPayloadType.localBook => '暂不支持导入该文件：$label',
      ExternalImportPayloadType.advancedTheme => '暂不支持导入该主题文件：$label',
      ExternalImportPayloadType.font => '暂不支持导入该字体文件：$label',
    };
  }

  static String _normalizedExtension(String label) {
    final normalized = label.trim().toLowerCase();
    if (!normalized.contains('.')) {
      return '';
    }
    return normalized.substring(normalized.lastIndexOf('.'));
  }

  static const Set<String> _localBookExtensions = <String>{
    '.txt',
    '.epub',
    '.md',
    '.markdown',
    '.html',
    '.htm',
    '.pdf',
    '.mobi',
    '.azw',
    '.azw3',
  };

  static const Set<String> _localBookMimeTypes = <String>{
    'text/plain',
    'application/epub+zip',
    'text/markdown',
    'text/x-markdown',
    'text/html',
    'application/pdf',
    'application/x-mobipocket-ebook',
    'application/vnd.amazon.ebook',
    'application/vnd.amazon.mobi8-ebook',
    'application/octet-stream',
  };

  static const Set<String> _advancedThemeExtensions = <String>{
    '.zip',
    '.json',
    '.red',
    '.rgshare',
  };

  static const Set<String> _advancedThemeMimeTypes = <String>{
    'application/zip',
    'application/x-zip-compressed',
    'application/json',
    'text/json',
    'application/octet-stream',
  };

  static const Set<String> _fontExtensions = <String>{'.ttf', '.otf'};

  static const Set<String> _fontMimeTypes = <String>{
    'font/ttf',
    'font/otf',
    'application/font-sfnt',
    'application/x-font-ttf',
    'application/x-font-opentype',
    'application/octet-stream',
  };
}
