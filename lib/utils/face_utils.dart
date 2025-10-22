import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as imglib;

Future<List<Rect>> detectFaces(String imagePath) async {
  final inputImage = InputImage.fromFilePath(imagePath);
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      // enableContours: true,
      // enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final List<Face> faces = await faceDetector.processImage(inputImage);
  faceDetector.close();
  // Return bounding boxes for each face
  return faces.map((face) => face.boundingBox).toList();
}


Float32List imageToByteListFloat32(
    imglib.Image image, int inputSize, double mean, double std) {
  // Resize to model input
  final resized = imglib.copyResize(
    image,
    width: inputSize,
    height: inputSize,
  );

  final Float32List buffer = Float32List(inputSize * inputSize * 3);
  int pixelIndex = 0;

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = resized.getPixel(x, y);

      // In v4, getPixel() returns a Pixel object
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      buffer[pixelIndex++] = (r - mean) / std;
      buffer[pixelIndex++] = (g - mean) / std;
      buffer[pixelIndex++] = (b - mean) / std;
    }
  }

  return buffer;
}

double euclideanDistance(List e1, List e2) {
  double sum = 0.0;
  for (int i = 0; i < e1.length; i++) {
    sum += pow((e1[i] - e2[i]), 2);
  }
  return sqrt(sum);
}
double cosineDistance(List<double> a, List<double> b) {
  double dot = 0.0;
  double normA = 0.0;
  double normB = 0.0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return 1 - (dot / (math.sqrt(normA) * math.sqrt(normB)));
}