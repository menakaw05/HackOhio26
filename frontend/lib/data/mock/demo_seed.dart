// SAMPLE DATA for demos and wireframes. Nothing in this file comes from a real learner or a
// real assessment; screens that show it carry a "Sample data" badge.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../widgets/feedback_banner.dart';
import '../models.dart';

/// IPA phonemes for the seeded words, matching Azure's IPA output.
const Map<String, List<String>> demoPhonemes = {
  'boot': ['b', 'u', 't'],
  'moon': ['m', 'u', 'n'],
  'food': ['f', 'u', 'd'],
  'blue': ['b', 'l', 'u'],
  'spoon': ['s', 'p', 'u', 'n'],
  'zoo': ['z', 'u'],
  'ship': ['ʃ', 'ɪ', 'p'],
  'fish': ['f', 'ɪ', 'ʃ'],
  'shell': ['ʃ', 'ɛ', 'l'],
  'rabbit': ['r', 'æ', 'b', 'ɪ', 't'],
  'red': ['r', 'ɛ', 'd'],
  'rain': ['r', 'eɪ', 'n'],
  'frog': ['f', 'r', 'ɑ', 'ɡ'],
  'tree': ['t', 'r', 'i'],
  'thumb': ['θ', 'ʌ', 'm'],
  'three': ['θ', 'r', 'i'],
  'bath': ['b', 'æ', 'θ'],
  'sun': ['s', 'ʌ', 'n'],
  'star': ['s', 't', 'ɑ', 'r'],
  'snake': ['s', 'n', 'eɪ', 'k'],
  'leaf': ['l', 'i', 'f'],
  'lake': ['l', 'eɪ', 'k'],
  'light': ['l', 'aɪ', 't'],
  'lotus': ['l', 'oʊ', 't', 'ə', 's'],
  'ball': ['b', 'ɔ', 'l'],
  'cat': ['k', 'æ', 't'],
  'duck': ['d', 'ʌ', 'k'],
  'wagon': ['w', 'æ', 'ɡ', 'ə', 'n'],
  'lunch': ['l', 'ʌ', 'n', 'tʃ'],
  'jumped': ['dʒ', 'ʌ', 'm', 'p', 't'],
  'stars': ['s', 't', 'ɑ', 'r', 'z'],
  'hopped': ['h', 'ɑ', 'p', 't'],
  'green': ['ɡ', 'r', 'i', 'n'],
  'road': ['r', 'oʊ', 'd'],
  'ride': ['r', 'aɪ', 'd'],
  'bumpy': ['b', 'ʌ', 'm', 'p', 'i'],
};

