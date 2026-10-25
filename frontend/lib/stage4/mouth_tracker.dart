import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'golden_store.dart';
import 'mouth_features.dart';

const _contourTypes = {
  'upperLipTop': FaceContourType.upperLipTop,
  'upperLipBottom': FaceContourType.upperLipBottom,
  'lowerLipTop': FaceContourType.lowerLipTop,
  'lowerLipBottom': FaceContourType.lowerLipBottom,
  'noseBottom': FaceContourType.noseBottom,
  'face': FaceContourType.face,
  'leftEye': FaceContourType.leftEye,
  'rightEye': FaceContourType.rightEye,
};

/// Front camera + ML Kit, emitting a [MouthFrame] for every frame where a face is found.
/// Separate from FaceCamera (used by the word drill) so that one stays unchanged.
class MouthTracker {
  CameraController? _controller;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      // fast mode for a higher frame rate; movement over time needs frames
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _busy = false;
  bool _streaming = false;
  final Stopwatch _clock = Stopwatch();

  /// Called for each frame with a face; null when the frame had no usable face.
  void Function(MouthFrame? frame)? onFrame;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Returns false if there's no front camera (e.g. the simulator) or it can't start.
  Future<bool> start() async {
    if (_streaming) return true;
    try {
      // a real device answers right away; this only matters without a camera plugin
      final cameras = await availableCameras().timeout(const Duration(seconds: 5));
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      if (front.isEmpty) return false;
      _controller = CameraController(
        front.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      _clock
        ..reset()
        ..start();
      await _controller!.startImageStream(_process);
      _streaming = true;
      return true;
    } on CameraException catch (e) {
      print('MouthTracker camera error: ${e.code} ${e.description}');
    } on MissingPluginException {
      // widget tests have no camera plugin
    } on TimeoutException {
      print('MouthTracker: no answer from the camera plugin');
    } on PlatformException catch (e) {
      print('MouthTracker camera unavailable: ${e.message}');
    }
    return false;
  }

  Future<void> _process(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    try {
      final t = _clock.elapsedMilliseconds;
      final input = _toInputImage(image, _controller!.description.sensorOrientation);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      onFrame?.call(faces.isEmpty ? null : _frame(faces.first, t));
    } catch (e) {
      print('MouthTracker frame error: $e');
    } finally {
      _busy = false;
    }
  }

  MouthFrame? _frame(Face face, int t) {
    final flat = <String, List<int>>{};
    final points = <String, List<Pt>>{};
    for (final e in _contourTypes.entries) {
      final contour = face.contours[e.value];
      if (contour == null || contour.points.isEmpty) continue;
      flat[e.key] = [for (final p in contour.points) ...[p.x, p.y]];
      points[e.key] = [for (final p in contour.points) (x: p.x.toDouble(), y: p.y.toDouble())];
    }
    final features = mouthFeatures(points);
    if (features == null) return null;
    return MouthFrame(t: t, features: features, contours: flat);
  }

  InputImage? _toInputImage(CameraImage image, int rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    if (_streaming) await _controller?.stopImageStream();
    _streaming = false;
    await _controller?.dispose();
    _controller = null;
    try {
      await _detector.close();
    } on MissingPluginException {
      // widget tests have no ML Kit plugin
    }
  }
}
