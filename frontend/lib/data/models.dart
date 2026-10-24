import 'package:flutter/material.dart';
import '../widgets/feedback_banner.dart';

/// Where a queued word came from.
enum WordSource {
  diagnostic('Diagnostic', Icons.fact_check_rounded),
  reading('Reading', Icons.menu_book_rounded),
  lookAndSay('Look & Say', Icons.center_focus_strong_rounded),
  assigned('your SLP', Icons.assignment_rounded),
  manual('you', Icons.edit_rounded);

  const WordSource(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum SoundLevel {
  strong('Strong', FeedbackKind.success),
  almost('Almost', FeedbackKind.almost),
  needsPractice('Needs practice', FeedbackKind.focus);

  const SoundLevel(this.label, this.kind);

  final String label;
  final FeedbackKind kind;

  static SoundLevel fromScore(double score) => score >= 0.8
      ? SoundLevel.strong
      : (score >= 0.6 ? SoundLevel.almost : SoundLevel.needsPractice);
}

class Learner {
  const Learner({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.streak,
    required this.weeklyGoalMinutes,
  });

  final String id;
  final String name;
  final int colorIndex;
  final int streak;
  final int weeklyGoalMinutes;

  String get initial => name.characters.first.toUpperCase();
}

class WordItem {
  const WordItem({
    required this.id,
    required this.text,
    required this.phonemes,
    required this.source,
    required this.addedAt,
  });

  final String id;
  final String text;

  /// IPA symbols, matching what Azure returns (e.g. boot = b, u, t).
  final List<String> phonemes;
  final WordSource source;
  final DateTime addedAt;
}

class PhonemeResult {
  const PhonemeResult(this.phoneme, this.kind);

  final String phoneme;
  final FeedbackKind kind;
}

class AttemptResult {
  const AttemptResult({
    required this.wordId,
    required this.kind,
    required this.phonemeResults,
    required this.timestamp,
    this.coaching,
  });

  final String wordId;
  final FeedbackKind kind;
  final List<PhonemeResult> phonemeResults;
  final DateTime timestamp;

  /// One-line coaching message, e.g. a mouth-shape hint.
  final String? coaching;
}

/// One sound in the learner's sound profile, 0 to 1.
class SoundScore {
  const SoundScore(this.phoneme, this.score, this.exampleWord);

  final String phoneme;
  final double score;
  final String exampleWord;

  SoundLevel get level => SoundLevel.fromScore(score);
}

/// Weekly scores for one sound, oldest first.
class SoundTrend {
  const SoundTrend(this.phoneme, this.weekly);

  final String phoneme;
  final List<double> weekly;
}

enum LessonStatus { done, current, locked }

class LessonNode {
  const LessonNode({
    required this.id,
    required this.title,
    required this.sound,
    required this.status,
    required this.words,
  });

  final String id;
  final String title;
  final String sound;
  final LessonStatus status;
  final List<String> words;
}

class Passage {
  const Passage({
    required this.id,
    required this.title,
    required this.level,
    required this.minutes,
    required this.icon,
    required this.text,
    required this.mockResults,
  });

  final String id;
  final String title;
  final String level;
  final int minutes;
  final IconData icon;
  final String text;

  /// SAMPLE DATA: how each word "went", keyed by lowercase word. Words not listed were clear.
  final Map<String, FeedbackKind> mockResults;

  List<String> get words => text.split(RegExp(r'\s+'));
}

class DayActivity {
  const DayActivity(this.date, this.minutes, this.wordsPracticed);

  final DateTime date;
  final int minutes;
  final int wordsPracticed;
}

class ActivityEntry {
  const ActivityEntry(this.word, this.source, this.when, this.kind);

  final String word;
  final WordSource source;
  final DateTime when;
  final FeedbackKind kind;
}

/// "today", "yesterday", "3 days ago".
String relativeDay(DateTime when, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = today.difference(DateUtils.dateOnly(when)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
