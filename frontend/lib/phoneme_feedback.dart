import 'phoneme_classifier.dart';
import 'speech_models.dart';

/// The sound to practice after a missed word: the lowest-scoring sound the camera can check
/// (a lip model's), if one scored below [passScore]; otherwise the lowest-scoring sound. So the
/// "a" in "apple" goes to the A model even when the /l/ scored lower.
PhonemeAssessment? findTroublePhoneme(PAResult result, {double passScore = 80}) {
  final checkable = findWorstPhoneme(result, only: PhonemeQualityModel.hasModelFor);
  if (checkable != null && checkable.accuracyScore < passScore) return checkable;
  return findWorstPhoneme(result);
}

/// Azure leaves out the sounds when the word was far off ("kit" for "cat"). Then the word's
/// own [phonemes] stand in, each with the word's score, so practice can still pick one.
PAResult withWordSounds(PAResult result, List<String> phonemes) {
  if (phonemes.isEmpty || result.words.any((w) => w.phonemes.isNotEmpty)) return result;
  final word = result.words.firstOrNull;
  return PAResult(
    recognizedText: result.recognizedText,
    accuracyScore: result.accuracyScore,
    fluencyScore: result.fluencyScore,
    completenessScore: result.completenessScore,
    prosodyScore: result.prosodyScore,
    pronunciationScore: result.pronunciationScore,
    words: [
      WordAssessment(
        word: word?.word ?? '',
        accuracyScore: word?.accuracyScore ?? result.accuracyScore,
        errorType: word?.errorType ?? 'None',
        phonemes: [
          for (final p in phonemes)
            PhonemeAssessment(phoneme: p, accuracyScore: result.accuracyScore, nBestPhonemes: const []),
        ],
        timestamp: word?.timestamp ?? DateTime.now(),
      ),
    ],
  );
}

/// Returns the lowest-scoring phoneme across all words in the result (among those [only]
/// accepts, if given), or null if none were scored.
PhonemeAssessment? findWorstPhoneme(PAResult result, {bool Function(String phoneme)? only}) {
  PhonemeAssessment? worst;
  for (final word in result.words) {
    for (final p in word.phonemes) {
      if (only != null && !only(p.phoneme)) continue;
      if (worst == null || p.accuracyScore < worst.accuracyScore) {
        worst = p;
      }
    }
  }
  return worst;
}

/// Feedback built from the original Azure word attempt, used when there's no face model for the phoneme.
String azureFeedbackFor(PhonemeAssessment p) {
  final score = p.accuracyScore.toStringAsFixed(0);
  final opener = p.accuracyScore >= 60 ? 'Almost!' : "Let's keep working on it.";

  // NBestPhonemes are what Azure thought it heard, best match first
  final heard = p.nBestPhonemes.isNotEmpty ? p.nBestPhonemes.first.phoneme : null;
  final soundedLike =
      heard != null && heard != p.phoneme ? ' It sounded more like /$heard/.' : '';

  return '$opener Your /${p.phoneme}/ scored $score.$soundedLike';
}
