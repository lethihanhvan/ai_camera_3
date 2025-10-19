import 'dart:convert';
import 'dart:io';

import 'package:ai_camera/utils/face_utils.dart';
import 'package:ai_camera/views/camera_screen.dart';
import 'package:ai_camera/views/face_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;
import 'FaceImageDTO.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

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
  // String? _imagePath;
  // List<Rect>? _faceRects;
  // int? _imageWidth;
  // int? _imageHeight;

  bool _isLoading = true;

  List<FaceImageDTO> _faceImages = [];


  var interpreter;
  late File jsonFile;
  dynamic data = {};
  late List e1;
  double threshold = 1.0;
  late Directory tempDir;
  // Future<void> _openCamera() async {
  //   // Push CameraScreen and wait for the captured photo path
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (_) => const CameraScreen()),
  //   );
  //
  //   if (result != null && mounted) {
  //     setState(() => _imagePath = result);
  //
  //     // Get original image dimensions
  //     final decodedImage = await decodeImageFromList(File(result).readAsBytesSync());
  //     setState(() {
  //       _imageWidth = decodedImage.width;
  //       _imageHeight = decodedImage.height;
  //     });
  //
  //     // Detect faces and get bounding boxes
  //     List<Rect> rects = await detectFaces(result);
  //     setState(() => _faceRects = rects);
  //   }
  // }


  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      setState(() {
        _isLoading = false;
      });
    });
  }


  Future loadModel() async {
    try {
      // load file tan.txt from assets
      // String test = await rootBundle.loadString('assets/tan.txt');

      // Load model bytes from asset
      final dataModelFile = await rootBundle.load('assets/mobilefacenet.tflite');

      // Write them to a temporary file
      final tempDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${tempDir.path}/mobilefacenet.tflite');
      await modelFile.writeAsBytes(
        dataModelFile.buffer.asUint8List(dataModelFile.offsetInBytes, dataModelFile.lengthInBytes),
        flush: true,
      );

      // Load interpreter from file path
      // interpreter = await Interpreter.fromFile(modelFile);


      // final interpreter1 = await Interpreter.fromAsset('mobilefacenet.tflite');


      final gpuDelegateV2 = tfl.GpuDelegateV2(
          options: tfl.GpuDelegateOptionsV2());

      var interpreterOptions = tfl.InterpreterOptions()
        ..addDelegate(gpuDelegateV2);
      interpreter = await tfl.Interpreter.fromFile(modelFile,
          options: interpreterOptions);


      // sync json file emb.json from assets to temp directory
      String _embPath = tempDir.path + '/emb.json';
      jsonFile = new File(_embPath);
      if (jsonFile.existsSync()) data = json.decode(jsonFile.readAsStringSync());

    } on Exception {
      debugPrint('Failed to load model.');
    }
  }

  String _recog(imglib.Image img) {
    // Convert image to Float32List input
    var input = imageToByteListFloat32(img, 112, 128, 128);
    // Reshape input for TFLite
    var inputTensor = input.reshape([1, 112, 112, 3]);
    // Prepare output buffer
    var output = List.filled(192, 0.0).reshape([1, 192]);
    // Run inference
    interpreter.run(inputTensor, output);
    // Flatten output
    var embedding = List<double>.from(output[0]);
    e1 = embedding;
    return compare(e1).toUpperCase();
  }

  String compare(List currEmb) {
    if (data.length == 0) return "No Face saved";
    double minDist = 999;
    double currDist = 0.0;
    String predRes = "NOT RECOGNIZED";
    for (String label in data.keys) {
      currDist = euclideanDistance(data[label], currEmb);
      if (currDist <= threshold && currDist < minDist) {
        minDist = currDist;
        predRes = label;
      }
    }
    print(minDist.toString() + " " + predRes);
    return predRes;
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
      final tempDir = await getTemporaryDirectory();
      for (var asset in result) {
        final file = await asset.file;
        if (file != null) {
          final imagePath = file.path;
          final decodedImage = await decodeImageFromList(file.readAsBytesSync());
          final imageWidth = decodedImage.width;
          final imageHeight = decodedImage.height;
          List<Rect> rects = await detectFaces(imagePath);
          List<imglib.Image> faceCrops = [];
          imglib.Image convertedImage = imglib.decodeImage(file.readAsBytesSync())!;
          for (var rect in rects) {
            double x, y, w, h;

            x = (rect.left - 10);
            y = (rect.top - 10);
            w = (rect.width + 20);
            h = (rect.height + 20);

            imglib.Image croppedImage = imglib.copyCrop(
                convertedImage, x: x.round(), y: y.round(),width:  w.round(), height:  h.round());
            faceCrops.add(croppedImage);

            // save cropped image for debugging
            // final croppedFile = File('${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png');
            // await croppedFile.writeAsBytes(imglib.encodePng(croppedImage));
            // debugPrint("Cropped face saved at: " + croppedFile.path);

            String res = _recog(croppedImage);
            debugPrint("Recognition Result: " + res);
          }

          faceImages.add(FaceImageDTO(
            imagePath: imagePath,
            faceRects: rects,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            faceImages: faceCrops
          ));
        }
      }
    }

    setState(() {
      _faceImages = faceImages;
    });

  }

  @override
  Widget build(BuildContext context) {
    final displayWidth = MediaQuery.of(context).size.width;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera Capture Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading model, please wait...'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Capture Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // if (_imagePath != null && _imageWidth != null && _imageHeight != null)
            //   FaceImagePreview(
            //     imagePath: _imagePath!,
            //     faceRects: _faceRects ?? [],
            //     imageWidth: _imageWidth!,
            //     imageHeight: _imageHeight!,
            //   )
            // else
            //   const Text('No image captured'),

            if (_faceImages.isNotEmpty)
              Column(
                children: [
                  ..._faceImages.map((faceImage) => FaceImagePreview(
                    imagePath: faceImage.imagePath!,
                    faceRects: faceImage.faceRects!,
                    imageWidth: faceImage.imageWidth!,
                    imageHeight: faceImage.imageHeight!,
                  )).toList()
                ],
              ),




            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openImagePickers,
              child: const Text('Pick Images'),
            ),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: _openCamera,
            //   child: const Text('Open Camera'),
            // ),
          ],
        ),
      ),
    );
  }
}
