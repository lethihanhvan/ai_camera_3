import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../dto/people.dart';
import 'exported_files_page.dart';

class FoundPeoplePage extends StatelessWidget {
  final List<People> people;
  final List<String> imagesPaths;

  const FoundPeoplePage({Key? key, required this.people, required this.imagesPaths}) : super(key: key);

  Future<void> exportExcelWithImages(List<People> people, List<String> imagesPaths) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    // Write header for main sheet
    sheet.getRangeByName('A1').setText('ID');
    sheet.getRangeByName('B1').setText('Name');
    sheet.getRangeByName('C1').setText('Student ID');
    sheet.getRangeByName('D1').setText('Email');
    sheet.getRangeByName('E1').setText('Classification');
    // sheet.getRangeByName('F1').setText('Image Path');

    // Write data to main sheet
    for (int i = 0; i < people.length; i++) {
      final row = i + 2;
      final p = people[i];
      sheet.getRangeByName('A$row').setText(p.id);
      sheet.getRangeByName('B$row').setText(p.name);
      sheet.getRangeByName('C$row').setText(p.studentId ?? '');
      sheet.getRangeByName('D$row').setText(p.email ?? '');
      sheet.getRangeByName('E$row').setText(p.classification ?? '');
      // sheet.getRangeByName('F$row').setText((i < imagesPaths.length) ? imagesPaths[i] : '');
    }

    // Create a new sheet for each image and insert the image
    for (int i = 0; i < imagesPaths.length; i++) {
      final imgPath = imagesPaths[i];
      final imgFile = File(imgPath);
      if (await imgFile.exists()) {
        final imgBytes = await imgFile.readAsBytes();
        // Sheet name: use filename, truncate to 31 chars, remove invalid chars
        String baseName = imgPath.split('/').last;
        baseName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        if (baseName.length > 28) baseName = baseName.substring(0, 28); // leave room for index
        final sheetName = 'Img_${i+1}_$baseName';
        final imgSheet = workbook.worksheets.addWithName(sheetName);
        // imgSheet.getRangeByName('A1').setText('Filename');
        // imgSheet.getRangeByName('A2').setText(imgPath.split('/').last);
        // Insert image at B2
        imgSheet.pictures.addStream(2, 2, imgBytes); // row 2, col 2 (B2)
      }
    }

    // Save workbook
    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    // make filename show readable date and time
    String formattedTimestamp = timestamp.replaceAll('T', '_').split('.').first;
    final file = File('${dir.path}/report_$formattedTimestamp _ $timestamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    OpenFile.open(file.path);
  }

  Future<void> _exportExcel(BuildContext context) async {
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No people to export')));
      return;
    }

    exportExcelWithImages(people, imagesPaths);

    // try {
    //   // Build Excel workbook
    //   final excel = Excel.createExcel();
    //   final sheet = excel['FoundPeople'];
    //   // Add 'Image' column to header
    //   final header = ['id', 'name', 'studentId', 'email', 'classification', 'Image'];
    //   sheet.appendRow(header.map((h) => TextCellValue(h)).toList());
    //
    //   for (int i = 0; i < people.length; i++) {
    //     final p = people[i];
    //     final row = [
    //       p.id,
    //       p.name,
    //       p.studentId ?? '',
    //       p.email ?? '',
    //       p.classification ?? '',
    //       // Instead of embedding, export image path
    //       (i < imagesPaths.length) ? imagesPaths[i] : '',
    //     ];
    //     // Add row data
    //     sheet.appendRow(row.map((v) => TextCellValue(v.toString())).toList());
    //   }
    //
    //   final dir = await getApplicationDocumentsDirectory();
    //   final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    //   final file = File('${dir.path}/found_people_$timestamp.xlsx');
    //   await file.writeAsBytes(excel.encode()!, flush: true);
    //
    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
    //   OpenFile.open(file.path);
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Found People (' + (people.length.toString()) + ')', style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            icon: Text('Create Report', style: TextStyle(fontSize: 14)),
            onPressed: () => _exportExcel(context),
          ),
          // IconButton(
          //   tooltip: 'View Exported Files',
          //   icon: Icon(Icons.folder),
          //   onPressed: () {
          //     Navigator.of(context).push(
          //       MaterialPageRoute(builder: (_) => const ExportedFilesPage()),
          //     );
          //   },
          // ),
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
