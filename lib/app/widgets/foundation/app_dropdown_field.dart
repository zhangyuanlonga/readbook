import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';

class AppDropdownOption<T> {
  const AppDropdownOption({
    required this.value,
    required this.label,
    this.labelWidget,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.style,
  });

  final T value;
  final String label;
  final Widget? labelWidget;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool enabled;
  final ButtonStyle? style;
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.labelText,
    this.hintText,
    this.leadingIcon,
    this.width,
    this.menuHeight,
    this.expanded = true,
    this.enabled = true,
    this.isDense = true,
    this.contentPadding,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.menuStyle,
    this.inputDecorationTheme,
  });

  final T? value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?>? onSelected;
  final String? labelText;
  final String? hintText;
  final Widget? leadingIcon;
  final double? width;
  final double? menuHeight;
  final bool expanded;
  final bool enabled;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final MenuStyle? menuStyle;
  final Object? inputDecorationTheme;

  @override
  Widget build(BuildContext context) {
    if (!expanded || width != null) {
      return _buildMenu(context, width);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : null;
        return _buildMenu(context, resolvedWidth);
      },
    );
  }

  Widget _buildMenu(BuildContext context, double? resolvedWidth) {
    final tokens = appComponentThemeTokensOf(context);
    final radius = BorderRadius.circular(tokens.input.radius);
    final defaultDecorationTheme = InputDecorationTheme(
      isDense: isDense,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(borderRadius: radius),
      disabledBorder: OutlineInputBorder(borderRadius: radius),
      focusedBorder: OutlineInputBorder(borderRadius: radius),
    );

    return DropdownMenu<T>(
      enabled: enabled && onSelected != null,
      width: resolvedWidth,
      menuHeight: menuHeight,
      leadingIcon: leadingIcon,
      label: labelText == null ? null : Text(labelText!),
      hintText: hintText,
      textStyle: textStyle,
      textAlign: textAlign,
      inputDecorationTheme: inputDecorationTheme ?? defaultDecorationTheme,
      menuStyle: menuStyle,
      initialSelection: value,
      onSelected: onSelected,
      selectOnly: true,
      dropdownMenuEntries: options
          .map(
            (option) => DropdownMenuEntry<T>(
              value: option.value,
              label: option.label,
              labelWidget: option.labelWidget,
              leadingIcon: option.leadingIcon,
              trailingIcon: option.trailingIcon,
              enabled: option.enabled,
              style: option.style,
            ),
          )
          .toList(growable: false),
    );
  }
}
