import 'package:flutter/widgets.dart';

class ReaderBackgroundVisualModel {
  const ReaderBackgroundVisualModel({required this.decoration});

  final Decoration decoration;
}

class ReaderBackgroundLayer extends StatelessWidget {
  const ReaderBackgroundLayer({super.key, required this.model});

  final ReaderBackgroundVisualModel model;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: DecoratedBox(decoration: model.decoration));
  }
}
