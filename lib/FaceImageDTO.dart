

import 'dart:ui';

class FaceImageDTO {
  final String? imagePath;
  final List<Rect>? faceRects;
  final int? imageWidth;
  final int? imageHeight;

  FaceImageDTO({
    this.imagePath,
    this.faceRects,
    this.imageWidth,
    this.imageHeight,
  });
}