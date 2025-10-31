import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;

import '../db/database_helper.dart';
import '../dto/face_people.dart';
import '../dto/people.dart';

class FaceImagePreview extends StatefulWidget {
  final String imagePath;

  // final List<Rect> faceRects;
  final List<FacePeople> facePeoples;
  final bool rectsAreNormalized; // true if rects are in 0..1 normalized coordinates
  final int imageWidth;
  final int imageHeight;
  final Function onAddPeopleCallback;
  final List<imglib.Image>? faceImages;
  // Parent may provide an async callback to delete this image entry
  final Future<void> Function()? onDelete;

  const FaceImagePreview({
    Key? key,
    required this.imagePath,
    required this.facePeoples,
    this.rectsAreNormalized = false,
    required this.imageWidth,
    required this.imageHeight,
    required this.onAddPeopleCallback,
    this.faceImages,
    this.onDelete,
  }) : super(key: key);

  @override
  State<FaceImagePreview> createState() => _FaceImagePreviewState();
}

class _FaceImagePreviewState extends State<FaceImagePreview> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  int? _selectedFaceIndex; // index of tapped face
  Offset? _debugLastImagePoint; // for visual debugging when a hit is missed
  final GlobalKey _interactiveViewerKey = GlobalKey();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    // If currently identity, zoom in. Otherwise reset.
    final matrix = _transformationController.value;
    final isIdentity = matrix == Matrix4.identity();

    if (isIdentity) {
      // Zoom to 2x (clamped by InteractiveViewer maxScale) centered at tap position
      const double zoom = 2.0;
      // Translate so the tapped point stays under the finger after scaling
      final x = -position.dx * (zoom - 1);
      final y = -position.dy * (zoom - 1);
      final target = Matrix4.identity()
        ..translateByVector3(Vector3(x, y, 0))
        ..multiply(Matrix4.diagonal3Values(zoom, zoom, 1));
      _transformationController.value = target;
    } else {
      _transformationController.value = Matrix4.identity();
    }
  }

  Future<void> _addPeopleInformation(
    String? uuidInput,
    String name,
    String studentId,
    String? email,
    String classification,
    List<double>? embedding,
    Uint8List? image,
  ) async {
    if (uuidInput == null || uuidInput.isEmpty) {
      // add new person
      // create an example People
      final people = People(
        id: Uuid().v4(),
        name: name,
        studentId: studentId,
        email: email,
        classification: classification,
        embeddings: (embedding == null || embedding.isEmpty) ? [] : [embedding],
        images: (image == null) ? [] : [image],
      );

      // insert
      await DatabaseHelper().insertPeople(people);
      widget.onAddPeopleCallback();
      // show a simple confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu ${people.name} thành công!')));
      }
    } else {
      // update existing person
      final existing = await DatabaseHelper().getPeopleById(uuidInput);
      if (existing != null) {
        // create updated People with new embedding added
        final updatedEmbeddings = List<List<double>>.from(existing.embeddings);
        if (embedding != null && embedding.isNotEmpty) {
          updatedEmbeddings.add(embedding);
        }

        final updatedImages = List<Uint8List>.from(existing.images);
        if (image != null) {
          updatedImages.add(image);
        }

        final updatedPeople = People(
          id: existing.id,
          name: name,
          studentId: studentId,
          email: email,
          classification: classification,
          embeddings: updatedEmbeddings,
          images: updatedImages,
        );

        // update in database
        await DatabaseHelper().updatePeople(updatedPeople);
        widget.onAddPeopleCallback();
        // show a simple confirmation
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Đã cập nhật ${updatedPeople.name} thành công!')));
        }
      }
    }



    //     // create an example People
    //     final people = People(
    //       id: Uuid().v4(),
    //       name: 'Alice Example',
    //       studentId: 'S12345',
    //       email: 'alice@example.com',
    //       classification: 'student',
    //       embeddings: [
    //         [0.1, 0.2, 0.3], // embedding vectors (List<double>)
    //         [0.4, 0.5, 0.6],
    //       ],
    //     );
    //
    // // insert
    //     await DatabaseHelper().insertPeople(people);
    //
    // // fetch single using the same id we generated
    //     final loaded = await DatabaseHelper().getPeopleById(people.id);
    //     debugPrint('Loaded person: ${loaded?.toJson()}');
    //
    // // fetch all
    //     final all = await DatabaseHelper().getAllPeople();
    //     debugPrint('All people count: ${all.length}');
  }

  // New: handle tap down to detect which face rect was tapped
  void _handleTapDown(TapDownDetails details) {
    // Simpler robust mapping: map the tap to the InteractiveViewer viewport local coordinates,
    // then to the scene (child) coordinates, convert that to image pixel coordinates and test
    // against face rects (which must be either normalized or image-pixel coords depending on
    // `rectsAreNormalized`). This avoids mixing viewport and scene spaces.
    final RenderBox ivBox =
        _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox? ??
        context.findRenderObject() as RenderBox;
    final Offset viewportPoint = ivBox.globalToLocal(details.globalPosition);
    final Offset scenePoint = _transformationController.toScene(viewportPoint);

    // image and painting geometry
    final imageSize = Size(widget.imageWidth.toDouble(), widget.imageHeight.toDouble());
    final Size widgetSize = ivBox.size;
    final FittedSizes fitted = applyBoxFit(BoxFit.contain, imageSize, widgetSize);
    final Size destinationSize = fitted.destination;
    final double dx = (widgetSize.width - destinationSize.width) / 2.0;
    final double dy = (widgetSize.height - destinationSize.height) / 2.0;

    // Map scenePoint (child coords) into image pixel coordinates.
    final Offset localInImage = scenePoint - Offset(dx, dy);
    final double imageX = localInImage.dx * (imageSize.width / destinationSize.width);
    final double imageY = localInImage.dy * (imageSize.height / destinationSize.height);
    final Offset imagePoint = Offset(imageX, imageY);

    // hit test against image-space rects
    final bool normalizedRects = widget.rectsAreNormalized;
    // hit inflation in image pixels
    final double hitInflateImage = math.max(6.0, math.min(imageSize.width, imageSize.height) * 0.02);
    int? hitIndex;
    for (var i = 0; i < widget.facePeoples.length; i++) {
      final r0 = widget.facePeoples[i].faceRect;
      final Rect rImage = normalizedRects
          ? Rect.fromLTRB(
              r0.left * imageSize.width,
              r0.top * imageSize.height,
              r0.right * imageSize.width,
              r0.bottom * imageSize.height,
            )
          : r0;
      if (rImage.inflate(hitInflateImage).contains(imagePoint)) {
        hitIndex = i;
        break;
      }
    }

    if (hitIndex == null) {
      debugPrint(
        'No hit. viewportPoint=$viewportPoint scenePoint=$scenePoint imagePoint=$imagePoint normalizedRects=$normalizedRects',
      );
      for (var i = 0; i < widget.facePeoples.length; i++) {
        final r0 = widget.facePeoples[i].faceRect;
        final Rect rImage = normalizedRects
            ? Rect.fromLTRB(
                r0.left * imageSize.width,
                r0.top * imageSize.height,
                r0.right * imageSize.width,
                r0.bottom * imageSize.height,
              )
            : r0;
        debugPrint(' rect[$i]=imageRect=$rImage');
      }
      setState(() => _debugLastImagePoint = imagePoint);
    } else {
      setState(() => _debugLastImagePoint = null);
    }

    debugPrint('Tapped face index: $hitIndex');
    setState(() {
      _selectedFaceIndex = hitIndex;
    });

    if (hitIndex != null) {
      showPeopleInformationDialog(faceIndex: hitIndex);
    }
  }

  // Show dialog to add or update People. If faceIndex is provided, prefill name with a helpful placeholder.
  Future<void> showPeopleInformationDialog({int? faceIndex}) async {
    final uuidController = TextEditingController();
    final nameController = TextEditingController(text: faceIndex != null ? '' : '');
    final studentIdController = TextEditingController();
    final emailController = TextEditingController();
    final classificationController = TextEditingController();

    uuidController.text = faceIndex != null && widget.facePeoples[faceIndex].dbId != null
        ? widget.facePeoples[faceIndex].dbId!
        : '';

    // Fetch all people from database
    final allPeople = await DatabaseHelper().getAllPeople();

    bool isSelectMode = uuidController.text.isNotEmpty; // Start in select mode if UUID exists
    People? selectedPerson;

    if (uuidController.text.isNotEmpty) {
      // existing person; find from allPeople list to ensure same instance
      selectedPerson = allPeople.firstWhere(
        (p) => p.id == uuidController.text,
        orElse: () => allPeople.isEmpty ? People(id: '', name: '', classification: '') : allPeople.first,
      );

      // Only use if we found a valid match
      if (selectedPerson.id == uuidController.text) {
        nameController.text = selectedPerson.name;
        studentIdController.text = selectedPerson.studentId ?? "";
        emailController.text = selectedPerson.email ?? '';
        classificationController.text = selectedPerson.classification ?? '';
      } else {
        // No match found, switch to create mode
        selectedPerson = null;
        isSelectMode = false;
      }
    }

    // Get face image for preview
    Widget? facePreview;
    if (faceIndex != null) {
      // Use pre-cropped face image if available
      if (widget.faceImages != null && faceIndex < widget.faceImages!.length) {
        final faceImg = widget.faceImages![faceIndex];
        final Uint8List bytes = Uint8List.fromList(imglib.encodePng(faceImg));

        facePreview = Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 120,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 60),
                );
              },
            ),
          ),
        );
      } else {
        // Fallback to manual cropping if faceImages not available
        final faceRect = widget.facePeoples[faceIndex].faceRect;

        facePreview = Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: faceRect.width,
                height: faceRect.height,
                child: OverflowBox(
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: widget.imageWidth.toDouble(),
                  maxHeight: widget.imageHeight.toDouble(),
                  child: Transform.translate(
                    offset: Offset(-faceRect.left, -faceRect.top),
                    child: Image.file(
                      File(widget.imagePath),
                      width: widget.imageWidth.toDouble(),
                      height: widget.imageHeight.toDouble(),
                      fit: BoxFit.none,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, size: 60),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: AlertDialog(
                title: Column(
                  children: [
                    if (facePreview != null) ...[facePreview, const SizedBox(height: 12)],
                    const Text('Lưu thông tin người', style: TextStyle(fontSize: 16)),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode selector
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Chọn người có sẵn', style: TextStyle(fontSize: 14)),
                            icon: Icon(Icons.person_search, size: 18),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Tạo mới', style: TextStyle(fontSize: 14)),
                            icon: Icon(Icons.person_add, size: 18),
                          ),
                        ],
                        selected: {isSelectMode},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setState(() {
                            isSelectMode = newSelection.first;
                            if (!isSelectMode) {
                              // Reset to new person mode
                              selectedPerson = null;
                              uuidController.clear();
                              nameController.clear();
                              studentIdController.clear();
                              emailController.clear();
                              classificationController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Show dropdown if in select mode
                      if (isSelectMode) ...[
                        DropdownButtonFormField<People>(
                          initialValue: selectedPerson,
                          decoration: InputDecoration(
                            labelText: 'Chọn người',
                            labelStyle: const TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.people, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: allPeople.map((person) {
                            return DropdownMenuItem<People>(
                              value: person,
                              child: Row(
                                children: [
                                  Text(
                                    '${person.name} (${person.classification ?? "N/A"})',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  person.images.isNotEmpty
                                      ? Row(
                                    children: [
                                      ...person.images.take(5).map((imgBytes) => Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          // decoration: BoxDecoration(
                                          //   borderRadius: BorderRadius.circular(4),
                                          //   border: Border.all(color: Colors.grey, width: 1),
                                          // ),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundImage: MemoryImage(imgBytes),
                                          ),
                                        ),
                                      )),
                                    ],
                                  )
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (People? person) {
                            setState(() {
                              selectedPerson = person;
                              if (person != null) {
                                uuidController.text = person.id;
                                nameController.text = person.name;
                                studentIdController.text = person.studentId ?? "";
                                emailController.text = person.email ?? '';
                                classificationController.text = person.classification ?? '';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Show UUID field (read-only)
                      if (uuidController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTextFieldWithLabel(
                            controller: uuidController,
                            label: 'UUID',
                            icon: Icons.fingerprint,
                            readOnly: true,
                          ),
                        ),

                      // Editable fields (disabled in select mode after selection)
                      _buildTextFieldWithLabel(
                        controller: nameController,
                        label: 'Tên',
                        icon: Icons.person,
                        hint: 'Nhập họ và tên',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFieldWithLabel(
                        controller: studentIdController,
                        label: 'Mã sinh viên',
                        icon: Icons.badge,
                        hint: 'Nhập mã sinh viên',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFieldWithLabel(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email,
                        hint: 'Nhập email',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFieldWithLabel(
                        controller: classificationController,
                        label: 'Phân loại',
                        icon: Icons.category,
                        hint: 'VD: Sinh viên, Giảng viên',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Lưu'),
                    onPressed: () {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tên là bắt buộc')),
                        );
                        return;
                      }
                      // Get face image bytes
                      Uint8List? faceImageBytes;
                      if (faceIndex != null && widget.faceImages != null && faceIndex < widget.faceImages!.length) {
                        final faceImg = widget.faceImages![faceIndex];
                        faceImageBytes = Uint8List.fromList(imglib.encodePng(faceImg));
                      }

                      _addPeopleInformation(
                        uuidController.text,
                        nameController.text,
                        studentIdController.text,
                        emailController.text,
                        classificationController.text,
                        faceIndex != null ? widget.facePeoples[faceIndex].embedding : null,
                        faceImageBytes,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextFieldWithLabel({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? Colors.grey.shade700 : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14),
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.transparent,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header with image path and delete button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Icon(Icons.image, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.imagePath.split('/').last,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Xóa ảnh',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Xóa ảnh'),
                          content: const Text('Bạn có chắc chắn muốn xóa ảnh này?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Hủy'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await widget.onDelete!();
                      }
                    },
                  ),
              ],
            ),
          ),
          // Interactive viewer for the image and face boxes
          AspectRatio(
            aspectRatio: widget.imageWidth / widget.imageHeight,
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              onTapDown: _handleTapDown,
              child: InteractiveViewer(
                key: _interactiveViewerKey,
                transformationController: _transformationController,
                minScale: 0.1,
                maxScale: 4.0,
                child: CustomPaint(
                  size: Size(
                    widget.imageWidth.toDouble(),
                    widget.imageHeight.toDouble(),
                  ),
                  painter: FacePainter(
                    image: FileImage(File(widget.imagePath)),
                    facePeoples: widget.facePeoples,
                    imageSize: Size(
                      widget.imageWidth.toDouble(),
                      widget.imageHeight.toDouble(),
                    ),
                    rectsAreNormalized: widget.rectsAreNormalized,
                    selectedFaceIndex: _selectedFaceIndex,
                    debugLastImagePoint: _debugLastImagePoint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final ImageProvider image;
  final List<FacePeople> facePeoples;
  final Size imageSize;
  final bool rectsAreNormalized;
  final int? selectedFaceIndex;
  final Offset? debugLastImagePoint;

  FacePainter({
    required this.image,
    required this.facePeoples,
    required this.imageSize,
    this.rectsAreNormalized = false,
    this.selectedFaceIndex,
    this.debugLastImagePoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint the face rectangles
    for (var i = 0; i < facePeoples.length; i++) {
      final r0 = facePeoples[i].faceRect;
      final Rect rect = rectsAreNormalized
          ? Rect.fromLTRB(
              r0.left * size.width,
              r0.top * size.height,
              r0.right * size.width,
              r0.bottom * size.height,
            )
          : Rect.fromLTWH(
              r0.left * (size.width / imageSize.width),
              r0.top * (size.height / imageSize.height),
              r0.width * (size.width / imageSize.width),
              r0.height * (size.height / imageSize.height),
            );

      final isSelected = i == selectedFaceIndex;
      final hasDbId = facePeoples[i].dbId != null;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4.0 : 2.0
        ..color = hasDbId
            ? (isSelected ? Colors.green.shade700 : Colors.green.shade400)
            : (isSelected ? Colors.red.shade700 : Colors.red.shade400);

      canvas.drawRect(rect, paint);

      // Optionally, draw a label
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Khuôn mặt ${i + 1}${hasDbId ? " (Đã nhận dạng)" : ""}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.0,
            backgroundColor: paint.color.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, rect.topLeft - Offset(0, textPainter.height));
    }

    // Debug: draw the last tapped point if it didn't hit a face
    if (debugLastImagePoint != null) {
      final Offset pointInWidget = Offset(
        debugLastImagePoint!.dx * (size.width / imageSize.width),
        debugLastImagePoint!.dy * (size.height / imageSize.height),
      );
      final paint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pointInWidget, 8.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.facePeoples != facePeoples ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rectsAreNormalized != rectsAreNormalized ||
        oldDelegate.selectedFaceIndex != selectedFaceIndex ||
        oldDelegate.debugLastImagePoint != debugLastImagePoint;
  }
}
