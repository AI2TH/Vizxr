import 'package:flutter/material.dart';
import '../theme/lens_theme.dart';

class SparklineChart extends StatelessWidget {
  final List<double> dataPoints;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;
  final bool showDots;
  final double height;

  const SparklineChart({
    super.key,
    required this.dataPoints,
    this.lineColor = LensTheme.cyanAccent,
    this.fillColor = const Color(0x3300F2FE),
    this.strokeWidth = 2.0,
    this.showDots = false,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Container(
            height: 1,
            color: lineColor.withOpacity(0.3),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          dataPoints: dataPoints,
          lineColor: lineColor,
          fillColor: fillColor,
          strokeWidth: strokeWidth,
          showDots: showDots,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;
  final bool showDots;

  _SparklinePainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.showDots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final double minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    final double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final double range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final double stepX = size.width / (dataPoints.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final double normalized = (dataPoints[i] - minVal) / range;
      // Invert Y so highest value is at top (y=0) with 4px padding
      final double y = size.height - (normalized * (size.height - 8)) - 4;
      final double x = i * stepX;
      points.add(Offset(x, y));
    }

    // Path for line
    final Path path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final Offset controlPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, controlPoint.dx, controlPoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    // Path for gradient fill below line
    final Path fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw the sparkline curve
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Optional dots on peak and last point
    if (showDots) {
      final Paint dotPaint = Paint()..color = lineColor;
      canvas.drawCircle(points.last, 3.0, dotPaint);

      final Paint ringPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(points.last, 3.0, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}
