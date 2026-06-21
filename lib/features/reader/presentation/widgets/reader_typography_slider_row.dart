import 'package:flutter/material.dart';

typedef ReaderPreviewAwareSliderBuilder =
    Widget Function({
      required double min,
      required double max,
      required int? divisions,
      required double value,
      required ValueChanged<double>? onChanged,
      ValueChanged<double>? onChangeEnd,
      String? label,
    });

/// 阅读器设置面板里的排版滑杆行。
///
/// 这个 widget 只负责展示标签、加减按钮、滑杆和值文本，不读取阅读器状态，
/// 也不直接持久化配置。调用方把预览感知滑杆 builder 传进来，保留原来的
/// 拖动预览 / 延迟恢复逻辑，同时让超大 settings sheet 少承担一块 UI 细节。
class ReaderTypographySliderRow extends StatefulWidget {
  const ReaderTypographySliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    required this.sliderBuilder,
    this.compactSheetScale = 1,
    this.step = 1,
    this.showValueLabel = true,
    this.deferChangedUntilEnd = false,
    this.valueLabelBuilder,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final double compactSheetScale;
  final double step;
  final bool showValueLabel;
  final bool deferChangedUntilEnd;
  final String Function(double value)? valueLabelBuilder;

  @override
  State<ReaderTypographySliderRow> createState() =>
      _ReaderTypographySliderRowState();
}

class _ReaderTypographySliderRowState extends State<ReaderTypographySliderRow> {
  double? _draftValue;
  bool _isDragging = false;

  double get _safeValue =>
      (_draftValue ?? widget.value).clamp(widget.min, widget.max).toDouble();

  String get _safeValueLabel =>
      widget.valueLabelBuilder?.call(_safeValue) ?? widget.valueLabel;

  double _scale(double value) => value * widget.compactSheetScale;

  @override
  void didUpdateWidget(covariant ReaderTypographySliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != oldWidget.value) {
      _draftValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeValue = _safeValue;
    final safeValueLabel = _safeValueLabel;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    void nudge(double delta) {
      final next = (safeValue + delta).clamp(widget.min, widget.max).toDouble();
      setState(() {
        _isDragging = false;
        _draftValue = null;
      });
      widget.onChanged(next);
    }

    void handleSliderChanged(double next) {
      if (!widget.deferChangedUntilEnd) {
        widget.onChanged(next);
        return;
      }
      setState(() {
        _isDragging = true;
        _draftValue = next;
      });
    }

    void handleSliderChangeEnd(double next) {
      if (!widget.deferChangedUntilEnd) {
        return;
      }
      setState(() {
        _isDragging = false;
        _draftValue = next;
      });
      widget.onChanged(next);
    }

    Widget controls({required bool stacked}) {
      return Row(
        children: [
          if (!stacked)
            SizedBox(
              width: _scale(28),
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                      widget.compactSheetScale *
                      0.95,
                ),
              ),
            ),
          if (stacked) const SizedBox.shrink(),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(
              minWidth: _scale(28),
              minHeight: _scale(28),
            ),
            onPressed: () => nudge(-widget.step),
            icon: Icon(Icons.remove_rounded, size: _scale(16)),
          ),
          Expanded(
            child: widget.sliderBuilder(
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              value: safeValue,
              onChanged: handleSliderChanged,
              onChangeEnd: handleSliderChangeEnd,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(
              minWidth: _scale(28),
              minHeight: _scale(28),
            ),
            onPressed: () => nudge(widget.step),
            icon: Icon(Icons.add_rounded, size: _scale(16)),
          ),
          if (widget.showValueLabel && !stacked)
            SizedBox(
              width: _scale(54),
              child: Text(
                safeValueLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                      widget.compactSheetScale *
                      0.94,
                ),
              ),
            ),
        ],
      );
    }

    Widget stackedLabel() {
      return Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize:
                    (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                    widget.compactSheetScale *
                    0.95,
              ),
            ),
          ),
          if (widget.showValueLabel)
            Text(
              safeValueLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize:
                    (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                    widget.compactSheetScale *
                    0.94,
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: _scale(0.5)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = textScale >= 1.2 && constraints.maxWidth < 360;
          if (!stacked) {
            return controls(stacked: false);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stackedLabel(),
              SizedBox(height: _scale(2)),
              controls(stacked: true),
            ],
          );
        },
      ),
    );
  }
}
