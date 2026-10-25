/// Azure's en-US IPA phoneme set, with the exact symbols Azure returns (checked against real
/// Azure output: r is ɹ, g is plain ASCII g, and r-colored vowels like ɑɹ are one phoneme).
enum PhonemeGroup {
  consonant('Consonants'),
  vowel('Vowels'),
  rColored('R-colored vowels (optional)');

  const PhonemeGroup(this.label);

  final String label;
}

class GoldenPhoneme {
  const GoldenPhoneme(this.ipa, this.example, this.group);

  final String ipa;
  final String example;
  final PhonemeGroup group;
}

const goldenPhonemes = [
  GoldenPhoneme('p', 'pop', PhonemeGroup.consonant),
  GoldenPhoneme('b', 'boot', PhonemeGroup.consonant),
  GoldenPhoneme('m', 'moon', PhonemeGroup.consonant),
  GoldenPhoneme('w', 'water', PhonemeGroup.consonant),
  GoldenPhoneme('f', 'fish', PhonemeGroup.consonant),
  GoldenPhoneme('v', 'van', PhonemeGroup.consonant),
  GoldenPhoneme('θ', 'thumb', PhonemeGroup.consonant),
  GoldenPhoneme('ð', 'that', PhonemeGroup.consonant),
  GoldenPhoneme('t', 'top', PhonemeGroup.consonant),
  GoldenPhoneme('d', 'dog', PhonemeGroup.consonant),
  GoldenPhoneme('n', 'nose', PhonemeGroup.consonant),
  GoldenPhoneme('s', 'sun', PhonemeGroup.consonant),
  GoldenPhoneme('z', 'zoo', PhonemeGroup.consonant),
  GoldenPhoneme('l', 'leaf', PhonemeGroup.consonant),
  GoldenPhoneme('ɹ', 'red', PhonemeGroup.consonant),
  GoldenPhoneme('ʃ', 'ship', PhonemeGroup.consonant),
  GoldenPhoneme('ʒ', 'measure', PhonemeGroup.consonant),
  GoldenPhoneme('tʃ', 'chair', PhonemeGroup.consonant),
  GoldenPhoneme('dʒ', 'jump', PhonemeGroup.consonant),
  GoldenPhoneme('j', 'yes', PhonemeGroup.consonant),
  GoldenPhoneme('k', 'cat', PhonemeGroup.consonant),
  GoldenPhoneme('g', 'go', PhonemeGroup.consonant),
  GoldenPhoneme('ŋ', 'ring', PhonemeGroup.consonant),
  GoldenPhoneme('h', 'hat', PhonemeGroup.consonant),
  GoldenPhoneme('i', 'beat', PhonemeGroup.vowel),
  GoldenPhoneme('ɪ', 'bit', PhonemeGroup.vowel),
  GoldenPhoneme('eɪ', 'day', PhonemeGroup.vowel),
  GoldenPhoneme('ɛ', 'bed', PhonemeGroup.vowel),
  GoldenPhoneme('æ', 'cat', PhonemeGroup.vowel),
  GoldenPhoneme('ɑ', 'hot', PhonemeGroup.vowel),
  GoldenPhoneme('ʌ', 'cup', PhonemeGroup.vowel),
  GoldenPhoneme('ə', 'about', PhonemeGroup.vowel),
  GoldenPhoneme('ɔ', 'thought', PhonemeGroup.vowel),
  GoldenPhoneme('oʊ', 'boat', PhonemeGroup.vowel),
  GoldenPhoneme('ʊ', 'book', PhonemeGroup.vowel),
  GoldenPhoneme('u', 'boot', PhonemeGroup.vowel),
  GoldenPhoneme('aɪ', 'bite', PhonemeGroup.vowel),
  GoldenPhoneme('aʊ', 'cow', PhonemeGroup.vowel),
  GoldenPhoneme('ɔɪ', 'boy', PhonemeGroup.vowel),
  GoldenPhoneme('ɝ', 'bird', PhonemeGroup.vowel),
  GoldenPhoneme('ɚ', 'butter', PhonemeGroup.vowel),
  GoldenPhoneme('ɑɹ', 'car', PhonemeGroup.rColored),
  GoldenPhoneme('ɛɹ', 'air', PhonemeGroup.rColored),
  GoldenPhoneme('ɪɹ', 'ear', PhonemeGroup.rColored),
  GoldenPhoneme('ɔɹ', 'door', PhonemeGroup.rColored),
  GoldenPhoneme('aɪɹ', 'fire', PhonemeGroup.rColored),
  GoldenPhoneme('aʊɹ', 'hour', PhonemeGroup.rColored),
];

GoldenPhoneme? goldenPhonemeFor(String ipa) =>
    goldenPhonemes.where((p) => p.ipa == ipa).firstOrNull;
