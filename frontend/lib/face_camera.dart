import 'package:camera/camera.dart';

/// Front camera used during phoneme attempts.
class FaceCamera {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

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

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
