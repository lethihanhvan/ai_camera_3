

import 'dart:ui';
import 'package:image/image.dart' as imglib;

import 'dto/face_people.dart';

class FaceImageDTO {
  final String? imagePath;
  final List<FacePeople> facePeoples;
  final int? imageWidth;
  final int? imageHeight;
  final List<imglib.Image>? faceImages;

  FaceImageDTO({
    this.imagePath,
    this.facePeoples = const [],
    this.imageWidth,
    this.imageHeight,
    this.faceImages
  });

  // setters for facePeoples and faceImages
  void setFacePeoples(List<FacePeople> peoples) {
    facePeoples.clear();
    facePeoples.addAll(peoples);
  }
}