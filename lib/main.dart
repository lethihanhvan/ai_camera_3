import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ai_camera/utils/face_utils.dart';
import 'package:ai_camera/views/exported_files_page.dart';
import 'package:ai_camera/views/face_image_preview.dart';
import 'package:ai_camera/views/import_export_page.dart';
import 'package:ai_camera/views/manage_people_page.dart';
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
      title: 'Nhận dạng điểm danh AI',
      // localizationsDelegates: const [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      // supportedLocales: const [
      //   Locale('en', ''), // English, no country code
      //   Locale('vi', ''), // Vietnamese, no country code
      // ],
      // locale: const Locale('vi', ''),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
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
  bool _isReloadingDb = false;

  List<FaceImageDTO> _faceImages = [];
  List<People> _dbPeoples = [];
  String timeKey = DateTime.now().millisecondsSinceEpoch.toString();


  var interpreter;
  late File jsonFile;
  dynamic data = {};
  late List e1;
  // double threshold = 1.0;
  double threshold = 0.4;
  int minSizeImage = 112;
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
    setState(() {
      _isReloadingDb = true;
    });

    try {
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
                    double x, y, w, h;
                    var rect = facePeople.faceRect;

                    x = (rect.left - 10);
                    y = (rect.top - 10);
                    w = (rect.width + 20);
                    h = (rect.height + 20);


                    imglib.Image croppedImage = imglib.copyCrop(
                        convertedImage, x: x.round(), y: y.round(), width: w.round(), height: h.round());

                    List<double> embeddingData = buildEmbeddingData(croppedImage);
                    String? dbId = detectPeopleByDBAndEmbedding(croppedImage, embeddingData);
                    facePeople.dbId = dbId;
                    return facePeople;
                  }).toList()
              );
              return faceImageItem;
            }).toList();
            _isReloadingDb = false;
          });
        });
      });
    } catch (e) {
      debugPrint('Error reloading DB peoples: $e');
      setState(() {
        _isReloadingDb = false;
      });
    }
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

      String fileName = "mobilefacenet";
      // String fileName = "face_detect_v1";
      // Load model bytes from asset
      final dataModelFile = await rootBundle.load('assets/${fileName}.tflite');

      // Write them to a temporary file
      final tempDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${tempDir.path}/${fileName}.tflite');
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

  // List<double> buildEmbeddingData(imglib.Image img) {
  //   var input = imageToByteListFloat32(img, 112, 128, 128);
  //   // Reshape input for TFLite
  //   var inputTensor = input.reshape([1, 112, 112, 3]);
  //   // Prepare output buffer
  //   var output = List.filled(192, 0.0).reshape([1, 192]);
  //   // Run inference
  //   interpreter.run(inputTensor, output);
  //   // Flatten output
  //   var embedding = List<double>.from(output[0]);
  //   return embedding;
  // }

  List<double> normalizeEmbedding(List<double> embedding) {
    double sum = embedding.fold(0.0, (a, b) => a + b * b);
    double norm = sqrt(sum);
    return embedding.map((e) => e / norm).toList();
  }

  List<double> buildEmbeddingData(imglib.Image img) {
    var input = imageToByteListFloat32(img, 112, 128, 128);
    var inputTensor = input.reshape([1, 112, 112, 3]);
    var output = List.filled(192, 0.0).reshape([1, 192]);
    interpreter.run(inputTensor, output);
    var embedding = List<double>.from(output[0]);
    return normalizeEmbedding(embedding); // Add normalization
  }

  String? compareWithDB(List currEmb) {
    if (_dbPeoples.isEmpty) return null;

    final Map<String, double> mapMatchPeople = {};

    // Collect the smallest distance for each person (across their embeddings)
    for (People person in _dbPeoples) {
      for (List<double> dbEmb in person.embeddings) {
        var index = person.embeddings.indexOf(dbEmb);
        // final double currDist = euclideanDistance(dbEmb, currEmb);
        final double currDist = cosineDistance(dbEmb, currEmb);
        if (currDist <= threshold) {
          final prev = mapMatchPeople[person.id];
          if (prev == null || currDist < prev) {
            mapMatchPeople[person.id] = currDist;
            print("Compare ${person.name} dist: $currDist index: $index" );
            // < threshold -> cunfg nguoi -> thoat
            // continue;
          }
        }
      }
    }

    if (mapMatchPeople.isEmpty) return null;

    // Find the entry with the minimum distance
    final bestEntry = mapMatchPeople.entries.reduce((a, b) => a.value <= b.value ? a : b);

    // Only return if confidence is high enough (distance < 0.25 = very confident)
    // if (bestEntry.value > 0.25) return null;

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

    setState(() {
      _isReloadingDb = true;
    });

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
            if (rect.width < minSizeImage || rect.height < minSizeImage) continue;

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
      _isReloadingDb = false;
    });

  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Đang khởi tạo mô hình AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vui lòng đợi...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }


    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.face_retouching_natural,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Nhận dạng điểm danh AI',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                tooltip: 'Cài đặt',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => SafeArea(child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text(
                                  'Cài đặt',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.people),
                            title: const Text('Quản lý học sinh'),
                            subtitle: const Text('Xem, sửa và xóa học sinh'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ManagePeoplePage()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.import_export),
                            title: const Text('Nhập/Xuất dữ liệu'),
                            subtitle: const Text('Sao lưu và khôi phục cơ sở dữ liệu'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ImportExportPage()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: const Text('Tệp báo cáo'),
                            subtitle: const Text('Xem các báo cáo đã xuất'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ExportedFilesPage()),
                              );
                            },
                          ),
                        ],
                      ),
                    )),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Stats header
                  if (_faceImages.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.photo_library,
                            label: 'Ảnh',
                            value: '${_faceImages.length}',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            icon: Icons.face,
                            label: 'Khuôn mặt',
                            value: '${_faceImages.fold<int>(0, (sum, img) => sum + img.facePeoples.length)}',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            icon: Icons.person,
                            label: 'học sinh',
                            value: '${_dbPeoples.length}',
                          ),
                        ],
                      ),
                    ),

                  // Scrollable area for previews
                  Expanded(
                    child: _faceImages.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Không có ảnh nào được chọn',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhấn "Chọn ảnh" để bắt đầu',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      key: Key('main_column_$timeKey'),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _faceImages.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: FaceImagePreview(
                            imagePath: _faceImages[i].imagePath!,
                            facePeoples: _faceImages[i].facePeoples,
                            imageWidth: _faceImages[i].imageWidth!,
                            imageHeight: _faceImages[i].imageHeight!,
                            faceImages: _faceImages[i].faceImages,
                            onAddPeopleCallback: () async {
                              await reloadDbPeoples();
                            },
                            onDelete: () async {
                              setState(() {
                                if (i >= 0 && i < _faceImages.length) {
                                  _faceImages.removeAt(i);
                                }
                              });
                              await reloadDbPeoples();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Đã xóa ảnh'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _openImagePickers,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text(
                                'Chọn ảnh',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                            ),
                          ),
                          if (_faceImages.isNotEmpty) const SizedBox(height: 12),
                          if (_faceImages.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final mapData = listAndShowFoundPeople();
                                  final found = mapData["people"] as List<People>;
                                  final List<String> imagePaths = mapData["imagesPaths"] as List<String>;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FoundPeoplePage(
                                        people: found,
                                        imagesPaths: imagePaths,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.people_alt),
                                label: const Text(
                                  'Hiển thị học sinh đã tìm thấy',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isReloadingDb)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
