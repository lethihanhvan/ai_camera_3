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
        title: Row(
          children: [
            Icon(
              Icons.people_alt,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Người đã tìm thấy (${people.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _exportExcel(context),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Xuất báo cáo'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
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
        child: people.isEmpty
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
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Không tìm thấy người',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Không có người quen nào được phát hiện trong ảnh',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Column(
                  children: [
                    // Summary card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
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
                          _buildSummaryItem(
                            icon: Icons.person,
                            label: 'Người',
                            value: '${people.length}',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildSummaryItem(
                            icon: Icons.photo,
                            label: 'Tổng ảnh',
                            value: '${people.fold<int>(0, (sum, p) => sum + p.images.length)}',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildSummaryItem(
                            icon: Icons.face,
                            label: 'Dữ liệu nhúng',
                            value: '${people.fold<int>(0, (sum, p) => sum + p.embeddings.length)}',
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: people.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final p = people[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with name
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (p.studentId != null)
                                              Text(
                                                'ID: ${p.studentId}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.green.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Đã nhận diện',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
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

                                  // Image thumbnails
                                  if (p.images.isNotEmpty) ...[
                                    Text(
                                      'Ảnh khuôn mặt',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 64,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: (p.images.length > 5) ? 5 : p.images.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                                        itemBuilder: (context, imgIndex) {
                                          final remaining = p.images.length - 5;
                                          if (imgIndex == 4 && p.images.length > 5) {
                                            return Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '+${remaining > 0 ? remaining : 0}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          final bytes = p.images[imgIndex];
                                          return Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey.shade300, width: 2),
                                              image: DecorationImage(
                                                image: MemoryImage(bytes),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Details
                                  if (p.email != null || p.classification != null) ...[
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                  ],

                                  if (p.email != null)
                                    _buildInfoRow(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: p.email!,
                                      context: context,
                                    ),

                                  if (p.classification != null)
                                    _buildInfoRow(
                                      icon: Icons.school_outlined,
                                      label: 'Classification',
                                      value: p.classification!,
                                      context: context,
                                    ),

                                  // Stats
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildStatChip(
                                        icon: Icons.face,
                                        label: '${p.embeddings.length} embeddings',
                                        context: context,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        icon: Icons.photo_library,
                                        label: '${p.images.length} photos',
                                        context: context,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryItem({
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
