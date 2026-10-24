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

  PAResult result(List<PhonemeAssessment> phonemes, {double accuracy = 0}) => PAResult(
        recognizedText: '',
        accuracyScore: accuracy,
        fluencyScore: 0,
        completenessScore: 0,
        prosodyScore: 0,
        pronunciationScore: 0,
        words: [
          WordAssessment(
            word: 'puh',
            accuracyScore: accuracy,
            errorType: 'None',
            phonemes: phonemes,
            timestamp: DateTime.now(),
          ),
        ],
      );

  test('single sounds are said like a teacher would', () {
    expect(soundPromptFor('p'), (text: 'puh', ipa: 'pʌ'));
    expect(soundPromptFor('s'), (text: 'sss', ipa: 'sss'));
    expect(soundPromptFor('u'), (text: 'too', ipa: 'u'));
    expect(soundPromptFor('?'), (text: '?', ipa: '?'));
  });

  test('consonants are practiced in a syllable with the word\'s own vowel', () {
    // "pop" = p ɑ p
    expect(soundPromptFor('p', after: 'ɑ'), (text: 'pah', ipa: 'pɑ'));
    expect(soundPromptFor('p', before: 'ɑ'), (text: 'ahp', ipa: 'ɑp'));
    expect(soundPromptFor('ɹ', before: 's', after: 'æ'), (text: 'ra', ipa: 'ɹæ'));
    // no vowel beside it: the sound on its own
    expect(soundPromptFor('s', after: 't'), (text: 'sss', ipa: 'sss'));
    // vowels are practiced on their own
    expect(soundPromptFor('u', before: 'b', after: 't'), (text: 'too', ipa: 'u'));
  });

  test('finds the sounds around the trouble sound', () {
    final p1 = _p('p', 40), a = _p('ɑ', 90), p2 = _p('p', 80);
    final r = result([p1, a, p2]);
    expect(neighbors(r, p1), (before: null, after: 'ɑ'));
    expect(neighbors(r, p2), (before: 'ɑ', after: null));
  });

  test('scores only the target sound, ignoring the added vowel', () {
    // "puh" said with a good /p/ and a mumbled "uh"
    expect(soundScore(result([_p('p', 85), _p('ʌ', 20)]), 'p'), 85);
    // best occurrence: the child says the sound once
    expect(soundScore(result([_p('s', 30), _p('s', 70)]), 's'), 70);
    // Azure didn't line the sound up: fall back to overall accuracy
    expect(soundScore(result([_p('t', 60)], accuracy: 42), 'p'), 42);
    expect(bestPhoneme(result([_p('t', 60)]), 'p'), isNull);
  });
}
