import 'dart:io';
import 'package:flutter/material.dart';

class FaceImagePreview extends StatefulWidget {
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
  State<FaceImagePreview> createState() => _FaceImagePreviewState();
}

class _FaceImagePreviewState extends State<FaceImagePreview> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    // If currently identity, zoom in. Otherwise reset.
    final matrix = _transformationController.value;
    final isIdentity = matrix == Matrix4.identity();

    if (isIdentity) {
      // Zoom to 2x (clamped by InteractiveViewer maxScale) centered at tap position
      const double zoom = 2.0;
      // Translate so the tapped point stays under the finger after scaling
      final x = -position.dx * (zoom - 1);
      final y = -position.dy * (zoom - 1);
      final target = Matrix4.identity()
        ..translate(x, y)
        ..scale(zoom);
      _transformationController.value = target;
    } else {
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        SizedBox(
          width: displayWidth,
          child: AspectRatio(
            aspectRatio: widget.imageWidth / widget.imageHeight,
            child: ClipRect(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(100),
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      if (widget.faceRects.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FacePainter(
                              widget.faceRects,
                              imageSize: Size(widget.imageWidth.toDouble(), widget.imageHeight.toDouble()),
                            ),
                          ),
                        ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('People Detected: ${widget.faceRects.length}'),
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
      ..color = Colors.red.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
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
