import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class SemiCircleScoreWidget extends StatelessWidget {
  final String title;
  final double score;

  const SemiCircleScoreWidget({
    super.key,
    required this.title,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = score > 0.8 ? errorBackgroundColor : Colors.orange;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Center vertically
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: secondaryColor,
            fontSize: 10, // Reduced font size
          ),
        ),
        const SizedBox(height: 4), // Reduced spacing
        SizedBox(
          width: 70, // Reduced width
          height: 40, // Reduced height
          child: CustomPaint(
            painter: _SemiCirclePainter(
              score: score,
              progressColor: color,
              backgroundColor: color.withValues(alpha: 0.2),
              strokeWidth: 6, // Reduced stroke width
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0), // Reduced padding
                child: Text(
                  '${(score * 100).toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Reduced font size
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final double score;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _SemiCirclePainter({
    required this.score,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const double startAngle = -math.pi;
    const double sweepAngle = math.pi;

    canvas.drawArc(rect, startAngle, sweepAngle, false, backgroundPaint);
    canvas.drawArc(rect, startAngle, sweepAngle * score, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
