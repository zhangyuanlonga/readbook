enum BottomNavIconGalleryTab { bookshelf, discover, stats, mine }

enum BottomNavIconAssetFormat { svg, png }

enum BottomNavIconVariantSlot {
  lightUnselected,
  lightSelected,
  darkUnselected,
  darkSelected,
}

class BottomNavIconAssetRef {
  const BottomNavIconAssetRef({
    required this.path,
    required this.format,
    required this.isAsset,
  });

  final String path;
  final BottomNavIconAssetFormat format;
  final bool isAsset;

  Map<String, dynamic> toJson() {
    return {'path': path, 'format': format.name, 'isAsset': isAsset};
  }

  factory BottomNavIconAssetRef.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path']?.toString().trim() ?? '';
    if (rawPath.isEmpty) {
      throw const FormatException('Missing required field: path');
    }

    final rawFormat = json['format']?.toString().trim() ?? '';
    final format = switch (rawFormat) {
      'svg' => BottomNavIconAssetFormat.svg,
      'png' => BottomNavIconAssetFormat.png,
      _ => throw const FormatException('Invalid required field: format'),
    };

    final rawIsAsset = json['isAsset'];
    if (rawIsAsset is! bool) {
      throw const FormatException('Missing required field: isAsset');
    }

    return BottomNavIconAssetRef(
      path: rawPath,
      format: format,
      isAsset: rawIsAsset,
    );
  }

  BottomNavIconAssetRef copyWith({
    String? path,
    BottomNavIconAssetFormat? format,
    bool? isAsset,
  }) {
    return BottomNavIconAssetRef(
      path: path ?? this.path,
      format: format ?? this.format,
      isAsset: isAsset ?? this.isAsset,
    );
  }
}

class BottomNavIconSet {
  const BottomNavIconSet({
    this.lightUnselected,
    this.lightSelected,
    this.darkUnselected,
    this.darkSelected,
  });

  final BottomNavIconAssetRef? lightUnselected;
  final BottomNavIconAssetRef? lightSelected;
  final BottomNavIconAssetRef? darkUnselected;
  final BottomNavIconAssetRef? darkSelected;

  Map<String, dynamic> toJson() {
    return {
      if (lightUnselected != null) 'lightUnselected': lightUnselected!.toJson(),
      if (lightSelected != null) 'lightSelected': lightSelected!.toJson(),
      if (darkUnselected != null) 'darkUnselected': darkUnselected!.toJson(),
      if (darkSelected != null) 'darkSelected': darkSelected!.toJson(),
    };
  }

  factory BottomNavIconSet.fromJson(Map<String, dynamic> json) {
    return BottomNavIconSet(
      lightUnselected: _readAsset(json['lightUnselected']),
      lightSelected: _readAsset(json['lightSelected']),
      darkUnselected: _readAsset(json['darkUnselected']),
      darkSelected: _readAsset(json['darkSelected']),
    );
  }

  BottomNavIconSet copyWith({
    BottomNavIconAssetRef? lightUnselected,
    bool clearLightUnselected = false,
    BottomNavIconAssetRef? lightSelected,
    bool clearLightSelected = false,
    BottomNavIconAssetRef? darkUnselected,
    bool clearDarkUnselected = false,
    BottomNavIconAssetRef? darkSelected,
    bool clearDarkSelected = false,
  }) {
    return BottomNavIconSet(
      lightUnselected:
          clearLightUnselected ? null : (lightUnselected ?? this.lightUnselected),
      lightSelected:
          clearLightSelected ? null : (lightSelected ?? this.lightSelected),
      darkUnselected:
          clearDarkUnselected ? null : (darkUnselected ?? this.darkUnselected),
      darkSelected:
          clearDarkSelected ? null : (darkSelected ?? this.darkSelected),
    );
  }

  BottomNavIconAssetRef? assetForSlot(BottomNavIconVariantSlot slot) {
    return switch (slot) {
      BottomNavIconVariantSlot.lightUnselected => lightUnselected,
      BottomNavIconVariantSlot.lightSelected => lightSelected,
      BottomNavIconVariantSlot.darkUnselected => darkUnselected,
      BottomNavIconVariantSlot.darkSelected => darkSelected,
    };
  }

