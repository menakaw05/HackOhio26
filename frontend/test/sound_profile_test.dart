import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models.dart';
import 'package:frontend/data/sound_profile.dart';

import 'fake_practice_services.dart';

void main() {
  test('averages each sound over its words, weakest first', () {
    final profile = profileFromScores({
      'red': scoreOf('red', [('ɹ', 40), ('ɛ', 90), ('d', 95)], accuracy: 70),
      'frog': scoreOf('frog', [('f', 90), ('ɹ', 60), ('ɑ', 88), ('ɡ', 92)], accuracy: 80),
    });
    expect(profile.first.phoneme, 'r'); // Azure's ɹ, spelled like the seeded words
    expect(profile.first.score, closeTo(0.5, 1e-9));
    expect(profile.first.exampleWord, 'red');
    expect(profile.first.level, SoundLevel.needsPractice);
    expect(profile.map((s) => s.score), orderedEquals([...profile.map((s) => s.score)]..sort()));
  });

  test('leaves out schwa, and nothing scored gives an empty profile', () {
    final profile = profileFromScores({
      'apple': scoreOf('apple', [('æ', 85), ('p', 70), ('ə', 30), ('l', 90)], accuracy: 75),
    });
    expect(profile.map((s) => s.phoneme), isNot(contains('ə')));
    expect(profileFromScores({}), isEmpty);
  });
}
