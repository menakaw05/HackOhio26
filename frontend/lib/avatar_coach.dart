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

/// How to say one sound on its own, like a teacher would (the spellings
/// eLEXir's ice bridges game uses). [text] is what the child is shown and
/// the coach's text; [ipa] is exactly what the coach says (as plain text
/// "puh" comes out "pooh" and "sss" as "ess ess ess").
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
  'æ': (text: 'a', ipa: 'æ'), 'ɑ': (text: 'ah', ipa: 'ɑ'), 'ɔ': (text: 'aw', ipa: 'ɔ'),
  'ɛ': (text: 'eh', ipa: 'ɛ'), 'ɪ': (text: 'ih', ipa: 'ɪ'), 'i': (text: 'ee', ipa: 'i'),
  'ʊ': (text: 'oo', ipa: 'ʊ'), 'u': (text: 'oo', ipa: 'u'), 'ʌ': (text: 'uh', ipa: 'ʌ'),
  'ə': (text: 'uh', ipa: 'ə'), 'oʊ': (text: 'oh', ipa: 'oʊ'), 'eɪ': (text: 'ay', ipa: 'eɪ'),
  'aɪ': (text: 'eye', ipa: 'aɪ'), 'aʊ': (text: 'ow', ipa: 'aʊ'), 'ɔɪ': (text: 'oy', ipa: 'ɔɪ'),
  'ɝ': (text: 'her', ipa: 'ɝ'), 'ɚ': (text: 'her', ipa: 'ɝ'),
};

// Letters for a consonant or vowel inside a practice syllable ("p" + "ah").
const Map<String, String> _consonantLetters = {
  'p': 'p', 'b': 'b', 't': 't', 'd': 'd', 'k': 'k', 'g': 'g', 'ɡ': 'g',
  'f': 'f', 'v': 'v', 's': 's', 'z': 'z', 'm': 'm', 'n': 'n', 'l': 'l',
  'ɹ': 'r', 'w': 'w', 'j': 'y', 'h': 'h', 'ʃ': 'sh', 'ʒ': 'zh',
  'tʃ': 'ch', 'dʒ': 'j', 'θ': 'th', 'ð': 'th', 'ŋ': 'ng',
};
const Map<String, String> _vowelLetters = {
  'ɑ': 'ah', 'æ': 'a', 'ɛ': 'eh', 'e': 'ay', 'eɪ': 'ay', 'ɪ': 'i', 'i': 'ee',
  'u': 'oo', 'ʊ': 'oo', 'ʌ': 'uh', 'ə': 'uh', 'oʊ': 'oh', 'o': 'oh', 'ɔ': 'aw',
  'aɪ': 'eye', 'aʊ': 'ow', 'ɔɪ': 'oy', 'ɝ': 'er', 'ɚ': 'er',
};

bool isVowel(String ipa) => _vowelLetters.containsKey(ipa);

/// How to practice one sound. A consonant goes into a syllable with the vowel
/// next to it in the word, so it's said the way it is in the word: the /p/
/// at the start of "pop" becomes "pah" (consonant + vowel), the /p/ at the
/// end "ahp" (vowel + consonant). With no vowel beside it, or for a vowel,
/// the sound is practiced on its own ("puh", "sss", "oo").
SoundPrompt soundPromptFor(String ipa, {String? before, String? after}) {
  final c = _consonantLetters[ipa];
  if (c != null) {
    if (after != null && isVowel(after)) {
      return (text: '$c${_vowelLetters[after]}', ipa: '$ipa$after');
    }
    if (before != null && isVowel(before)) {
      return (text: '${_vowelLetters[before]}$c', ipa: '$before$ipa');
    }
  }
  return _soundPrompts[ipa] ?? (text: ipa, ipa: ipa);
}

/// The sounds just before and after [target] in the word Azure scored
/// ([target] must come from [result]).
({String? before, String? after}) neighbors(PAResult result, PhonemeAssessment target) {
  for (final word in result.words) {
    final i = word.phonemes.indexOf(target);
    if (i < 0) continue;
    String? at(int j) => j >= 0 && j < word.phonemes.length ? word.phonemes[j].phoneme : null;
    return (before: at(i - 1), after: at(i + 1));
  }
  return (before: null, after: null);
}
