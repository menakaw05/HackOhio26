import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'package:frontend/practice_services.dart';
import 'package:frontend/speech_models.dart';

/// Scripted stand-in for Azure, the camera, the lip model and the coach.
class FakePracticeServices implements PracticeServices {
  FakePracticeServices({List<PAResult>? scores, List<LipCheck?>? lipChecks})
      : scores = scores ?? [],
        lipChecks = lipChecks ?? [];

  /// Word scores and lip checks, used up in order.
  final List<PAResult> scores;
  final List<LipCheck?> lipChecks;

  final List<String> spoken = [];
  String? lipModel;

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
