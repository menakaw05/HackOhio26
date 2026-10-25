import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/app_state.dart';
import 'package:frontend/data/mock/demo_seed.dart';
import 'package:frontend/data/models.dart';

void main() {
  test('selecting the demo learner loads their queue and profile', () {
    final state = AppState()..selectLearner('maya');
    expect(state.learner?.name, 'Maya');
    expect(state.queue.length, 8);
    expect(state.soundsToWorkOn.first.phoneme, 'r');
    expect(state.history, isNotEmpty);
  });

  test('new learner has empty data', () {
    final state = AppState()..selectLearner('sam');
    expect(state.queue.isEmpty, isTrue);
    expect(state.soundProfile, isEmpty);
  });

  test('adding words skips ones already queued and keeps the source', () {
    final state = AppState()..selectLearner('maya');
    final added = state.addWords(['frog', 'leaf', 'Fish'], WordSource.reading);
    expect(added, 2);
    final leaf = state.queue.items.firstWhere((w) => w.text == 'leaf');
    expect(leaf.source, WordSource.reading);
    expect(leaf.phonemes, ['l', 'i', 'f']);
  });

  test('reset restores the seeded queue', () {
    final state = AppState()..selectLearner('maya');
    state.queue.next();
    state.resetDemo();
    expect(state.queue.length, 8);
    expect(state.learner?.id, 'maya');
  });

  test('every seeded word has phonemes', () {
    for (final w in [...diagnosticWords, for (final p in DemoSeed.passages) ...p.mockResults.keys]) {
      expect(phonemesFor(w), isNotEmpty, reason: w);
    }
  });

  test('relative days', () {
    final now = DateTime(2026, 10, 24, 15);
    expect(relativeDay(DateTime(2026, 10, 24, 9), now: now), 'today');
    expect(relativeDay(DateTime(2026, 10, 23), now: now), 'yesterday');
    expect(relativeDay(DateTime(2026, 10, 20), now: now), '4 days ago');
  });
}
