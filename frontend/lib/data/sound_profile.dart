import '../speech_models.dart';
import 'models.dart';

// Azure's IPA spelling -> the seeded words' spelling, so profile sounds match those words.
const _seedSpelling = {'ɹ': 'r'};

/// A sound profile from the Diagnostic's Azure results, keyed by word: each sound's
/// average accuracy (0-1) over the words it was in, weakest first, with the first of those
/// words as its example. Schwa is left out; it's too weak a vowel to practice on its own.
List<SoundScore> profileFromScores(Map<String, PAResult> scoresByWord) {
  final totals = <String, ({double sum, int count, String word})>{};
  for (final MapEntry(key: word, value: result) in scoresByWord.entries) {
    for (final w in result.words) {
      for (final p in w.phonemes) {
        final sound = _seedSpelling[p.phoneme] ?? p.phoneme;
        if (sound == 'ə') continue;
        final t = totals[sound];
        totals[sound] = (
          sum: (t?.sum ?? 0) + p.accuracyScore,
          count: (t?.count ?? 0) + 1,
          word: t?.word ?? word,
        );
      }
    }
  }
  return [
    for (final MapEntry(key: sound, value: t) in totals.entries)
      SoundScore(sound, t.sum / t.count / 100, t.word),
  ]..sort((a, b) => a.score.compareTo(b.score));
}
