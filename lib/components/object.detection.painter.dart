import 'package:flutter/material.dart';

class ObjectDetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detectedObjects;
  final Size previewSize;
  final Size screenSize;

  ObjectDetectionPainter(
      this.detectedObjects, this.previewSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint boxPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint textBackgroundPaint = Paint()
      ..color = Colors.red.withOpacity(0.7);

    final double scaleX = screenSize.width / previewSize.width;
    final double scaleY = screenSize.height / previewSize.height;

    for (final object in detectedObjects) {
      final rect = Rect.fromLTWH(
        object['left'] * scaleX,
        object['top'] * scaleY,
        (object['right'] - object['left']) * scaleX,
        (object['bottom'] - object['top']) * scaleY,
      );

      // Draw bounding box
      canvas.drawRect(rect, boxPaint);

      // Draw label
      final textSpan = TextSpan(
        text:
            '${object['label']} ${(object['confidence'] * 100).toStringAsFixed(0)}%',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Draw text background
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.top - 18,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        textBackgroundPaint,
      );

      // Draw text
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.top - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
