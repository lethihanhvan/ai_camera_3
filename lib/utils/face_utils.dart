import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';

Future<List<Rect>> detectFaces(String imagePath) async {
  final inputImage = InputImage.fromFilePath(imagePath);
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
    ),
  );

  final List<Face> faces = await faceDetector.processImage(inputImage);
  faceDetector.close();
  // Return bounding boxes for each face
  return faces.map((face) => face.boundingBox).toList();
}
