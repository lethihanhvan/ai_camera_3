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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${people.name} successfully!')));
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
          ).showSnackBar(SnackBar(content: Text('Updated ${updatedPeople.name} successfully!')));
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
                    const Text('Save People Information', style: TextStyle(fontSize: 16)),
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
                            label: Text('Select Existing', style: TextStyle(fontSize: 14)),
                            icon: Icon(Icons.person_search, size: 18),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Create New', style: TextStyle(fontSize: 14)),
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
                            labelText: 'Select Person',
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
                        label: 'Name',
                        icon: Icons.person,
                        hint: 'Enter full name',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFieldWithLabel(
                        controller: studentIdController,
                        label: 'Student ID',
                        icon: Icons.badge,
                        hint: 'e.g., S12345',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFieldWithLabel(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email,
                        hint: 'user@example.com',
                        keyboardType: TextInputType.emailAddress,
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFieldWithLabel(
                        controller: classificationController,
                        label: 'Classification',
                        icon: Icons.category,
                        hint: 'e.g., Student, Teacher',
                        readOnly: isSelectMode && selectedPerson != null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
                      final uuidInput = uuidController.text.trim();
                      final name = nameController.text.trim();
                      final studentId = studentIdController.text.trim();
                      final email = emailController.text.trim().isEmpty ? null : emailController.text.trim();
                      final classification = classificationController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
                        return;
                      }

                      Navigator.of(context).pop();
                      _addPeopleInformation(
                        uuidInput.isEmpty ? null : uuidInput,
                        name,
                        studentId,
                        email,
                        classification,
                        faceIndex != null ? widget.facePeoples[faceIndex].embedding : null,
                        await facePreviewAsBytes(faceIndex!),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    // controllers will be GC'd; no explicit dispose needed for ephemeral controllers here
  }

  Widget _buildTextFieldWithLabel({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16),
        prefixIcon: Icon(icon, size: 20),
        isDense: false,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  /// Return a PNG `Uint8List` for the face preview at [faceIndex].
  ///
  /// Uses `widget.faceImages` (pre-cropped imglib.Image) when available.
  /// Falls back to decoding and cropping the original image at `widget.imagePath`.
  /// Returns null if the index is invalid or an error occurs.
  Future<Uint8List?> facePreviewAsBytes(int faceIndex) async {
    try {
      if (faceIndex < 0 || faceIndex >= widget.facePeoples.length) return null;

      // If the pre-cropped images are available, encode that image to PNG bytes.
      if (widget.faceImages != null && faceIndex < widget.faceImages!.length) {
        final img = widget.faceImages![faceIndex];
        return Uint8List.fromList(imglib.encodePng(img));
      }

      // Fallback: decode and crop original image file
      final file = File(widget.imagePath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final im = imglib.decodeImage(bytes);
      if (im == null) return null;

      // Determine crop rectangle in pixel coordinates
      Rect r = widget.facePeoples[faceIndex].faceRect;
      bool normalized = widget.rectsAreNormalized;
      int x, y, w, h;

      if (normalized) {
        x = (r.left * im.width).round();
        y = (r.top * im.height).round();
        w = ((r.right - r.left) * im.width).round();
        h = ((r.bottom - r.top) * im.height).round();
      } else {
        x = r.left.round();
        y = r.top.round();
        w = r.width.round();
        h = r.height.round();
      }

      // Optionally add a small padding so the face isn't tight to border (same as other code)
      const int pad = 10;
      x = (x - pad).clamp(0, im.width - 1);
      y = (y - pad).clamp(0, im.height - 1);
      w = (w + pad * 2).clamp(0, im.width - x);
      h = (h + pad * 2).clamp(0, im.height - y);

      // Ensure width/height at least 1
      if (w <= 0 || h <= 0) return null;

      final cropped = imglib.copyCrop(im, x: x, y: y, width: w, height: h);
      return Uint8List.fromList(imglib.encodePng(cropped));
    } catch (e) {
      debugPrint('facePreviewAsBytes error: $e');
      return null;
    }
  }

  /// Show confirmation dialog and call parent's onDelete if confirmed.
  Future<void> _confirmAndDeleteImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete image?'),
        content: const Text('Remove this image and its face items from the list?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (widget.onDelete != null) await widget.onDelete!();
      } catch (e) {
        debugPrint('onDelete callback error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        SizedBox(
          width: displayWidth,
          child: AspectRatio(
            aspectRatio: widget.imageWidth / widget.imageHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ClipRect(
                  child: InteractiveViewer(
                    key: _interactiveViewerKey,
                    transformationController: _transformationController,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: const EdgeInsets.all(100),
                    minScale: 1.0,
                    maxScale: 10.0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: _handleTapDown,
                      onLongPress: () async {
                        await _confirmAndDeleteImage();
                      },
                      onDoubleTapDown: (details) => _doubleTapDetails = details,
                      onDoubleTap: _handleDoubleTap,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          // Delete button overlay (top-right)
                          // Positioned(
                          //   top: 8,
                          //   right: 8,
                          //   child: Material(
                          //     color: Colors.black45,
                          //     shape: const CircleBorder(),
                          //     clipBehavior: Clip.antiAlias,
                          //     child: IconButton(
                          //       icon: const Icon(Icons.delete, size: 20, color: Colors.white),
                          //       tooltip: 'Delete image',
                          //       onPressed: () async {
                          //         await _confirmAndDeleteImage();
                          //       },
                          //     ),
                          //   ),
                          // ),
                           if (widget.facePeoples.isNotEmpty)
                             Positioned.fill(
                               child: CustomPaint(
                                 painter: _FacePainter(
                                   widget.facePeoples,
                                   imageSize: Size(widget.imageWidth.toDouble(), widget.imageHeight.toDouble()),
                                   selectedIndex: _selectedFaceIndex,
                                   debugTapPoint: _debugLastImagePoint,
                                   rectsAreNormalized: widget.rectsAreNormalized,
                                 ),
                               ),
                             ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // const SizedBox(height: 8),
        // // Text('People Detected: ${widget.facePeoples.length}'),
        // // const SizedBox(height: 16),
        // TextButton(
        //   onPressed: () async {
        //     await showPeopleInformationDialog();
        //   },
        //   child: const Text('Add People'),
        // ),
      ],
    );
  }
}

class _FacePainter extends CustomPainter {
  // final List<Rect> rects;
  final List<FacePeople> facePeoples;
  final Size imageSize;
  final int? selectedIndex;
  final Offset? debugTapPoint;
  final bool rectsAreNormalized;

  _FacePainter(
    this.facePeoples, {
    required this.imageSize,
    this.selectedIndex,
    this.debugTapPoint,
    required this.rectsAreNormalized,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.red.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Figure out exactly how the image is painted inside this canvas using BoxFit.contain
    final FittedSizes fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final Size destinationSize = fitted.destination;
    final double dx = (size.width - destinationSize.width) / 2.0;
    final double dy = (size.height - destinationSize.height) / 2.0;

    final double paintScaleX = destinationSize.width / imageSize.width;
    final double paintScaleY = destinationSize.height / imageSize.height;

    for (var i = 0; i < facePeoples.length; i++) {
      final String? uuid = facePeoples[i].dbId;
      final rect = facePeoples[i].faceRect;

      // convert rect to painted coordinates. If rects are normalized (0..1) then they should be
      // provided as such by the caller; we can't detect that reliably here, but the hit-test
      // already attempts to handle normalized rects. For painting we'll treat the passed rects
      // as image-pixel coordinates if their right/bottom are > 1. Otherwise we treat them
      // as normalized fractions and convert accordingly.
      Rect paintedRect;
      if (rect.right <= 1.01 && rect.bottom <= 1.01) {
        // normalized rect
        final left = dx + rect.left * destinationSize.width;
        final top = dy + rect.top * destinationSize.height;
        final right = dx + rect.right * destinationSize.width;
        final bottom = dy + rect.bottom * destinationSize.height;
        paintedRect = Rect.fromLTRB(left, top, right, bottom);
      } else {
        // image pixel rect
        final left = dx + rect.left * paintScaleX;
        final top = dy + rect.top * paintScaleY;
        final right = dx + rect.right * paintScaleX;
        final bottom = dy + rect.bottom * paintScaleY;
        paintedRect = Rect.fromLTRB(left, top, right, bottom);
      }

      if (selectedIndex != null && i == selectedIndex) {
        final fill = Paint()..color = Colors.green.withAlpha((0.2 * 255).round());
        canvas.drawRect(paintedRect, fill);
        final highlight = Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawRect(paintedRect, highlight);
      } else {
        if (uuid != null && uuid.isNotEmpty) {
          print('Drawing highlighted rect for known uuid=$uuid at index=$i');
          final highlight = Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRect(paintedRect, highlight);
        } else {
          canvas.drawRect(paintedRect, strokePaint);
        }
      }

      // draw index label for debugging
      // final textPainter = TextPainter(
      //   text: TextSpan(text: '$i', style: const TextStyle(color: Colors.white, fontSize: 12, backgroundColor: Colors.black45)),
      //   textDirection: TextDirection.ltr,
      // );
      // textPainter.layout();
      // final labelOffset = Offset(paintedRect.left + 2, paintedRect.top + 2);
      // textPainter.paint(canvas, labelOffset);
    }

    // Draw debug tapped point (in image coords) if provided
    // if (debugTapPoint != null) {
    //   final dotPaint = Paint()..color = Colors.yellow;
    //   final dxp = dx + debugTapPoint!.dx * paintScaleX;
    //   final dyp = dy + debugTapPoint!.dy * paintScaleY;
    //   canvas.drawCircle(Offset(dxp, dyp), 6.0, dotPaint);
    //   final tp = TextPainter(
    //     text: const TextSpan(text: 'tap', style: TextStyle(color: Colors.yellow, fontSize: 10, backgroundColor: Colors.black45)),
    //     textDirection: TextDirection.ltr,
    //   );
    //   tp.layout();
    //   tp.paint(canvas, Offset(dxp + 6, dyp - 6));
    // }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      facePeoples != oldDelegate.facePeoples ||
      imageSize != oldDelegate.imageSize ||
      selectedIndex != oldDelegate.selectedIndex ||
      debugTapPoint != oldDelegate.debugTapPoint;

  // @override
  // bool shouldRepaint(covariant _FacePainter oldDelegate) =>
  //     true;
}
