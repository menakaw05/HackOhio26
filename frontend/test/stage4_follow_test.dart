import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/router.dart';
import 'package:frontend/stage4/follow_along.dart';
import 'package:frontend/stage4/golden_store.dart';
import 'package:frontend/stage4/mouth_matcher.dart';
import 'package:frontend/stage4/session_log.dart';
import 'screens_test.dart' show pumpAt;

void main() {
  final golden = parseGoldenFeatures(File(goldenAsset).readAsStringSync());
  final matcher = MouthMatcher.fromTakes(golden);
  const steps = [FollowStep('b', 130, 130), FollowStep('u', 270, 230), FollowStep('t', 510, 110)];

  /// Feeds a golden take of [ipa] as camera frames starting at [t0] ms. Returns true if any
  /// frame completed the sound.
  bool say(FollowAlongSession s, String ipa, int t0, {int take = 0}) {
    var passed = false;
    // the sound, then relaxing for half a second, at about 24 fps like the recordings
    final frames = [...golden[ipa]![take], for (var i = 0; i < 12; i++) golden[ipa]![take].last];
    for (var i = 0; i < frames.length; i++) {
      passed |= s.addFrame(MouthFrame(t: t0 + i * 42, features: frames[i], contours: const {}));
    }
    return passed;
  }

  test('without the avatar, each sound passes in turn and the word finishes', () {
    final s = FollowAlongSession(matcher: matcher, steps: steps, useAvatar: false)..start();
    expect(s.phase, FollowPhase.waiting);
    expect(s.current!.phoneme, 'b');

    var t = 0;
    for (final step in steps) {
      expect(say(s, step.phoneme, t), isTrue, reason: step.phoneme);
      expect(s.phase, FollowPhase.passed);
      s.advance();
      t += 5000;
    }
    expect(s.phase, FollowPhase.done);
  });

  test('with the avatar, a sound starts when the avatar pauses and the avatar continues after', () {
    final s = FollowAlongSession(matcher: matcher, steps: steps, useAvatar: true)..start();
    expect(s.phase, FollowPhase.coach);
    expect(say(s, 'b', 0), isFalse, reason: 'not scoring while the coach talks');

    s.coachPaused(0);
    expect(s.phase, FollowPhase.waiting);
    expect(say(s, 'b', 1000), isTrue);
    s.advance();
    expect(s.phase, FollowPhase.coach);
    expect(s.index, 1);

    s.coachFinished();
    expect(s.phase, FollowPhase.done);
  });

  test('a still face never passes, and the score has to hold above the threshold', () {
    final s = FollowAlongSession(matcher: matcher, steps: steps, useAvatar: false)..start();
    final rest = golden['b']!.first.first;
    for (var i = 0; i < 60; i++) {
      expect(s.addFrame(MouthFrame(t: i * 42, features: rest, contours: const {})), isFalse);
    }
    expect(s.score, 0);

    // a new attempt: a 'b' take the matcher wasn't built with (take 0 is an outlier, so use 1)
    final heldOut = MouthMatcher.fromTakes({
      ...golden,
      'b': [for (var k = 0; k < golden['b']!.length; k++) if (k != 1) golden['b']![k]],
    });
    FollowAlongSession session(double threshold) =>
        FollowAlongSession(matcher: heldOut, steps: steps, useAvatar: false, threshold: threshold)
          ..start();
    expect(say(session(0.999), 'b', 0, take: 1), isFalse, reason: 'too strict to pass');
    expect(say(session(0.5), 'b', 0, take: 1), isTrue);
  });

  testWidgets('stage 4 screen renders without the avatar configured', (tester) async {
    await pumpAt(tester, Routes.stage4, settle: false);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Stage 4: follow along'), findsOneWidget);
    expect(find.text('Step through the sounds without the avatar'), findsOneWidget);
    expect(find.text('Tuning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('manual mode scores but never auto-passes; Next sound moves on and everything is logged', () {
    final s = FollowAlongSession(matcher: matcher, steps: steps, useAvatar: false, autoPass: false)
      ..start();
    final log = Stage4SessionLog(
      word: 'boot',
      steps: steps,
      useAvatar: false,
      threshold: 0.5,
      windowMs: 750,
      config: matcher.config,
    )..event(0, 'start');

    final frames = [...golden['b']!.first, for (var i = 0; i < 12; i++) golden['b']!.first.last];
    var maxScore = 0.0;
    for (var i = 0; i < frames.length; i++) {
      final f = MouthFrame(t: i * 42, features: frames[i], contours: const {'face': [1, 2]});
      expect(s.addFrame(f), isFalse);
      maxScore = s.score > maxScore ? s.score : maxScore;
      log.frame(i * 42, f, s);
    }
    log.frame(999, null, s); // a frame with no face
    expect(maxScore, greaterThan(0.5), reason: 'still scored');
    expect(s.phase, FollowPhase.waiting);

    s.manualPass();
    log.event(1000, 'next', index: 0);
    s.advance();
    expect(s.current!.phoneme, 'u');

    final json = log.toJson();
    expect(json['word'], 'boot');
    expect((json['steps'] as List).length, 3);
    expect((json['events'] as List).last, {'t': 1000, 'type': 'next', 'index': 0});
    final logged = json['frames'] as List;
    expect(logged.length, frames.length + 1);
    expect((logged.first as Map)['f'], hasLength(5));
    expect((logged.first as Map)['c'], {'face': [1, 2]});
    expect((logged.last as Map).containsKey('f'), isFalse);
    expect((json['config'] as Map)['trimFraction'], matcher.config.trimFraction);
  });

  test('barely-visible sounds pass on their own after their usual duration', () {
    expect(
      [for (final p in matcher.phonemes) if (matcher.barelyVisible(p)) p]..sort(),
      (['ŋ', 't', 'z', 'ð', 'l', 'ʒ', 'd', 'n', 'ʃ']..sort()),
    );
    final wait = matcher.typicalDuration('t')!.inMilliseconds;
    expect(wait, inInclusiveRange(600, 1300));

    // still face on /t/ (the third sound of "boot")
    final s = FollowAlongSession(matcher: matcher, steps: steps, useAvatar: false)..start();
    s
      ..manualPass()
      ..advance()
      ..manualPass()
      ..advance();
    expect(s.current!.phoneme, 't');
    expect(s.autoPassing, isTrue);
    final rest = golden['t']!.first.first;
    var passedAt = -1;
    for (var t = 0; t <= wait + 200; t += 42) {
      if (s.addFrame(MouthFrame(t: t, features: rest, contours: const {}))) passedAt = t;
    }
    expect(passedAt, greaterThanOrEqualTo(wait));
    expect(passedAt, lessThan(wait + 84));

    // manual (debug) mode never auto-passes
    final manual = FollowAlongSession(
        matcher: matcher, steps: const [FollowStep('t', 0, 100)], useAvatar: false, autoPass: false)
      ..start();
    for (var t = 0; t <= wait * 2; t += 42) {
      expect(manual.addFrame(MouthFrame(t: t, features: rest, contours: const {})), isFalse);
    }
    expect(manual.phase, FollowPhase.waiting);

    // a visible sound is still matched, not timed
    final b = FollowAlongSession(matcher: matcher, steps: const [FollowStep('b', 0, 100)], useAvatar: false)
      ..start();
    expect(b.autoPassing, isFalse);
    for (var t = 0; t <= 3000; t += 42) {
      expect(b.addFrame(MouthFrame(t: t, features: rest, contours: const {})), isFalse);
    }
  });
}
