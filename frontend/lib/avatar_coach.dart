import 'speech_models.dart';

// Stage 3 helpers: which avatar mouth shape to hold and which movement to
// exaggerate for a trouble sound. Sounds are Azure's IPA phonemes.

/// Azure viseme ids (en-US viseme table) for IPA phonemes.
const Map<String, int> _visemes = {
  'æ': 1, 'ə': 1, 'ʌ': 1,
  'ɑ': 2, 'ɔ': 3, 'ɛ': 4, 'e': 4, 'eɪ': 4, 'ʊ': 4, 'ɝ': 5, 'ɚ': 5,
  'j': 6, 'i': 6, 'ɪ': 6, 'w': 7, 'u': 7, 'o': 8, 'oʊ': 8,
  'aʊ': 9, 'ɔɪ': 10, 'aɪ': 11, 'h': 12, 'ɹ': 13, 'l': 14,
  's': 15, 'z': 15, 'ʃ': 16, 'tʃ': 16, 'dʒ': 16, 'ʒ': 16,
  'ð': 17, 'f': 18, 'v': 18, 'd': 19, 't': 19, 'n': 19, 'θ': 19,
  'k': 20, 'g': 20, 'ɡ': 20, 'ŋ': 20, 'p': 21, 'b': 21, 'm': 21,
};

/// Visemes for sounds shaped mainly by the tongue, which the camera can't check.
const Set<int> _tongueVisemes = {5, 13, 14, 15, 16, 17, 19, 20};

/// Azure viseme id for an IPA phoneme, or null if unknown.
int? visemeFor(String ipa) =>
    _visemes[ipa] ?? (ipa.isEmpty ? null : _visemes[ipa.substring(0, 1)]);

bool isTongueSound(String ipa) => _tongueVisemes.contains(visemeFor(ipa));

/// Exaggeration fades as the child gets closer: 1 + k * (1 - accuracy/100),
/// where accuracy is Azure's 0-100 score for the sound.
double boostGain(double accuracy, {double k = 0.6}) =>
    1 + k * (1 - (accuracy / 100).clamp(0.0, 1.0));

/// ARKit face channels to exaggerate for the sound's visible movement.
/// Lip closure (p, b, m) isn't boosted: the avatar seals and holds the lips.
Map<String, double> boostFor(String ipa, double gain) {
  switch (visemeFor(ipa)) {
    case 3 || 7 || 8 || 9 || 10: // rounded lips
      return {'mouthFunnel': gain, 'mouthPucker': gain};
    case 6: // spread lips
      return {'mouthStretchLeft': gain, 'mouthStretchRight': gain};
    case 1 || 2 || 11: // open jaw
      return {'jawOpen': gain};
    case 18: // lower lip to top teeth
      return {'mouthRollLower': gain};
    default:
      return {};
  }
}

const Map<String, String> _voicingPartner = {
  'p': 'b', 'b': 'p', 't': 'd', 'd': 't', 'k': 'g', 'g': 'k', 'ɡ': 'k',
  'f': 'v', 'v': 'f', 's': 'z', 'z': 's', 'θ': 'ð', 'ð': 'θ',
  'ʃ': 'ʒ', 'ʒ': 'ʃ', 'tʃ': 'dʒ', 'dʒ': 'tʃ',
};
const Set<String> _voiced = {'b', 'd', 'g', 'ɡ', 'v', 'z', 'ð', 'ʒ', 'dʒ'};

/// "Touch your throat" cue when Azure heard the voiced/voiceless partner of
/// the target (p for b, s for z, ...), otherwise null.
String? voicingCue(PhonemeAssessment p) {
  if (p.nBestPhonemes.isEmpty) return null;
  final heard = p.nBestPhonemes.first.phoneme;
  if (_voicingPartner[p.phoneme] != heard) return null;
  return _voiced.contains(p.phoneme)
      ? 'Touch your throat: /${p.phoneme}/ should buzz.'
      : 'Touch your throat: /${p.phoneme}/ should not buzz, just air.';
}