  BottomNavIconSet copyWithSlot(
    BottomNavIconVariantSlot slot, {
    BottomNavIconAssetRef? asset,
    bool clear = false,
  }) {
    return switch (slot) {
      BottomNavIconVariantSlot.lightUnselected => copyWith(
        lightUnselected: asset,
        clearLightUnselected: clear,
      ),
      BottomNavIconVariantSlot.lightSelected => copyWith(
        lightSelected: asset,
        clearLightSelected: clear,
      ),
      BottomNavIconVariantSlot.darkUnselected => copyWith(
        darkUnselected: asset,
        clearDarkUnselected: clear,
      ),
      BottomNavIconVariantSlot.darkSelected => copyWith(
        darkSelected: asset,
        clearDarkSelected: clear,
      ),
    };
  }

  static BottomNavIconAssetRef? _readAsset(Object? value) {
    if (value is! Map) {
      return null;
    }
    return BottomNavIconAssetRef.fromJson(
      value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue)),
    );
  }
}

class BottomNavIconGallery {
  const BottomNavIconGallery({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.isBuiltIn,
    required this.isEditable,
    required this.isDeletable,
    required this.items,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isBuiltIn;
  final bool isEditable;
  final bool isDeletable;
  final Map<BottomNavIconGalleryTab, BottomNavIconSet> items;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isBuiltIn': isBuiltIn,
      'isEditable': isEditable,
      'isDeletable': isDeletable,
      'items': {
        for (final entry in items.entries) entry.key.name: entry.value.toJson(),
      },
    };
  }

  factory BottomNavIconGallery.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim() ?? '';
    if (rawId.isEmpty) {
      throw const FormatException('Missing required field: id');
    }

    final rawName = json['name']?.toString().trim() ?? '';
    if (rawName.isEmpty) {
      throw const FormatException('Missing required field: name');
    }

    final createdAt = _readDateTime(json, 'createdAt');
    final updatedAt = _readDateTime(json, 'updatedAt');
    final isBuiltIn = _readBool(json, 'isBuiltIn');
    final isEditable = _readBool(json, 'isEditable');
    final isDeletable = _readBool(json, 'isDeletable');
    final rawItems = json['items'];
    if (rawItems is! Map) {
      throw const FormatException('Missing required field: items');
    }

    final items = <BottomNavIconGalleryTab, BottomNavIconSet>{};
    for (final entry in rawItems.entries) {
      final tab = switch (entry.key.toString().trim()) {
        'bookshelf' => BottomNavIconGalleryTab.bookshelf,
        'discover' => BottomNavIconGalleryTab.discover,
        'stats' => BottomNavIconGalleryTab.stats,
        'mine' => BottomNavIconGalleryTab.mine,
        _ => null,
      };
      if (tab == null) {
        continue;
      }
      if (entry.value is! Map) {
        continue;
      }
      items[tab] = BottomNavIconSet.fromJson(
        (entry.value as Map).map(
          (key, nestedValue) => MapEntry(key.toString(), nestedValue),
        ),
      );
    }

    return BottomNavIconGallery(
      id: rawId,
      name: rawName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isBuiltIn: isBuiltIn,
      isEditable: isEditable,
      isDeletable: isDeletable,
      items: Map<BottomNavIconGalleryTab, BottomNavIconSet>.unmodifiable(items),
    );
  }

  BottomNavIconGallery copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBuiltIn,
    bool? isEditable,
    bool? isDeletable,
    Map<BottomNavIconGalleryTab, BottomNavIconSet>? items,
  }) {
    return BottomNavIconGallery(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isEditable: isEditable ?? this.isEditable,
      isDeletable: isDeletable ?? this.isDeletable,
      items: items ?? this.items,
    );
  }

  BottomNavIconGallery copyWithItem(
    BottomNavIconGalleryTab tab,
    BottomNavIconSet item,
  ) {
    return copyWith(
      items: Map<BottomNavIconGalleryTab, BottomNavIconSet>.unmodifiable({
        ...items,
        tab: item,
      }),
    );
  }

  static DateTime _readDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim() ?? '';
    if (raw.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid required field: $key');
    }
    return parsed;
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! bool) {
      throw FormatException('Missing required field: $key');
    }
    return raw;
  }
}
