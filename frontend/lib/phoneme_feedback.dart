import 'speech_models.dart';

/// Returns the lowest-scoring phoneme across all words in the result, or null if none were scored.
PhonemeAssessment? findWorstPhoneme(PAResult result) {
  PhonemeAssessment? worst;
  for (final word in result.words) {
    for (final p in word.phonemes) {
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