List<String> phonemesFor(String word) =>
    demoPhonemes[word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')] ?? const [];

/// The 12 words the Diagnostic walks through.
const diagnosticWords = [
  'sun', 'ship', 'red', 'boot', 'thumb', 'cat',
  'leaf', 'zoo', 'frog', 'light', 'ball', 'duck',
];

class DemoProfile {
  DemoProfile({
    required this.learner,
    required this.queue,
    required this.soundProfile,
    required this.trends,
    required this.mastered,
    required this.lessons,
    required this.history,
    required this.activity,
  });

  final Learner learner;
  final List<WordItem> queue;
  final List<SoundScore> soundProfile;
  final List<SoundTrend> trends;
  final List<String> mastered;
  final List<LessonNode> lessons;
  final List<DayActivity> history;
  final List<ActivityEntry> activity;
}

abstract final class DemoSeed {
  static List<DemoProfile> profiles({DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    return [_maya(today), _leo(today), _sam()];
  }

  static WordItem word(String text, WordSource source, DateTime addedAt) => WordItem(
        id: '${source.name}-$text-${addedAt.millisecondsSinceEpoch}',
        text: text,
        phonemes: phonemesFor(text),
        source: source,
        addedAt: addedAt,
      );

  static const _lessons = [
    LessonNode(id: 'oo', title: 'Long oo', sound: 'u', status: LessonStatus.done,
        words: ['boot', 'moon', 'spoon']),
    LessonNode(id: 'sh', title: 'Sh sounds', sound: 'ʃ', status: LessonStatus.done,
        words: ['ship', 'fish', 'shell']),
    LessonNode(id: 'r', title: 'Roaring r', sound: 'r', status: LessonStatus.current,
        words: ['red', 'rain', 'rabbit']),
    LessonNode(id: 'th', title: 'Tongue th', sound: 'θ', status: LessonStatus.locked,
        words: ['thumb', 'three', 'bath']),
    LessonNode(id: 's', title: 'S blends', sound: 's', status: LessonStatus.locked,
        words: ['star', 'snake', 'spoon']),
    LessonNode(id: 'l', title: 'Lazy l', sound: 'l', status: LessonStatus.locked,
        words: ['leaf', 'lake', 'light']),
  ];

  /// Demo learner: 4 weeks of history, a 12-day streak, an improving r and th.
  static DemoProfile _maya(DateTime today) {
    final rng = math.Random(7);
    final history = [
      for (var i = 27; i >= 0; i--)
        // practiced every day for the last 12 days, most days before that
        if (i < 12 || rng.nextDouble() > 0.3)
          DayActivity(today.subtract(Duration(days: i)), 8 + rng.nextInt(12), 6 + rng.nextInt(10)),
    ];
    DateTime d(int days) => today.subtract(Duration(days: days));
    return DemoProfile(
      learner: const Learner(id: 'maya', name: 'Maya', colorIndex: 1, streak: 12, weeklyGoalMinutes: 60),
      queue: [
        word('rabbit', WordSource.reading, d(1)),
        word('frog', WordSource.reading, d(1)),
        word('thumb', WordSource.diagnostic, d(3)),
        word('red', WordSource.diagnostic, d(3)),
        word('three', WordSource.assigned, d(2)),
        word('moon', WordSource.lookAndSay, d(0)),
        word('shell', WordSource.manual, d(0)),
        word('rain', WordSource.assigned, d(2)),
      ],
      soundProfile: const [
        SoundScore('r', 0.48, 'red'),
        SoundScore('θ', 0.55, 'thumb'),
        SoundScore('ʃ', 0.7, 'ship'),
        SoundScore('l', 0.74, 'leaf'),
        SoundScore('s', 0.86, 'sun'),
        SoundScore('u', 0.9, 'boot'),
        SoundScore('k', 0.92, 'cat'),
        SoundScore('b', 0.95, 'ball'),
      ],
      trends: const [
        SoundTrend('r', [0.3, 0.36, 0.42, 0.48]),
        SoundTrend('θ', [0.38, 0.45, 0.5, 0.55]),
        SoundTrend('ʃ', [0.5, 0.58, 0.66, 0.7]),
        SoundTrend('u', [0.68, 0.78, 0.86, 0.9]),
      ],
      mastered: const ['u', 'b', 'k', 's', 'm'],
      lessons: _lessons,
      history: history,
      activity: [
        ActivityEntry('moon', WordSource.lookAndSay, d(0), FeedbackKind.success),
        ActivityEntry('rabbit', WordSource.reading, d(0), FeedbackKind.almost),
        ActivityEntry('red', WordSource.diagnostic, d(1), FeedbackKind.focus),
        ActivityEntry('boot', WordSource.assigned, d(1), FeedbackKind.success),
        ActivityEntry('ship', WordSource.manual, d(2), FeedbackKind.success),
        ActivityEntry('thumb', WordSource.diagnostic, d(3), FeedbackKind.almost),
      ],
    );
  }

  /// A learner a few days in: short history, small queue.
  static DemoProfile _leo(DateTime today) {
    DateTime d(int days) => today.subtract(Duration(days: days));
    return DemoProfile(
      learner: const Learner(id: 'leo', name: 'Leo', colorIndex: 2, streak: 3, weeklyGoalMinutes: 45),
      queue: [
        word('ship', WordSource.diagnostic, d(1)),
        word('star', WordSource.assigned, d(0)),
      ],
      soundProfile: const [
        SoundScore('s', 0.58, 'sun'),
        SoundScore('ʃ', 0.66, 'ship'),
        SoundScore('l', 0.84, 'leaf'),
      ],
      trends: const [SoundTrend('s', [0.5, 0.58])],
      mastered: const ['l'],
      lessons: _lessons
          .map((l) => LessonNode(
                id: l.id,
                title: l.title,
                sound: l.sound,
                words: l.words,
                status: l.id == 'oo' ? LessonStatus.current : LessonStatus.locked,
              ))
          .toList(),
      history: [for (var i = 2; i >= 0; i--) DayActivity(d(i), 10, 8)],
      activity: [ActivityEntry('ship', WordSource.diagnostic, d(1), FeedbackKind.almost)],
    );
  }

  /// Brand new learner, so empty states have something to show.
  static DemoProfile _sam() => DemoProfile(
        learner: const Learner(id: 'sam', name: 'Sam', colorIndex: 3, streak: 0, weeklyGoalMinutes: 30),
        queue: const [],
        soundProfile: const [],
        trends: const [],
        mastered: const [],
        lessons: const [],
        history: const [],
        activity: const [],
      );

  static const passages = [
    Passage(
      id: 'lotus-pond',
      title: 'The Lotus Pond',
      level: 'Level 1',
      minutes: 2,
      icon: Icons.local_florist_rounded,
      text: 'A pink lotus sat on the lake. A green frog hopped on a big leaf. '
          'The frog said hello to a blue fish.',
      mockResults: {
        'frog': FeedbackKind.almost,
        'leaf': FeedbackKind.focus,
        'fish': FeedbackKind.almost,
      },
    ),
    Passage(
      id: 'moon-boots',
      title: 'Moon Boots',
      level: 'Level 2',
      minutes: 3,
      icon: Icons.nightlight_round,
      text: 'Luna put on her moon boots. She jumped up, up, up to the stars. '
          'Soon it was time for lunch.',
      mockResults: {
        'jumped': FeedbackKind.almost,
        'stars': FeedbackKind.focus,
        'lunch': FeedbackKind.almost,
      },
    ),
    Passage(
      id: 'red-wagon',
      title: "Rabbit's Red Wagon",
      level: 'Level 2',
      minutes: 3,
      icon: Icons.pets_rounded,
      text: 'Rabbit has a red wagon. He takes it for a ride down the bumpy road. '
          'The wagon goes bump, bump, bump.',
      mockResults: {
        'rabbit': FeedbackKind.focus,
        'red': FeedbackKind.almost,
        'road': FeedbackKind.almost,
      },
    ),
  ];
}
