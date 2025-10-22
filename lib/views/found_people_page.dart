import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart';

import '../dto/people.dart';

class FoundPeoplePage extends StatelessWidget {
  final List<People> people;
  final List<String> imagesPaths;

  const FoundPeoplePage({Key? key, required this.people, required this.imagesPaths}) : super(key: key);

  Future<void> _exportExcel(BuildContext context) async {
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No people to export')));
      return;
    }

    try {
      // Build Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['FoundPeople'];
      // Add 'Image' column to header
      final header = ['id', 'name', 'studentId', 'email', 'classification', 'Image'];
      sheet.appendRow(header.map((h) => TextCellValue(h)).toList());

      for (int i = 0; i < people.length; i++) {
        final p = people[i];
        final row = [
          p.id,
          p.name,
          p.studentId ?? '',
          p.email ?? '',
          p.classification ?? '',
          // Instead of embedding, export image path
          (i < imagesPaths.length) ? imagesPaths[i] : '',
        ];
        // Add row data
        sheet.appendRow(row.map((v) => TextCellValue(v.toString())).toList());
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/found_people_$timestamp.xlsx');
      await file.writeAsBytes(excel.encode()!, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
      OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Found People'),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportExcel(context),
          )
        ],
      ),
      body: people.isEmpty
          ? const Center(child: Text('No known people found'))
          : SafeArea(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = people[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Text(p.id, style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (p.studentId != null) Text('Student ID: ${p.studentId}'),
                          // name is non-nullable on People, show directly
                          Text('Name: ${p.name}'),
                          if (p.email != null) Text('Email: ${p.email}'),
                          if (p.classification != null) Text('Classification: ${p.classification}'),
                          const SizedBox(height: 6),
                          Text('Embeddings: ${p.embeddings.length} stored'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
