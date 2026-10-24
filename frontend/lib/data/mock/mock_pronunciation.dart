// MOCK pronunciation results so Word Practice can be clicked through without the backend.
// Replaced by the real Azure + face-model services when they're wired in.
import '../../widgets/feedback_banner.dart';
import '../models.dart';

/// Placeholder mouth-shape hints per sound.
const _coaching = {
  'u': 'Round your lips a little more.',
  'r': 'Try curling your tongue back a little.',
  'θ': 'Let your tongue peek out between your teeth.',
  'ʃ': 'Push your lips forward, like a quiet "shh".',
  'l': 'Touch the tip of your tongue behind your top teeth.',
  's': 'Keep your teeth close together.',
};

abstract final class MockPronunciation {
  /// First attempt is "Almost!" on one sound; later attempts are "Great!".
  static AttemptResult assess(WordItem word, int attemptIndex) {
    final focusIndex = word.phonemes.isEmpty ? -1 : word.phonemes.length ~/ 2;
    final success = attemptIndex > 0 || word.phonemes.isEmpty;
    final focusPhoneme = focusIndex >= 0 ? word.phonemes[focusIndex] : null;

    return AttemptResult(
      wordId: word.id,
      kind: success ? FeedbackKind.success : FeedbackKind.almost,
      phonemeResults: [
        for (var i = 0; i < word.phonemes.length; i++)
          PhonemeResult(
            word.phonemes[i],
            !success && i == focusIndex ? FeedbackKind.almost : FeedbackKind.success,
          ),
      ],
      coaching: success
          ? 'You said "${word.text}" clearly!'
          : (_coaching[focusPhoneme] ?? 'Listen once more, then give it another go.'),
      timestamp: DateTime.now(),
    );
  }
}
