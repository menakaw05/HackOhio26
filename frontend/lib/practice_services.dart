import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'avatar_view.dart';
import 'face_camera.dart';
import 'phoneme_classifier.dart';
import 'speech_controller.dart';
import 'speech_models.dart';
import 'tts_service.dart';

/// One sound attempt judged by the ONNX lip model.
class LipCheck {
  const LipCheck({required this.passed, required this.score, required this.tip});

  final bool passed;

  /// Share of the attempt's frames the model judged correct, 0 to 1.
  final double score;

  /// The model's feedback for its label, e.g. "Try rounding your lips more".
  final String tip;
}

/// What Word Practice uses: Azure scoring and speech through the backend, the
/// front camera with the lip model, and the avatar coach.
abstract class PracticeServices {
  /// Azure TTS; segments like "/u/" are said as that sound.
  Future<void> speak(String text);
  Future<void> stopSpeaking();

  /// Records the word, then scores it with Azure at the phoneme level.
  Future<bool> startRecording(BuildContext context);
  Future<PAResult> stopAndScore(String word);

  /// Front camera for the mirror; [camera] is null until [startCamera] works.
  Future<bool> startCamera();
  CameraController? get camera;

  /// Loads the lip model for [phoneme] and returns the tips it can give.
  Future<List<String>> loadLipModel(String phoneme);
  Future<void> startLipCapture();

  /// Null if no face was seen.
  Future<LipCheck?> stopLipCapture();

  /// The avatar page for the coach, or null to show a placeholder.
  String? get coachUrl;

  void dispose();
}

/// Makes the services for each Word Practice screen. Tests swap in fakes.
PracticeServices Function() createPracticeServices = LivePracticeServices.new;

class LivePracticeServices implements PracticeServices {
  final SpeechController _speech = SpeechController();
  final TtsService _tts = TtsService();
  final FaceCamera _faceCamera = FaceCamera();
  final PhonemeQualityModel _lips = PhonemeQualityModel();

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stopSpeaking() => _tts.stop();

  @override
  Future<bool> startRecording(BuildContext context) => _speech.onStartClicked(context);

  @override
  Future<PAResult> stopAndScore(String word) async {
    final file = await _speech.onStopClicked();
    if (file == null) throw StateError('Nothing was recorded.');
    return _speech.assess(file, word, GradingLevel.phoneme);
  }

  @override
  Future<bool> startCamera() async {
    try {
      return await _faceCamera.initialize();
    } catch (e) {
      debugPrint('camera error: $e');
      return false;
    }
  }

  @override
  CameraController? get camera => _faceCamera.isInitialized ? _faceCamera.controller : null;

  @override
  Future<List<String>> loadLipModel(String phoneme) async {
    await _lips.loadModel(phoneme);
    return _lips.missTips;
  }

  @override
  Future<void> startLipCapture() => _faceCamera.startFaceStream();

  @override
  Future<LipCheck?> stopLipCapture() async {
    final faceJson = await _faceCamera.stopFaceStream();
    try {
      final tip = _lips.getPhonemeFeedback(faceJson);
      if (tip == null) return null;
      debugPrint('lip model: ${_lips.lastLabel} $tip');
      return LipCheck(passed: _lips.lastWasCorrect, score: _lips.lastCorrectFraction, tip: tip);
    } catch (e) {
      debugPrint('lip model error: $e');
      return null;
    }
  }

  @override
  String get coachUrl => '$avatarBaseUrl/?embed=1&frame=0,0,1,1';

  @override
  void dispose() {
    _tts.dispose();
    _speech.dispose();
    _faceCamera.dispose();
    _lips.dispose();
  }
}