/// How to say one sound on its own, like a teacher would.
/// [text] is the reference Azure scores the child against (the spellings
/// eLEXir's ice bridges game uses: "p" alone would be scored as the letter
/// name "pee"); vowels use a short host word and only the vowel is scored.
/// [ipa] is exactly what the coach says (as plain text "puh" comes out
/// "pooh" and "sss" as "ess ess ess").
typedef SoundPrompt = ({String text, String ipa});

const Map<String, SoundPrompt> _soundPrompts = {
  // stops: unsayable alone, so they take a short "uh"
  'p': (text: 'puh', ipa: 'pʌ'), 'b': (text: 'buh', ipa: 'bʌ'),
  't': (text: 'tuh', ipa: 'tʌ'), 'd': (text: 'duh', ipa: 'dʌ'),
  'k': (text: 'kuh', ipa: 'kʌ'), 'g': (text: 'guh', ipa: 'ɡʌ'), 'ɡ': (text: 'guh', ipa: 'ɡʌ'),
  'tʃ': (text: 'chuh', ipa: 'tʃʌ'), 'dʒ': (text: 'juh', ipa: 'dʒʌ'),
  // continuants: held
  'f': (text: 'fff', ipa: 'fff'), 'v': (text: 'vvv', ipa: 'vvv'),
  's': (text: 'sss', ipa: 'sss'), 'z': (text: 'zzz', ipa: 'zzz'),
  'm': (text: 'mmm', ipa: 'mmm'), 'n': (text: 'nnn', ipa: 'nnn'),
  'ʃ': (text: 'shh', ipa: 'ʃʃʃ'), 'θ': (text: 'thh', ipa: 'θθθ'), 'ð': (text: 'the', ipa: 'ðʌ'),
  'l': (text: 'luh', ipa: 'lʌ'), 'ɹ': (text: 'ruh', ipa: 'ɹʌ'), 'w': (text: 'wuh', ipa: 'wʌ'),
  'j': (text: 'yuh', ipa: 'jʌ'), 'h': (text: 'huh', ipa: 'hʌ'), 'ŋ': (text: 'ng', ipa: 'ŋ'),
  // vowels
  'æ': (text: 'at', ipa: 'æ'), 'ɑ': (text: 'ah', ipa: 'ɑ'), 'ɔ': (text: 'aw', ipa: 'ɔ'),
  'ɛ': (text: 'eh', ipa: 'ɛ'), 'ɪ': (text: 'it', ipa: 'ɪ'), 'i': (text: 'ee', ipa: 'i'),
  'ʊ': (text: 'put', ipa: 'ʊ'), 'u': (text: 'too', ipa: 'u'), 'ʌ': (text: 'uh', ipa: 'ʌ'),
  'ə': (text: 'uh', ipa: 'ə'), 'oʊ': (text: 'oh', ipa: 'oʊ'), 'eɪ': (text: 'ay', ipa: 'eɪ'),
  'aɪ': (text: 'eye', ipa: 'aɪ'), 'aʊ': (text: 'ow', ipa: 'aʊ'), 'ɔɪ': (text: 'oy', ipa: 'ɔɪ'),
  'ɝ': (text: 'her', ipa: 'ɝ'), 'ɚ': (text: 'her', ipa: 'ɝ'),
};

SoundPrompt soundPromptFor(String ipa) => _soundPrompts[ipa] ?? (text: ipa, ipa: ipa);

/// Single sounds are hard for speech scoring, so the bar is lower than for
/// words (ice bridges uses the same 50).
const double soundPassScore = 50;

/// Score for a single-sound attempt: Azure's best score for the target sound
/// (the child says it once), or the overall accuracy if Azure didn't line the
/// sound up.
double soundScore(PAResult result, String phoneme) =>
    bestPhoneme(result, phoneme)?.accuracyScore ?? result.accuracyScore;

/// The best-scoring occurrence of [phoneme] in [result], or null.
PhonemeAssessment? bestPhoneme(PAResult result, String phoneme) {
  PhonemeAssessment? best;
  for (final word in result.words) {
    for (final p in word.phonemes) {
      if (p.phoneme == phoneme && (best == null || p.accuracyScore > best.accuracyScore)) {
        best = p;
      }
    }
  }
  return best;
}
