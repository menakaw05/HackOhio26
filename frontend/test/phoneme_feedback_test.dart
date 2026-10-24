import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/phoneme_feedback.dart';
import 'package:frontend/speech_models.dart';

PhonemeAssessment _p(String phoneme, double score, [List<String> heard = const []]) =>
    PhonemeAssessment(
      phoneme: phoneme,
      accuracyScore: score,
      nBestPhonemes: [
        for (final h in heard) PhonemeConfusion(phoneme: h, score: 50),
      ],
    );

PAResult _result(List<List<PhonemeAssessment>> words) => PAResult(
      recognizedText: '',
      accuracyScore: 0,
      fluencyScore: 0,
      completenessScore: 0,
      prosodyScore: 0,
      pronunciationScore: 0,
      words: [
        for (final w in words)
          WordAssessment(
            word: 'w',
            accuracyScore: 0,
            errorType: 'None',
            phonemes: w,
            timestamp: DateTime.now(),
          ),
      ],
    );

void main() {
  test('finds lowest-scoring phoneme across words', () {
    final r = _result([
      [_p('b', 90), _p('u', 40)],
      [_p('t', 70)],
    ]);
    expect(findWorstPhoneme(r)?.phoneme, 'u');
  });

  test('returns null when no phonemes were scored', () {
    expect(findWorstPhoneme(_result([[]])), isNull);
  });

  test('azure feedback mentions what it sounded like', () {
    expect(azureFeedbackFor(_p('t', 65, ['d', 't'])),
        'Almost! Your /t/ scored 65. It sounded more like /d/.');
    expect(azureFeedbackFor(_p('t', 30, ['t'])),
        "Let's keep working on it. Your /t/ scored 30.");
  });
}
