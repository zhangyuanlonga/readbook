import 'package:flutter/material.dart';

class ReaderInlineFeedback extends StatelessWidget {
  const ReaderInlineFeedback({
    super.key,
    required this.message,
    required this.textColor,
    this.onTap,
  });

  final String message;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AspectRatio(
      aspectRatio: 3 / 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}
