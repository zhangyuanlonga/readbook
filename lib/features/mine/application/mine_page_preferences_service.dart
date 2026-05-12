import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MinePageStartupDestination { home, bookshelf }

extension MinePageStartupDestinationX on MinePageStartupDestination {
  String get label {
    return switch (this) {
      MinePageStartupDestination.home => '首页',
      MinePageStartupDestination.bookshelf => '书架',
    };
  }

  String get location {
    return switch (this) {
      MinePageStartupDestination.home => '/home',
      MinePageStartupDestination.bookshelf => '/bookshelf',
    };
  }
}

enum MinePageItemId {
  profileCard,
  membershipCenter,
  sync,
  inspiration,
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
  sourceManagement,
  cacheManagement,
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
    sectionTitle: '顶部区域',
    subtitle: '会员入口，暂不支持隐藏',
    configurable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.sync,
    title: '同步',
    sectionTitle: '顶部区域',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.inspiration,
    title: '灵感',
    sectionTitle: '顶部区域',
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
  ),
  MinePageItemDefinition(
    id: MinePageItemId.categoryManagement,
    title: '分类管理',
    sectionTitle: '数据',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.fontManagement,
    title: '字体管理',
    sectionTitle: '数据',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.systemSettings,
    title: '系统',
    sectionTitle: '数据',
    displayable: false,
  ),
  MinePageItemDefinition(
    id: MinePageItemId.sourceManagement,
    title: '书源管理',
    sectionTitle: '数据',
  ),
  MinePageItemDefinition(
    id: MinePageItemId.cacheManagement,
    title: '存储管理',
    sectionTitle: '数据',
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

  static const String _hiddenItemIdsKey = 'mine.page.hiddenItems';
  static const String _startupDestinationKey = 'app.startup.destination';

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
    await prefs.setStringList(_hiddenItemIdsKey, hiddenIds);
  }

  Future<MinePageStartupDestination> loadStartupDestination() async {
    final prefs = await _preferencesFuture;
    return readStartupDestination(prefs);
  }

  Future<void> saveStartupDestination(
    MinePageStartupDestination destination,
  ) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_startupDestinationKey, destination.name);
  }

  static MinePageVisibilityState readVisibilityState(SharedPreferences prefs) {
    final rawIds = prefs.getStringList(_hiddenItemIdsKey) ?? const <String>[];
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
    return _startupDestinationFromRaw(prefs.getString(_startupDestinationKey));
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
      _ => MinePageStartupDestination.home,
    };
  }
}
