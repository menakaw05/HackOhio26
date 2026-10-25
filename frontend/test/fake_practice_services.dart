import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'package:frontend/practice_services.dart';
import 'package:frontend/speech_models.dart';
import 'package:frontend/stage4/follow_along.dart';
import 'package:frontend/stage4/golden_store.dart';
import 'package:frontend/stage4/mouth_matcher.dart';

/// Scripted stand-in for Azure, the camera, the lip model and the coach.
class FakePracticeServices implements PracticeServices {
  FakePracticeServices({
    List<PAResult>? scores,
    List<LipCheck?>? lipChecks,
    this.matcher,
    this.steps = const [],
  })  : scores = scores ?? [],
        lipChecks = lipChecks ?? [];

  /// Word scores and lip checks, used up in order.
  final List<PAResult> scores;
  final List<LipCheck?> lipChecks;

  final List<String> spoken = [];
  String? lipModel;

  /// Stage 4: the matcher and the word's sounds; feed camera frames through [onFrame].
  final MouthMatcher? matcher;
  final List<FollowStep> steps;
  void Function(MouthFrame? frame)? onFrame;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<bool> startRecording(BuildContext context) async => true;

  @override
  Future<PAResult> stopAndScore(String word) async => scores.removeAt(0);

  @override
  Future<bool> startCamera() async => false;

  @override
  CameraController? get camera => null;

  @override
  Future<List<String>> loadLipModel(String phoneme) async {
    lipModel = phoneme;
    return const ['Try rounding your lips more.'];
  }

  @override
  Future<void> startLipCapture() async {}

  @override
  Future<LipCheck?> stopLipCapture() async => lipChecks.removeAt(0);

  @override
  String? get coachUrl => null;

  @override
  Future<MouthMatcher?> loadMatcher() async => matcher;

  @override
  Future<List<FollowStep>> followSteps(String word) async => steps;

  @override
  Future<bool> startMouthTracking(void Function(MouthFrame? frame) onFrame) async {
    this.onFrame = onFrame;
    return true;
  }

  @override
  Future<void> stopMouthTracking() async => onFrame = null;

  @override
  void dispose() {}
}

/// An Azure result for [word] with a score per sound.
PAResult scoreOf(String word, List<(String, double)> sounds, {required double accuracy}) =>
    PAResult(
      recognizedText: word,
      accuracyScore: accuracy,
      fluencyScore: 100,
      completenessScore: 100,
      prosodyScore: 100,
      pronunciationScore: accuracy,
      words: [
        WordAssessment(
          word: word,
          accuracyScore: accuracy,
          errorType: 'None',
          phonemes: [
            for (final (phoneme, score) in sounds)
              PhonemeAssessment(phoneme: phoneme, accuracyScore: score, nBestPhonemes: const []),
          ],
          timestamp: DateTime.now(),
        ),
      ],
    );
