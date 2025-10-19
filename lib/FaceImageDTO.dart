

import 'dart:ui';
import 'package:image/image.dart' as imglib;

class FaceImageDTO {
  final String? imagePath;
  final List<Rect>? faceRects;
  final int? imageWidth;
  final int? imageHeight;
  final List<imglib.Image>? faceImages;

  FaceImageDTO({
    this.imagePath,
    this.faceRects,
    this.imageWidth,
    this.imageHeight,
    this.faceImages
  });
}