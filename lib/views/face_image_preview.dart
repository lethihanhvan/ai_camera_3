import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;
import 'package:uuid/uuid.dart';

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

  const FaceImagePreview({
    Key? key,
    required this.imagePath,
    required this.facePeoples,
    this.rectsAreNormalized = false,
    required this.imageWidth,
    required this.imageHeight,
    required this.onAddPeopleCallback,
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

  Future<void> _addPeopleInformation(String? uuidInput, String name, String studentId, String? email, String classification,
      List<double>? embedding) async {
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
      );

      // insert
      await DatabaseHelper().insertPeople(people);
      // show a simple confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${people.name} successfully!')),
        );
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

        final updatedPeople = People(
          id: existing.id,
          name: name,
          studentId: studentId,
          email: email,
          classification: classification,
          embeddings: updatedEmbeddings,
        );

        // update in database
        await DatabaseHelper().updatePeople(updatedPeople);
        // show a simple confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated ${updatedPeople.name} successfully!')),
          );
        }
      }
    }

    widget.onAddPeopleCallback();


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
    final RenderBox ivBox = _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox? ?? context.findRenderObject() as RenderBox;
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
          ? Rect.fromLTRB(r0.left * imageSize.width, r0.top * imageSize.height, r0.right * imageSize.width, r0.bottom * imageSize.height)
          : r0;
      if (rImage.inflate(hitInflateImage).contains(imagePoint)) {
        hitIndex = i;
        break;
      }
    }

    if (hitIndex == null) {
      debugPrint('No hit. viewportPoint=$viewportPoint scenePoint=$scenePoint imagePoint=$imagePoint normalizedRects=$normalizedRects');
      for (var i = 0; i < widget.facePeoples.length; i++) {
        final r0 = widget.facePeoples[i].faceRect;
        final Rect rImage = normalizedRects
            ? Rect.fromLTRB(r0.left * imageSize.width, r0.top * imageSize.height, r0.right * imageSize.width, r0.bottom * imageSize.height)
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

    if (uuidController.text.isNotEmpty) {
      // existing person; load their info to prefill
      final existing = await DatabaseHelper().getPeopleById(uuidController.text);
      if (existing != null) {
        nameController.text = existing.name;
        studentIdController.text = existing.studentId ?? "";
        emailController.text = existing.email ?? '';
        classificationController.text = existing.classification ?? '';
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save People Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: uuidController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'UUID'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: studentIdController,
                  decoration: const InputDecoration(labelText: 'Student ID'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: classificationController,
                  decoration: const InputDecoration(labelText: 'Classification'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {

                final uuidInput = uuidController.text.trim();
                final name = nameController.text.trim();
                final studentId = studentIdController.text.trim();
                final email = emailController.text.trim().isEmpty ? null : emailController.text.trim();
                final classification = classificationController.text.trim();
                Navigator.of(context).pop();
                // For now embedding isn't available here; pass null so DB helper will store empty embeddings.
                _addPeopleInformation(uuidInput.isEmpty ? null : uuidInput, name, studentId, email, classification,
                    widget.facePeoples[faceIndex ?? 0].embedding);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    // controllers will be GC'd; no explicit dispose needed for ephemeral controllers here
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

  _FacePainter(this.facePeoples, {required this.imageSize, this.selectedIndex, this.debugTapPoint, required this.rectsAreNormalized});

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
           imageSize != oldDelegate.imageSize
       || selectedIndex != oldDelegate.selectedIndex || debugTapPoint != oldDelegate.debugTapPoint;

  // @override
  // bool shouldRepaint(covariant _FacePainter oldDelegate) =>
  //     true;
 }
