// MOCK diagnostic results so the flow can be clicked through without the backend.
// Replaced by real per-sound scores from the pronunciation service later.
import '../models.dart';
import 'demo_seed.dart';

abstract final class MockDiagnostic {
  static const profile = [
    SoundScore('r', 0.45, 'red'),
    SoundScore('θ', 0.52, 'thumb'),
    SoundScore('ʃ', 0.68, 'ship'),
    SoundScore('l', 0.72, 'leaf'),
    SoundScore('s', 0.84, 'sun'),
    SoundScore('u', 0.9, 'boot'),
    SoundScore('k', 0.93, 'cat'),
    SoundScore('b', 0.95, 'ball'),
  ];

  /// Up to [perSound] seeded words containing each sound that isn't Strong yet.
  static List<String> practiceWordsFor(List<SoundScore> profile, {int perSound = 2}) {
    final words = <String>[];
    for (final s in profile.where((s) => s.level != SoundLevel.strong)) {
      words.addAll(demoPhonemes.entries
          .where((e) => e.value.contains(s.phoneme) && !words.contains(e.key))
          .take(perSound)
          .map((e) => e.key));
    }
    return words;
  }
}
