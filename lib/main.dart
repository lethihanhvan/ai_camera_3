import 'dart:io';

import 'package:ai_camera/utils/face_utils.dart';
import 'package:ai_camera/views/camera_screen.dart';
import 'package:ai_camera/views/face_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'FaceImageDTO.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _imagePath;
  List<Rect>? _faceRects;
  int? _imageWidth;
  int? _imageHeight;

  List<FaceImageDTO> _faceImages = [];



  Future<void> _openCamera() async {
    // Push CameraScreen and wait for the captured photo path
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    if (result != null && mounted) {
      setState(() => _imagePath = result);

      // Get original image dimensions
      final decodedImage = await decodeImageFromList(File(result).readAsBytesSync());
      setState(() {
        _imageWidth = decodedImage.width;
        _imageHeight = decodedImage.height;
      });

      // Detect faces and get bounding boxes
      List<Rect> rects = await detectFaces(result);
      setState(() => _faceRects = rects);
    }
  }

  Future<void> _openImagePickers() async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
          requestType: RequestType.image, maxAssets: 10
      ),
    );

    List<FaceImageDTO> faceImages = [];
    if (result != null) {
      for (var asset in result) {
        final file = await asset.file;
        if (file != null) {
          final imagePath = file.path;
          final decodedImage = await decodeImageFromList(file.readAsBytesSync());
          final imageWidth = decodedImage.width;
          final imageHeight = decodedImage.height;
          List<Rect> rects = await detectFaces(imagePath);
          faceImages.add(FaceImageDTO(
            imagePath: imagePath,
            faceRects: rects,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          ));
        }
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    final displayWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Capture Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imagePath != null && _imageWidth != null && _imageHeight != null)
              FaceImagePreview(
                imagePath: _imagePath!,
                faceRects: _faceRects ?? [],
                imageWidth: _imageWidth!,
                imageHeight: _imageHeight!,
              )
            else
              const Text('No image captured'),



            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openImagePickers,
              child: const Text('Pick Images'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openCamera,
              child: const Text('Open Camera'),
            ),
          ],
        ),
      ),
    );
  }
}
