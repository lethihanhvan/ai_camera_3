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
      appBar: AppBar(title: const Text('Exported Excel Files')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(_formatRange(), style: const TextStyle(fontSize: 14)),
                ),
                IconButton(
                  tooltip: 'Filter by date range',
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDateRange,
                ),
                if (_filterStart != null || _filterEnd != null)
                  IconButton(
                    tooltip: 'Clear filter',
                    icon: const Icon(Icons.clear),
                    onPressed: _clearFilter,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? const Center(child: Text('No exported Excel files found'))
                    : SafeArea(
                        child: ListView.separated(
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
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
