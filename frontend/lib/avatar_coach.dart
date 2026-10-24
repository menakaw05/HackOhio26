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

/// The child's attempt at [phoneme] in [result]: the lowest-scoring
/// occurrence, or null if Azure didn't score that sound.
PhonemeAssessment? findPhoneme(PAResult result, String phoneme) {
  PhonemeAssessment? worst;
  for (final word in result.words) {
    for (final p in word.phonemes) {
      if (p.phoneme == phoneme && (worst == null || p.accuracyScore < worst.accuracyScore)) {
        worst = p;
      }
    }
  }
  return worst;
}
