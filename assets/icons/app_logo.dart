import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;

  const AppLogo({super.key, this.size = 200, this.showBackground = true});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BookLogoPainter(
          primaryColor: colorScheme.primary,
          surfaceColor: colorScheme.surfaceContainerHighest,
          lineColor: colorScheme.primary.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _BookLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color surfaceColor;
  final Color lineColor;

  _BookLogoPainter({
    required this.primaryColor,
    required this.surfaceColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background Circle
    final bgPaint = Paint()..color = primaryColor;
    canvas.drawCircle(center, radius, bgPaint);

    // Book dimensions
    final bookTop = size.height * 0.28;
    final bookBottom = size.height * 0.78;
    final bookLeft = size.width * 0.18;
    final bookRight = size.width * 0.82;
    final spineLeft = size.width * 0.48;
    final spineRight = size.width * 0.52;

    // Book base shadow
    final basePath =
        Path()
          ..moveTo(bookLeft, bookTop)
          ..quadraticBezierTo(
            bookLeft,
            bookTop - 20,
            bookLeft + 30,
            bookTop - 10,
          )
          ..lineTo(spineLeft, bookTop + 5)
          ..lineTo(spineRight, bookTop + 5)
          ..lineTo(bookRight - 30, bookTop - 10)
          ..quadraticBezierTo(bookRight, bookTop - 20, bookRight, bookTop)
          ..lineTo(bookRight, bookBottom)
          ..quadraticBezierTo(
            bookRight,
            bookBottom + 20,
            bookRight - 30,
            bookBottom + 10,
          )
          ..lineTo(spineRight, bookBottom - 5)
          ..lineTo(spineLeft, bookBottom - 5)
          ..lineTo(bookLeft + 30, bookBottom + 10)
          ..quadraticBezierTo(bookLeft, bookBottom + 20, bookLeft, bookBottom)
          ..close();

    // Left page
    final leftPagePath =
        Path()
          ..moveTo(bookLeft + 10, bookTop + 15)
          ..lineTo(bookLeft + 10, bookBottom - 10)
          ..quadraticBezierTo(
            bookLeft + 10,
            bookBottom,
            spineLeft - 5,
            bookBottom - 5,
          )
          ..lineTo(spineLeft - 5, bookTop + 15)
          ..close();

    // Right page
    final rightPagePath =
        Path()
          ..moveTo(spineRight + 5, bookTop + 15)
          ..lineTo(spineRight + 5, bookBottom - 5)
          ..quadraticBezierTo(
            bookRight - 10,
            bookBottom,
            bookRight - 10,
            bookBottom - 10,
          )
          ..lineTo(bookRight - 10, bookTop + 15)
          ..close();

    // Draw pages
    final pagePaint =
        Paint()
          ..color = surfaceColor
          ..style = PaintingStyle.fill;
    canvas.drawPath(leftPagePath, pagePaint);
    canvas.drawPath(rightPagePath, pagePaint);

    // Draw text lines on left page
    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(bookLeft + 25, bookTop + 45),
      Offset(spineLeft - 20, bookTop + 50),
      linePaint,
    );
    canvas.drawLine(
      Offset(bookLeft + 25, bookTop + 70),
      Offset(spineLeft - 30, bookTop + 75),
      linePaint,
    );
    canvas.drawLine(
      Offset(bookLeft + 25, bookTop + 95),
      Offset(spineLeft - 40, bookTop + 100),
      linePaint,
    );
    canvas.drawLine(
      Offset(bookLeft + 25, bookTop + 120),
      Offset(spineLeft - 50, bookTop + 125),
      linePaint,
    );

    // Draw text lines on right page
    canvas.drawLine(
      Offset(spineRight + 20, bookTop + 50),
      Offset(bookRight - 25, bookTop + 45),
      linePaint,
    );
    canvas.drawLine(
      Offset(spineRight + 30, bookTop + 75),
      Offset(bookRight - 25, bookTop + 70),
      linePaint,
    );
    canvas.drawLine(
      Offset(spineRight + 40, bookTop + 100),
      Offset(bookRight - 25, bookTop + 95),
      linePaint,
    );
    canvas.drawLine(
      Offset(spineRight + 50, bookTop + 125),
      Offset(bookRight - 25, bookTop + 120),
      linePaint,
    );

    // Spine
    final spinePaint =
        Paint()
          ..color = const Color(0xFF1D1B20).withOpacity(0.3)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(spineLeft, bookTop + 10),
      Offset(spineLeft, bookBottom - 10),
      spinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
