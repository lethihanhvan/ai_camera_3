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
        title: const Text('Import/Export People Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Manage People Database',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Export all people data to JSON or import from JSON file. When importing, existing people will be merged based on ID.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Permission Warning
            if (!_hasStoragePermission)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Storage permission required',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To export files, this app needs storage access permission.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await openAppSettings();
                        await _checkPermissions();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Open Settings'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

            // Export Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _exportToJson,
              icon: const Icon(Icons.upload_file),
              label: const Text('Export to JSON'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            
            // Import Button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _importFromJson,
              icon: const Icon(Icons.download),
              label: const Text('Import from JSON'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status Message
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            
            if (_statusMessage != null && !_isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
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
          _statusMessage = 'Storage permission denied. Please grant storage permission in app settings.';
          _isLoading = false;
        });
        return;
      }

      // Get all people from database
      final people = await _dbHelper.getAllPeople();
      
      if (people.isEmpty) {
        setState(() {
          _statusMessage = 'No people data to export';
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
        _statusMessage = 'Successfully exported ${people.length} people to:\n${file.path}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
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
        _statusMessage = 'Export failed: $e';
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
      // Pick JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _statusMessage = 'No file selected';
          _isLoading = false;
        });
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        setState(() {
          _statusMessage = 'Invalid file path';
          _isLoading = false;
        });
        return;
      }

      // Read and parse JSON
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final peopleList = (jsonData['people'] as List<dynamic>)
          .map((e) => People.fromJson(e as Map<String, dynamic>))
          .toList();

      if (peopleList.isEmpty) {
        setState(() {
          _statusMessage = 'No people data found in file';
          _isLoading = false;
        });
        return;
      }

      // Import with migration logic
      int newCount = 0;
      int updatedCount = 0;

      for (final person in peopleList) {
        final existing = await _dbHelper.getPeopleById(person.id);
        
        if (existing != null) {
          // Merge: combine embeddings and images
          final mergedEmbeddings = <List<double>>[
            ...existing.embeddings,
            ...person.embeddings,
          ];
          
          final mergedImages = <Uint8List>[
            ...existing.images,
            ...person.images,
          ];

          final merged = People(
            id: person.id,
            name: person.name,
            classification: person.classification,
            studentId: person.studentId,
            email: person.email,
            embeddings: mergedEmbeddings,
            images: mergedImages,
          );

          await _dbHelper.updatePeople(merged);
          updatedCount++;
        } else {
          // Insert new person
          await _dbHelper.insertPeople(person);
          newCount++;
        }
      }

      setState(() {
        _statusMessage = 'Import completed!\n'
            'New people: $newCount\n'
            'Updated people: $updatedCount\n'
            'Total processed: ${peopleList.length}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $newCount new, updated $updatedCount existing'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Import failed: $e';
        _isLoading = false;
      });
    }
  }
}

