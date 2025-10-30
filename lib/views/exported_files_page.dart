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

  // Added date-range filter
  DateTime? _filterStart;
  DateTime? _filterEnd;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  /// Load .xlsx files from app document directory and optionally filter by modified date range.
  Future<void> _loadFiles({DateTime? start, DateTime? end}) async {
    setState(() => _loading = true);
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) {
      return f.path.toLowerCase().endsWith('.xlsx');
    }).toList();

    // If start or end provided, normalize them to local date boundaries
    DateTime? s;
    DateTime? e;
    if (start != null) {
      s = DateTime(start.year, start.month, start.day);
    }
    if (end != null) {
      e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    }

    List<FileSystemEntity> filtered;
    if (s != null || e != null) {
      filtered = files.where((f) {
        try {
          final m = f.statSync().modified;
          if (s != null && m.isBefore(s)) return false;
          if (e != null && m.isAfter(e)) return false;
          return true;
        } catch (_) {
          return false;
        }
      }).toList();
    } else {
      filtered = files;
    }

    filtered.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() {
      _files = filtered;
      _loading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 1);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _filterStart != null && _filterEnd != null
          ? DateTimeRange(start: _filterStart!, end: _filterEnd!)
          : null,
    );

    if (picked != null) {
      _filterStart = picked.start;
      _filterEnd = picked.end;
      await _loadFiles(start: _filterStart, end: _filterEnd);
    }
  }

  Future<void> _clearFilter() async {
    setState(() {
      _filterStart = null;
      _filterEnd = null;
    });
    await _loadFiles();
  }

  String _formatRange() {
    if (_filterStart == null && _filterEnd == null) return 'All dates';
    final startText = _filterStart != null ? '${_filterStart!.year}-${_filterStart!.month.toString().padLeft(2, '0')}-${_filterStart!.day.toString().padLeft(2, '0')}' : '';
    final endText = _filterEnd != null ? '${_filterEnd!.year}-${_filterEnd!.month.toString().padLeft(2, '0')}-${_filterEnd!.day.toString().padLeft(2, '0')}' : '';
    if (_filterStart != null && _filterEnd != null) return '$startText → $endText';
    return _filterStart != null ? 'From $startText' : 'Until $endText';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text(
              'Report Files',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (_filterStart != null || _filterEnd != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Clear filter',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.clear, color: Colors.red.shade700, size: 20),
                ),
                onPressed: _clearFilter,
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
        child: Column(
          children: [
            // Date filter card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date Filter',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatRange(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text('Filter'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),

            // Files list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
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
                                  Icons.folder_open,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Report Files',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filterStart != null || _filterEnd != null
                                    ? 'No files in selected date range'
                                    : 'Export a report to see files here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _files.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final stat = file.statSync();
                            final name = file.path.split('/').last;
                            final modified = stat.modified;
                            final sizeInKB = (stat.size / 1024).toStringAsFixed(1);

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => OpenFile.open(file.path),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.insert_drive_file,
                                          color: Colors.green.shade700,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.storage,
                                                  size: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$sizeInKB KB',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.open_in_new,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
