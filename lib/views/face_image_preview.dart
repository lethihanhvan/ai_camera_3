import 'dart:io';
import 'package:flutter/material.dart';

class FaceImagePreview extends StatelessWidget {
  final String imagePath;
  final List<Rect> faceRects;
  final int imageWidth;
  final int imageHeight;

  const FaceImagePreview({
    Key? key,
    required this.imagePath,
    required this.faceRects,
    required this.imageWidth,
    required this.imageHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        SizedBox(
          width: displayWidth,
          child: AspectRatio(
            aspectRatio: imageWidth / imageHeight,
            child: Stack(
              children: [
                Image.file(
                  File(imagePath),
                  width: displayWidth,
                  fit: BoxFit.contain,
                ),
                if (faceRects.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FacePainter(
                        faceRects,
                        imageSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Text('People Detected: ${faceRects.length}'),
      ],
    );
  }
}

class _FacePainter extends CustomPainter {
  final List<Rect> rects;
  final Size imageSize;
  _FacePainter(this.rects, {required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withAlpha(128)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    for (final rect in rects) {
      final scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) => rects != oldDelegate.rects || imageSize != oldDelegate.imageSize;
}

