import 'dart:convert';
import 'dart:ui';

class FacePeople {
  String? dbId;
  Rect faceRect;
  List<double> embedding = [];
  String imagePath;

  FacePeople({
    this.dbId,
    required this.faceRect,
    required this.embedding,
    required this.imagePath,
  });
}