import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ai_camera/utils/face_utils.dart';
import 'package:ai_camera/views/exported_files_page.dart';
import 'package:ai_camera/views/face_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;
import 'FaceImageDTO.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'views/found_people_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heic_to_png_jpg/heic_to_png_jpg.dart';

import 'db/database_helper.dart';
import 'dto/face_people.dart';
import 'dto/people.dart';

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
  List<People> _dbPeoples = [];
  String timeKey = DateTime.now().millisecondsSinceEpoch.toString();


  var interpreter;
  late File jsonFile;
  dynamic data = {};
  late List e1;
  double threshold = 1.0;
  // double threshold = 0.35;
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

  Future<void> _requestPermissions() async {
    await Permission.photos.request();
    await Permission.videos.request();
  }

  loadDbPeoples() async {
    // Load people from database
    var dbPeoples = await DatabaseHelper().getAllPeople();

    setState(() {
      _dbPeoples = dbPeoples;
      // _faceImages = [..._faceImages];
      // timeKey = DateTime.now().millisecondsSinceEpoch.toString();
    });
  }

  reloadDbPeoples() async {
    // Load people from database
    var dbPeoples = await DatabaseHelper().getAllPeople();

    setState(() {
      _dbPeoples = dbPeoples;

      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          _faceImages = _faceImages.map((faceImageItem) {
            var file = File(faceImageItem.imagePath!);
            imglib.Image convertedImage = imglib.decodeImage(file.readAsBytesSync())!;
            faceImageItem.setFacePeoples(
                faceImageItem.facePeoples.map((facePeople) {
                  // if (facePeople.dbId != null) {
                  //   // already has dbId, skip
                  //   return facePeople;
                  // }
                  double x, y, w, h;
                  var rect = facePeople.faceRect;

                  x = (rect.left - 10);
                  y = (rect.top - 10);
                  w = (rect.width + 20);
                  h = (rect.height + 20);

                  imglib.Image croppedImage = imglib.copyCrop(
                      convertedImage, x: x.round(), y: y.round(),width:  w.round(), height:  h.round());

                  // save cropped image for debugging
                  // final croppedFile = File('${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png');
                  // await croppedFile.writeAsBytes(imglib.encodePng(croppedImage));
                  // debugPrint("Cropped face saved at: " + croppedFile.path);

                  List<double> embeddingData = buildEmbeddingData(croppedImage);
                  String? dbId = detectPeopleByDBAndEmbedding(croppedImage, embeddingData);
                  facePeople.dbId = dbId;
                  return facePeople;
                }).toList()
            );
            return faceImageItem;
          }).toList();
        });
      });
    });


  }



  @override
  void initState() {
    super.initState();
    loadModel().then((value) async {
      await loadDbPeoples();
      await _requestPermissions();
      setState(() {
        _isLoading = false;
      });
    });


  }


  Map listAndShowFoundPeople() {
    debugPrint("Known People in DB:");

    var map = {};
    List<People> foundPeople = [];
    List<String> dbIds = [];
    _faceImages.forEach((faceImage) {
      faceImage.facePeoples.forEach((facePeople) {
        String? dbId = facePeople.dbId;
        if (dbId != null) {
          People? person = _dbPeoples.firstWhere((p) => p.id == dbId);
          if (!foundPeople.any((p) => p.id == person.id)) {
            dbIds.add(dbId);
          }
        }
      });
    });

    foundPeople = _dbPeoples.where((p) => dbIds.contains(p.id)).toList();

    map["people"] = foundPeople;
    map["imagesPaths"] = _faceImages.map((e) => e.imagePath!).toList();
    return map;
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


  String? detectPeopleByDB(imglib.Image img) {
    // Convert image to Float32List input
    List<double> embedding = buildEmbeddingData(img);
    return compareWithDB(embedding);
  }

  String? detectPeopleByDBAndEmbedding(imglib.Image img, List<double> embedding) {
    // Convert image to Float32List input
    return compareWithDB(embedding);
  }

  List<double> buildEmbeddingData(imglib.Image img) {
    var input = imageToByteListFloat32(img, 112, 128, 128);
    // Reshape input for TFLite
    var inputTensor = input.reshape([1, 112, 112, 3]);
    // Prepare output buffer
    var output = List.filled(192, 0.0).reshape([1, 192]);
    // Run inference
    interpreter.run(inputTensor, output);
    // Flatten output
    var embedding = List<double>.from(output[0]);
    return embedding;
  }

  String? compareWithDB(List currEmb) {
    if (_dbPeoples.isEmpty) return null;

    final Map<String, double> mapMatchPeople = {};

    // Collect the smallest distance for each person (across their embeddings)
    for (People person in _dbPeoples) {
      for (List<double> dbEmb in person.embeddings) {
        final double currDist = euclideanDistance(dbEmb, currEmb);
        if (currDist <= threshold) {
          final prev = mapMatchPeople[person.id];
          if (prev == null || currDist < prev) {
            mapMatchPeople[person.id] = currDist;
          }
        }
      }
    }

    if (mapMatchPeople.isEmpty) return null;

    // Find the entry with the minimum distance
    final bestEntry = mapMatchPeople.entries.reduce((a, b) => a.value <= b.value ? a : b);
    debugPrint("Match People Distances: $mapMatchPeople, best: ${bestEntry.key}=${bestEntry.value}");

    return bestEntry.key;
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
        File? file = await asset.file;
        if (file != null) {
          String imagePath = file.path;
          // Check for HEIC extension
          late Uint8List imageData;
          if (imagePath.toLowerCase().endsWith('.heic')) {
            Uint8List heicData = await file.readAsBytes();
            // Convert HEIC to JPG
            imageData = await HeicConverter.convertToJPG(
              heicData: heicData,
              quality: 80,
            );

          } else {
            imageData = file.readAsBytesSync();
          }
          final decodedImage = await decodeImageFromList(imageData);
          final imageWidth = decodedImage.width;
          final imageHeight = decodedImage.height;
          List<Rect> rects = await detectFaces(imagePath);
          List<imglib.Image> faceCrops = [];
          imglib.Image? convertedImage = imglib.decodeImage(imageData);
          if (convertedImage == null) {
            debugPrint('Failed to decode image: $imagePath');
            continue;
          }
          List<FacePeople> facePeoples = [];
          for (var rect in rects) {
            double x, y, w, h;
            x = (rect.left - 10);
            y = (rect.top - 10);
            w = (rect.width + 20);
            h = (rect.height + 20);
            imglib.Image croppedImage = imglib.copyCrop(
                convertedImage, x: x.round(), y: y.round(),width:  w.round(), height:  h.round());
            faceCrops.add(croppedImage);
            List<double> embeddingData = buildEmbeddingData(croppedImage);
            String? peopleId = detectPeopleByDBAndEmbedding(croppedImage, embeddingData);
            debugPrint("Recognition Result: ${peopleId ?? "N/a"}");
            facePeoples.add(FacePeople(
                dbId: peopleId,
                faceRect: rect,
                embedding: embeddingData,
                imagePath: imagePath
            ));
          }

          faceImages.add(FaceImageDTO(
            imagePath: imagePath,
            facePeoples: facePeoples,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            faceImages: faceCrops
          ));
        }
      }
    }

    setState(() {
      _faceImages = [..._faceImages, ...faceImages];
    });

  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('AI Camera Detection')),
      body: SafeArea(
        child: Column(
          children: [
            // scrollable area for previews
            Expanded(
              child: SingleChildScrollView(
                key: Key('main_column_$timeKey'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                          for (var i = 0; i < _faceImages.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 0.0),
                              child: FaceImagePreview(
                                imagePath: _faceImages[i].imagePath!,
                                // faceRects: _faceImages[i].faceRects!,
                                facePeoples: _faceImages[i].facePeoples,
                                imageWidth: _faceImages[i].imageWidth!,
                                imageHeight: _faceImages[i].imageHeight!,
                                faceImages: _faceImages[i].faceImages,
                                onAddPeopleCallback: () async {
                                  await reloadDbPeoples();
                                },
                                onDelete: () async {
                                  // capture current index
                                  final idx = i;
                                  // remove the image entry and refresh state
                                  setState(() {
                                    if (idx >= 0 && idx < _faceImages.length) {
                                      _faceImages.removeAt(idx);
                                    }
                                  });
                                  await reloadDbPeoples();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Image removed')),
                                    );
                                  }
                                },
                              ),
                            ),
                            // gap between items (10px), don't add after last item
                            if (i != _faceImages.length - 1) const SizedBox(height: 10),
                          ],
                        ],
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Text('No images selected'),
                      ),
                    const SizedBox(height: 8),
                    // keep some bottom spacing so last preview isn't obscured by button
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // bottom fixed area for the buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _openImagePickers,
                    child: const SizedBox(
                      width: double.infinity,
                      child: Center(child: Text('Pick Images')),
                    ),
                  ),
                  if (_faceImages.isNotEmpty) const SizedBox(height: 8),
                  if (_faceImages.isNotEmpty)  OutlinedButton(
                    onPressed: () {
                      final mapData = listAndShowFoundPeople();
                      final found = mapData["people"] as List<People>;
                      final List<String> imagePaths = mapData["imagesPaths"] as List<String>;
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FoundPeoplePage(people: found, imagesPaths: imagePaths)));
                    },
                    child: const SizedBox(
                      width: double.infinity,
                      child: Center(child: Text('Show Found People')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ExportedFilesPage()),
                      );
                    },
                    child: const SizedBox(
                      width: double.infinity,
                      child: Center(child: Text('Report Files')),
                    ),
                  ),
                  // optionally keep camera button
                  // const SizedBox(height: 8),
                  // OutlinedButton(
                  //   onPressed: _openCamera,
                  //   child: const SizedBox(
                  //     width: double.infinity,
                  //     child: Center(child: Text('Open Camera')),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
