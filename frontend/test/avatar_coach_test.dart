import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/avatar_coach.dart';
import 'package:frontend/speech_models.dart';

PhonemeAssessment _p(String phoneme, double score, [List<String> heard = const []]) =>
    PhonemeAssessment(
      phoneme: phoneme,
      accuracyScore: score,
      nBestPhonemes: [
        for (final h in heard) PhonemeConfusion(phoneme: h, score: 50),
      ],
    );

void main() {
  test('maps IPA sounds to Azure visemes', () {
    expect(visemeFor('p'), 21);
    expect(visemeFor('ɹ'), 13);
    expect(visemeFor('u'), 7);
    expect(visemeFor('tʃ'), 16);
    expect(visemeFor('oʊ'), 8);
    expect(visemeFor('?'), isNull);
  });

  test('tongue sounds vs lip sounds', () {
    expect(isTongueSound('ɹ'), isTrue);
    expect(isTongueSound('θ'), isTrue);
    expect(isTongueSound('p'), isFalse);
    expect(isTongueSound('u'), isFalse);
  });

  test('exaggeration fades as accuracy rises', () {
    expect(boostGain(0), closeTo(1.6, 1e-9));
    expect(boostGain(50), closeTo(1.3, 1e-9));
    expect(boostGain(100), closeTo(1.0, 1e-9));
    expect(boostGain(120), closeTo(1.0, 1e-9));
  });

  test('boosts the visible movement for the sound', () {
    expect(boostFor('u', 1.4), {'mouthFunnel': 1.4, 'mouthPucker': 1.4});
    expect(boostFor('i', 1.2).keys, containsAll(['mouthStretchLeft', 'mouthStretchRight']));
    expect(boostFor('p', 1.4), isEmpty); // lips are sealed and held instead
    expect(boostFor('ɹ', 1.4), isEmpty);
  });

  test('touch-your-throat cue only for voicing swaps', () {
    expect(voicingCue(_p('b', 40, ['p'])), contains('should buzz'));
    expect(voicingCue(_p('p', 40, ['b'])), contains('just air'));
    expect(voicingCue(_p('p', 40, ['p'])), isNull);
    expect(voicingCue(_p('p', 40, ['t'])), isNull);
    expect(voicingCue(_p('p', 40)), isNull);
  });

  test('finds the lowest-scoring occurrence of the target sound', () {
    final result = PAResult(
      recognizedText: '',
      accuracyScore: 0,
      fluencyScore: 0,
      completenessScore: 0,
      prosodyScore: 0,
      pronunciationScore: 0,
      words: [
        WordAssessment(
          word: 'pop',
          accuracyScore: 0,
          errorType: 'None',
          phonemes: [_p('p', 90), _p('ɑ', 70), _p('p', 40)],
          timestamp: DateTime.now(),
        ),
      ],
    );
    expect(findPhoneme(result, 'p')!.accuracyScore, 40);
    expect(findPhoneme(result, 'm'), isNull);
  });
}
