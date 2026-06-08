import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/preferences/preference_key.dart';

enum MinePageStartupDestination { bookshelf }

enum MinePageLayoutMode { grid, list }

extension MinePageStartupDestinationX on MinePageStartupDestination {
  String get label {
    return switch (this) {
      MinePageStartupDestination.bookshelf => '书架',
    };
  }

  String get location {
    return switch (this) {
      MinePageStartupDestination.bookshelf => '/bookshelf',
    };
  }
}

enum MinePageItemId {
  profileCard,
  membershipCenter,
  inspiration,
  bookSources,
  appAppearance,
  advancedTheme,
  bottomNavGallery,
  coverGallery,
  appBackground,
  readerBackground,
  launchGallery,
  tagManagement,
  categoryManagement,
  fontManagement,
  systemSettings,
  feedback,
  officialGroup,
  checkUpdate,
  about,
}

class MinePageItemDefinition {
  const MinePageItemDefinition({
    required this.id,
    required this.title,
    required this.sectionTitle,
    this.subtitle,
    this.configurable = true,
    this.displayable = true,
  });

  final MinePageItemId id;
  final String title;
  final String sectionTitle;
  final String? subtitle;
  final bool configurable;
  final bool displayable;
}

const List<MinePageItemDefinition> minePageItemDefinitions = [
  MinePageItemDefinition(
    id: MinePageItemId.profileCard,
    title: '顶部用户卡片',
    sectionTitle: '顶部区域',
    subtitle: '账号信息入口，暂不支持隐藏',
    configurable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.membershipCenter,
    title: '高级会员',
    sectionTitle: '数据',
    displayable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.inspiration,
    title: '灵感笔记',
    sectionTitle: '数据',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.bookSources,
    title: '我的书源',
    sectionTitle: '数据',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.appAppearance,
    title: '应用外观',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.advancedTheme,
    title: '高级主题',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.bottomNavGallery,
    title: '底栏图集',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.coverGallery,
    title: '封面图集',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.appBackground,
    title: '应用背景',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.readerBackground,
    title: '阅读背景',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.launchGallery,
    title: '启动图集',
    sectionTitle: '外观',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.tagManagement,
    title: '标签管理',
    sectionTitle: '数据',
    configurable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.categoryManagement,
    title: '分类管理',
    sectionTitle: '数据',
    configurable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.fontManagement,
    title: '字体管理',
    sectionTitle: '数据',
    configurable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.systemSettings,
    title: '系统',
    sectionTitle: '数据',
    displayable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.feedback,
    title: '问题反馈',
    sectionTitle: '其他',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.officialGroup,
    title: '官方 Q 群',
    sectionTitle: '其他',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.checkUpdate,
    title: '检查更新',
    sectionTitle: '其他',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.about,
    title: '关于我们',
    sectionTitle: '其他',
  ),
];

final Map<MinePageItemId, MinePageItemDefinition> _minePageItemDefinitionMap = {
  for (final definition in minePageItemDefinitions) definition.id: definition,
};

MinePageItemDefinition minePageItemDefinitionFor(MinePageItemId id) {
  return _minePageItemDefinitionMap[id]!;
}

List<MinePageItemDefinition> get configurableMinePageItemDefinitions {
  return minePageItemDefinitions
      .where((definition) => definition.displayable && definition.configurable)
      .toList(growable: false);
}

List<MinePageItemDefinition> get displayableMinePageItemDefinitions {
  return minePageItemDefinitions
      .where((definition) => definition.displayable)
      .toList(growable: false);
}

class MinePageVisibilityState {
  factory MinePageVisibilityState({
    Iterable<MinePageItemId> hiddenItemIds = const <MinePageItemId>[],
  }) {
    final normalized =
        hiddenItemIds.toSet().toList()
          ..sort((left, right) => left.index.compareTo(right.index));
    return MinePageVisibilityState._(List.unmodifiable(normalized));
  }

  const MinePageVisibilityState._(this.hiddenItemIds);

  final List<MinePageItemId> hiddenItemIds;

  bool isVisible(MinePageItemId itemId) {
    final definition = minePageItemDefinitionFor(itemId);
    if (!definition.displayable) {
      return false;
    }
    if (kIsWeb && itemId == MinePageItemId.checkUpdate) {
      return false;
    }
    if (!definition.configurable) {
      return true;
    }
    return !hiddenItemIds.contains(itemId);
  }

  MinePageVisibilityState copyWithVisibility(
    MinePageItemId itemId,
    bool visible,
  ) {
    final definition = minePageItemDefinitionFor(itemId);
    if (!definition.displayable) {
      return this;
    }
    if (!definition.configurable) {
      return this;
    }
    final nextHidden = hiddenItemIds.toSet();
    if (visible) {
      nextHidden.remove(itemId);
    } else {
      nextHidden.add(itemId);
    }
    return MinePageVisibilityState(hiddenItemIds: nextHidden);
  }

