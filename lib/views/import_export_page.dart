import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import '../dto/people.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({Key? key}) : super(key: key);

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  String? _statusMessage;
  bool _hasStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.status;
      final storageStatus = await Permission.storage.status;
      setState(() {
        _hasStoragePermission = manageStatus.isGranted || storageStatus.isGranted;
      });
    } else {
      setState(() {
        _hasStoragePermission = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.import_export,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text(
              'Nhập/Xuất dữ liệu',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.cloud_sync,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quản lý cơ sở dữ liệu',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sao lưu và khôi phục dữ liệu của bạn',
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
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'Xuất tất cả dữ liệu người sang JSON hoặc nhập từ tệp sao lưu. Khi nhập, các bản ghi hiện có sẽ được hợp nhất dựa trên ID.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Export Button
                Container(
                  height: 120,
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _exportToJson,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.upload_file,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Xuất sang JSON',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tạo một tệp sao lưu',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Import Button
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _importFromJson,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.download,
                                color: Theme.of(context).colorScheme.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Nhập từ JSON',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Khôi phục từ bản sao lưu',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Status Message
                if (_isLoading)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),

                if (_statusMessage != null && !_isLoading)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Permission Warning
                if (!_hasStoragePermission)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Yêu cầu quyền truy cập bộ nhớ',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Để xuất tệp, ứng dụng này cần quyền truy cập bộ nhớ.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await openAppSettings();
                              await _checkPermissions();
                            },
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('Mở cài đặt'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(color: Colors.orange.shade700, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportToJson() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      // Request storage permission based on Android version
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Try to request manageExternalStorage for full access
        status = await Permission.manageExternalStorage.request();

        // Fallback to regular storage permission if manage not granted
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.storage.request();
      }

      if (!status.isGranted && !status.isLimited) {
        setState(() {
          _statusMessage = 'Quyền truy cập bộ nhớ bị từ chối. Vui lòng cấp quyền truy cập bộ nhớ trong cài đặt ứng dụng.';
          _isLoading = false;
        });
        return;
      }

      // Get all people from database
      final people = await _dbHelper.getAllPeople();
      
      if (people.isEmpty) {
        setState(() {
          _statusMessage = 'Không có dữ liệu người để xuất';
          _isLoading = false;
        });
        return;
      }

      // Convert to JSON
      final jsonData = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'count': people.length,
        'people': people.map((p) => p.toJson()).toList(),
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Save to Downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'people_export_$timestamp.json';
      final file = File('${directory!.path}/$fileName');
      
      await file.writeAsString(jsonString);

      setState(() {
        _statusMessage = 'Đã xuất thành công ${people.length} người vào:\n${file.path}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất vào: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Xuất thất bại: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importFromJson() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      // Pick a JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _statusMessage = 'Không có tệp nào được chọn';
          _isLoading = false;
        });
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString);

      if (jsonData['people'] == null) {
        setState(() {
          _statusMessage = 'Tệp JSON không hợp lệ: Thiếu khóa "people"';
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> peopleData = jsonData['people'];
      final List<People> peopleToImport = peopleData.map((p) => People.fromJson(p)).toList();

      int createdCount = 0;
      int updatedCount = 0;

      for (final person in peopleToImport) {
        final existing = await _dbHelper.getPeopleById(person.id);
        if (existing != null) {
          // Merge data: Keep existing ID, update other fields
          final updatedPerson = People(
            id: existing.id,
            name: person.name,
            studentId: person.studentId,
            email: person.email,
            classification: person.classification,
            // Merge embeddings and images, avoiding duplicates
            embeddings: [...existing.embeddings, ...person.embeddings]
                .map((e) => jsonEncode(e))
                .toSet()
                .map((e) => (jsonDecode(e) as List).cast<double>())
                .toList(),
            images: [...existing.images, ...person.images]
                .map((img) => base64Encode(img))
                .toSet()
                .map((s) => base64Decode(s))
                .toList(),
          );
          await _dbHelper.updatePeople(updatedPerson);
          updatedCount++;
        } else {
          // Create new person
          await _dbHelper.insertPeople(person);
          createdCount++;
        }
      }

      setState(() {
        _statusMessage = 'Nhập thành công!\n'
            'Đã tạo: $createdCount người mới\n'
            'Đã cập nhật: $updatedCount người hiện có';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Nhập thất bại: $e';
        _isLoading = false;
      });
    }
  }
}
