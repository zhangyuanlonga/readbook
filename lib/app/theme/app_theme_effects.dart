import 'package:ambient_effects_container/ambient_effects_container.dart';

import '../../domain/entities/app_advanced_theme.dart';

const List<AppAdvancedThemeEffect> appAdvancedThemeEffectOptions =
    <AppAdvancedThemeEffect>[
      AppAdvancedThemeEffect.none,
      AppAdvancedThemeEffect.rain,
      AppAdvancedThemeEffect.snow,
      AppAdvancedThemeEffect.leaf,
      AppAdvancedThemeEffect.sakura,
      AppAdvancedThemeEffect.rose,
      AppAdvancedThemeEffect.whitePetal,
      AppAdvancedThemeEffect.wisteria,
      AppAdvancedThemeEffect.firefly,
    ];

String appAdvancedThemeEffectLabel(AppAdvancedThemeEffect effect) {
  return switch (effect) {
    AppAdvancedThemeEffect.none => '关闭',
    AppAdvancedThemeEffect.rain => '雨',
    AppAdvancedThemeEffect.snow => '雪',
    AppAdvancedThemeEffect.leaf => '落叶',
    AppAdvancedThemeEffect.sakura => '樱花',
    AppAdvancedThemeEffect.rose => '玫瑰花瓣',
    AppAdvancedThemeEffect.whitePetal => '白色花瓣',
    AppAdvancedThemeEffect.wisteria => '紫藤',
    AppAdvancedThemeEffect.firefly => '萤火',
  };
}

String appAdvancedThemeEffectStatus(AppAdvancedThemeEffect effect) {
  if (effect == AppAdvancedThemeEffect.none) {
    return '未设置';
  }
  return appAdvancedThemeEffectLabel(effect);
}

AmbientEffectConfig? appAmbientEffectConfigFor(
  AppAdvancedThemeEffect effect, {
  bool preview = false,
}) {
  return switch (effect) {
    AppAdvancedThemeEffect.none => null,
    AppAdvancedThemeEffect.rain =>
      preview ? const RainEffect.light() : const RainEffect.medium(),
    AppAdvancedThemeEffect.snow =>
      preview ? const SnowEffect.light() : const SnowEffect.medium(),
    AppAdvancedThemeEffect.leaf =>
      preview ? const LeafEffect.light() : const LeafEffect.medium(),
    AppAdvancedThemeEffect.sakura =>
      preview ? const SakuraEffect.light() : const SakuraEffect.medium(),
    AppAdvancedThemeEffect.rose =>
      preview
          ? const PetalEffect.light(style: PetalStyle.rose)
          : const PetalEffect.medium(style: PetalStyle.rose),
    AppAdvancedThemeEffect.whitePetal =>
      preview
          ? const PetalEffect.light(style: PetalStyle.white)
          : const PetalEffect.medium(style: PetalStyle.white),
    AppAdvancedThemeEffect.wisteria =>
      preview
          ? const PetalEffect.light(style: PetalStyle.wisteria)
          : const PetalEffect.medium(style: PetalStyle.wisteria),
    AppAdvancedThemeEffect.firefly =>
      preview ? const FireflyEffect.light() : const FireflyEffect.medium(),
  };
}
