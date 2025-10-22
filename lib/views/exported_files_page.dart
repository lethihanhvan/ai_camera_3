import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExportedFilesPage extends StatefulWidget {
  const ExportedFilesPage({Key? key}) : super(key: key);

  @override
  State<ExportedFilesPage> createState() => _ExportedFilesPageState();
}

class _ExportedFilesPageState extends State<ExportedFilesPage> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) {
      return f.path.endsWith('.xlsx');
    }).toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exported Excel Files')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('No exported Excel files found'))
              : SafeArea(child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final file = _files[index];
          final stat = file.statSync();
          final name = file.path.split('/').last;
          final modified = stat.modified;
          return Card(
            child: ListTile(
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Modified: ${modified.toLocal()}'),
              trailing: IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Open/Download',
                onPressed: () => OpenFile.open(file.path),
              ),
              onTap: () => OpenFile.open(file.path),
            ),
          );
        },
      )),
    );
  }
}