  @override
  bool operator ==(Object other) {
    return other is MinePageVisibilityState &&
        listEquals(other.hiddenItemIds, hiddenItemIds);
  }

  @override
  int get hashCode => Object.hashAll(hiddenItemIds);
}

class MinePagePreferencesService {
  MinePagePreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future<SharedPreferences>.value(preferences);

  static const String hiddenItemIdsPreferenceKey = 'mine.page.hiddenItems';
  static const String startupDestinationPreferenceKey =
      'app.startup.destination';
  static const String layoutModePreferenceKey = 'mine.page.layoutMode';

  static const PreferenceKey<List<String>> hiddenItemIdsPreference =
      PreferenceKey<List<String>>(
        hiddenItemIdsPreferenceKey,
        defaultValue: <String>[],
      );
  static const PreferenceKey<String> startupDestinationPreference =
      PreferenceKey<String>(
        startupDestinationPreferenceKey,
        defaultValue: 'bookshelf',
      );
  static const PreferenceKey<String> layoutModePreference =
      PreferenceKey<String>(layoutModePreferenceKey);

  final Future<SharedPreferences> _preferencesFuture;

  Future<MinePageVisibilityState> loadVisibilityState() async {
    final prefs = await _preferencesFuture;
    return readVisibilityState(prefs);
  }

  Future<void> saveVisibilityState(MinePageVisibilityState state) async {
    final prefs = await _preferencesFuture;
    final hiddenIds = state.hiddenItemIds
        .where((itemId) {
          final definition = minePageItemDefinitionFor(itemId);
          return definition.displayable && definition.configurable;
        })
        .map((itemId) => itemId.name)
        .toList(growable: false);
    await _writeStringList(prefs, hiddenItemIdsPreference, hiddenIds);
  }

  Future<MinePageStartupDestination> loadStartupDestination() async {
    final prefs = await _preferencesFuture;
    return readStartupDestination(prefs);
  }

  Future<void> saveStartupDestination(
    MinePageStartupDestination destination,
  ) async {
    final prefs = await _preferencesFuture;
    await _writeString(prefs, startupDestinationPreference, destination.name);
  }

  Future<MinePageLayoutMode?> loadLayoutMode() async {
    final prefs = await _preferencesFuture;
    return readLayoutMode(prefs);
  }

  Future<void> saveLayoutMode(MinePageLayoutMode mode) async {
    final prefs = await _preferencesFuture;
    await _writeString(prefs, layoutModePreference, mode.name);
  }

  static MinePageVisibilityState readVisibilityState(SharedPreferences prefs) {
    final rawIds = _readStringList(prefs, hiddenItemIdsPreference);
    final hiddenIds = rawIds
        .map(_itemIdFromRaw)
        .whereType<MinePageItemId>()
        .where((itemId) {
          final definition = minePageItemDefinitionFor(itemId);
          return definition.displayable && definition.configurable;
        })
        .toList(growable: false);
    return MinePageVisibilityState(hiddenItemIds: hiddenIds);
  }

  static MinePageStartupDestination readStartupDestination(
    SharedPreferences prefs,
  ) {
    return _startupDestinationFromRaw(
      _readString(prefs, startupDestinationPreference),
    );
  }

  static MinePageLayoutMode? readLayoutMode(SharedPreferences prefs) {
    return _layoutModeFromRaw(_readString(prefs, layoutModePreference));
  }

  static MinePageItemId? _itemIdFromRaw(String raw) {
    for (final value in MinePageItemId.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }

  static MinePageStartupDestination _startupDestinationFromRaw(String? raw) {
    return switch (raw) {
      'bookshelf' => MinePageStartupDestination.bookshelf,
      // 首页入口已从主导航和路由中移除，旧配置统一落到当前第一个主入口：书架。
      _ => MinePageStartupDestination.bookshelf,
    };
  }

  static MinePageLayoutMode? _layoutModeFromRaw(String? raw) {
    return switch (raw) {
      'grid' => MinePageLayoutMode.grid,
      'list' => MinePageLayoutMode.list,
      _ => null,
    };
  }

  static String? _readString(
    SharedPreferences prefs,
    PreferenceKey<String> key,
  ) {
    return prefs.getString(key.name) ?? key.defaultValue;
  }

  static List<String> _readStringList(
    SharedPreferences prefs,
    PreferenceKey<List<String>> key,
  ) {
    return prefs.getStringList(key.name) ??
        key.defaultValue ??
        const <String>[];
  }

  static Future<void> _writeString(
    SharedPreferences prefs,
    PreferenceKey<String> key,
    String value,
  ) {
    return prefs.setString(key.name, value);
  }

  static Future<void> _writeStringList(
    SharedPreferences prefs,
    PreferenceKey<List<String>> key,
    List<String> value,
  ) {
    return prefs.setStringList(key.name, value);
  }
}
