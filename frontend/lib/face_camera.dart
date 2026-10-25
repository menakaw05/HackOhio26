import 'dart:convert';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Front camera used during phoneme attempts. While streaming, it runs ML Kit face detection
/// on each frame and buffers the lip contours.
class FaceCamera {
  CameraController? _controller;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      // fast: about 3x the frames of accurate with the avatar running (CLAUDE.md benchmark),
      // so a short sound still gets several frames for the lip model
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  final List<Map<String, dynamic>> _frames = [];
  int _frameIndex = 0;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _isStreaming;
  int get frameCount => _frames.length;

  /// Returns false if the device has no front camera (e.g. the iOS simulator).
  Future<bool> initialize() async {
    if (isInitialized) return true;

    final cameras = await availableCameras();
    final frontCameras =
        cameras.where((cam) => cam.lensDirection == CameraLensDirection.front);
    if (frontCameras.isEmpty) {
      print("No front camera available");
      return false;
    }

    _controller = CameraController(
      frontCameras.first,
      ResolutionPreset.medium,
      // the recorder owns the mic
      enableAudio: false,
      // ML Kit on iOS expects BGRA frames
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      return true;
    } on CameraException catch (e) {
      print('Camera error: ${e.code} ${e.description}');
      _controller = null;
      return false;
    }
  }

  /// Frees the camera for something else (stage 4's mouth tracker); [initialize] takes it
  /// back. The face detector stays open.
  Future<void> release() async {
    if (_isStreaming) await _controller?.stopImageStream();
    _isStreaming = false;
    await _controller?.dispose();
    _controller = null;
  }

  /// Starts buffering mouth contours from the camera stream.
  Future<void> startFaceStream() async {
    final controller = _controller;
    if (controller == null || !isInitialized || _isStreaming) return;

    _frames.clear();
    _frameIndex = 0;
    _isStreaming = true;

    await controller.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final inputImage =
            _convertToInputImage(image, controller.description.sensorOrientation);
        if (inputImage == null) return;

        final faces = await _faceDetector.processImage(inputImage);
        if (faces.isEmpty) return;

        final face = faces.first;
        final contourTypes = [
          FaceContourType.upperLipTop,
          FaceContourType.upperLipBottom,
          FaceContourType.lowerLipTop,
          FaceContourType.lowerLipBottom,
        ];

        // raw pixel coordinates, matching the training data (features are ratios of mouth width)
        final mouthContours = <String, List<Map<String, double>>>{};
        for (final contourType in contourTypes) {
          final contour = face.contours[contourType];
          if (contour != null && contour.points.isNotEmpty) {
            mouthContours[contourType.name] = contour.points
                .map((p) => {'x': p.x.toDouble(), 'y': p.y.toDouble()})
                .toList();
          }
        }

        if (mouthContours.isNotEmpty) {
          _frames.add({
            'frame_index': _frameIndex,
            'timestamp': DateTime.now().toIso8601String(),
            'mouthContours': mouthContours,
          });
          _frameIndex++;
        }
      } catch (e) {
        print('Error in frame processing: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  /// Stops the stream and returns the attempt as JSON: {"frame": [...]}.
  Future<String> stopFaceStream() async {
    if (!_isStreaming) return jsonEncode({'frame': []});

    await _controller?.stopImageStream();
    _isStreaming = false;

    final payload = jsonEncode({'frame': _frames});
    print('Captured ${_frames.length} face frames');

    _frames.clear();
    _frameIndex = 0;
    return payload;
  }

  InputImage? _convertToInputImage(CameraImage image, int rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ??
            InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    if (_isStreaming) await _controller?.stopImageStream();
    _isStreaming = false;
    await _controller?.dispose();
    _controller = null;
    await _faceDetector.close();
  }
}
