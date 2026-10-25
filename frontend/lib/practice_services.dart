import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'avatar_view.dart';
import 'face_camera.dart';
import 'phoneme_classifier.dart';
import 'recorder_controller.dart';
import 'speech_controller.dart';
import 'speech_models.dart';
import 'stage4/follow_along.dart';
import 'stage4/golden_store.dart';
import 'stage4/mouth_matcher.dart';
import 'stage4/mouth_tracker.dart';
import 'tts_service.dart';
import 'voice_window.dart';

/// One sound attempt judged by the ONNX lip model.
class LipCheck {
  const LipCheck({
    required this.passed,
    required this.score,
    required this.tip,
    this.correctFrames = 0,
    this.frames = 0,
    this.heard = true,
  });

  /// The mic ran but heard no voice, so nothing was judged: the resting mouth would.
  const LipCheck.notHeard() : this(passed: false, score: 0, tip: '', heard: false);

  final bool passed;

  /// Share of the attempt's frames the model judged correct, 0 to 1.
  final double score;

  /// The model's feedback for its label, e.g. "Try rounding your lips more".
  final String tip;

  /// How many of the attempt's camera frames had the right lip shape.
  final int correctFrames;
  final int frames;

  final bool heard;
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

  /// Stage 4 (Menaka's follow-along): the matcher built from the bundled golden data, or null
  /// if it can't load.
  Future<MouthMatcher?> loadMatcher();

  /// Stage 4: the sounds of [word] and when the coach says each one.
  Future<List<FollowStep>> followSteps(String word);

  /// Stage 4: the camera moves to the mouth tracker, which calls [onFrame] for every frame
  /// (fast ML Kit, so movement over time is smooth). False without a camera.
  Future<bool> startMouthTracking(void Function(MouthFrame? frame) onFrame);

  /// Gives the camera back to the mirror.
  Future<void> stopMouthTracking();

  void dispose();
}

/// Makes the services for each Word Practice screen. Tests swap in fakes.
PracticeServices Function() createPracticeServices = LivePracticeServices.new;

class LivePracticeServices implements PracticeServices {
  final SpeechController _speech = SpeechController();
  final TtsService _tts = TtsService();
  final FaceCamera _faceCamera = FaceCamera();
  final PhonemeQualityModel _lips = PhonemeQualityModel();
  final RecordingService _mic = RecordingService();
  DateTime? _micStarted;
  MouthTracker? _tracker;

  // building the matcher from 7 MB of golden data takes a moment; once per app run
  static Future<MouthMatcher?>? _matcher;

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
  CameraController? get camera {
    final tracker = _tracker;
    if (tracker != null) return tracker.isInitialized ? tracker.controller : null;
    return _faceCamera.isInitialized ? _faceCamera.controller : null;
  }

  @override
  Future<List<String>> loadLipModel(String phoneme) async {
    await _lips.loadModel(phoneme);
    return _lips.missTips;
  }

  @override
  Future<void> startLipCapture() async {
    await _faceCamera.startFaceStream();
    // the mic only times the sound (see stopLipCapture); the audio stays on the phone
    try {
      await _mic.start();
      _micStarted = DateTime.now();
    } catch (e) {
      debugPrint('mic error: $e');
      _micStarted = null;
    }
  }

  @override
  Future<LipCheck?> stopLipCapture() async {
    final faceJson = await _faceCamera.stopFaceStream();
    final speaking = await _speakingTime();
    if (speaking.silent) return const LipCheck.notHeard();
    try {
      final tip = _lips.getPhonemeFeedback(faceJson, from: speaking.from, to: speaking.to);
      if (tip == null) return null;
      debugPrint('lip model: ${_lips.lastLabel} $tip');
      return LipCheck(
        passed: _lips.lastWasCorrect,
        score: _lips.lastCorrectFraction,
        tip: tip,
        correctFrames: _lips.lastCorrectFrames,
        frames: _lips.lastFrames,
      );
    } catch (e) {
      debugPrint('lip model error: $e');
      return null;
    }
  }

  /// When the child spoke during the sound attempt, from the recording, which is then
  /// deleted. [silent]: the mic ran and heard no voice. No times and not silent: the mic
  /// didn't run, so the whole attempt is judged.
  Future<({bool silent, DateTime? from, DateTime? to})> _speakingTime() async {
    const unknown = (silent: false, from: null, to: null);
    final started = _micStarted;
    _micStarted = null;
    if (started == null) return unknown;
    try {
      final file = await _mic.stop();
      if (file == null) return unknown;
      final bytes = await file.readAsBytes();
      await file.delete();
      final wav = readPcm16Wav(bytes);
      if (wav == null) return unknown;
      final voice = findVoice(wav.samples, wav.sampleRate);
      debugPrint('voice: ${voice == null ? 'none' : '${voice.start.inMilliseconds}-${voice.end.inMilliseconds} ms'}');
      if (voice == null) return (silent: true, from: null, to: null);
      return (silent: false, from: started.add(voice.start), to: started.add(voice.end));
    } catch (e) {
      debugPrint('voice window error: $e');
      return unknown;
    }
  }

  @override
  String get coachUrl => '$avatarBaseUrl/?embed=1&frame=0,0,1,1';

  @override
  Future<MouthMatcher?> loadMatcher() => _matcher ??= MouthMatcher.loadBundled().then<MouthMatcher?>(
        (m) => m,
        onError: (Object e) {
          debugPrint('stage 4 matcher: $e');
          _matcher = null;
          return null;
        },
      );

  @override
  Future<List<FollowStep>> followSteps(String word) => fetchFollowSteps(word);

  @override
  Future<bool> startMouthTracking(void Function(MouthFrame? frame) onFrame) async {
    await _faceCamera.release();
    final tracker = MouthTracker()..onFrame = onFrame;
    _tracker = tracker;
    return tracker.start();
  }

  @override
  Future<void> stopMouthTracking() async {
    final tracker = _tracker;
    _tracker = null;
    await tracker?.dispose();
    await startCamera();
  }

  @override
  void dispose() {
    _tracker?.dispose();
    _tts.dispose();
    _speech.dispose();
    _mic.dispose();
    _faceCamera.dispose();
    _lips.dispose();
  }
}
