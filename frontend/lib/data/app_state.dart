import 'package:flutter/foundation.dart';
import 'mock/demo_seed.dart';
import 'models.dart';
import 'practice_queue.dart';

/// App-wide state: who's practicing and their (sample) data. Backed by [DemoSeed] for now.
class AppState extends ChangeNotifier {
  AppState() {
    _load();
  }

  late List<DemoProfile> _profiles;
  DemoProfile? _current;
  final PracticeQueue queue = PracticeQueue();

  List<Learner> get learners => _profiles.map((p) => p.learner).toList();
  Learner? get learner => _current?.learner;
  bool get hasLearner => _current != null;

  List<SoundScore> get soundProfile => _current?.soundProfile ?? const [];
  List<SoundTrend> get trends => _current?.trends ?? const [];
  List<String> get mastered => _current?.mastered ?? const [];
  List<LessonNode> get lessons => _current?.lessons ?? const [];
  List<DayActivity> get history => _current?.history ?? const [];
  List<ActivityEntry> get activity => _current?.activity ?? const [];
  List<Passage> get passages => DemoSeed.passages;

  /// Sounds below "Strong", weakest first.
  List<SoundScore> get soundsToWorkOn =>
      soundProfile.where((s) => s.level != SoundLevel.strong).toList()
        ..sort((a, b) => a.score.compareTo(b.score));

  List<DayActivity> historySince(DateTime since) =>
      history.where((d) => !d.date.isBefore(since)).toList();

  // Words each learner has already built up in stage 4 (this run). The first time a word is
  // practiced it's broken down and put back together; after that it's the word, then just
  // the trouble sound.
  final Set<String> _builtUp = {};

  String _builtKey(String word) => '${_current?.learner.id}:${word.toLowerCase()}';
  bool hasBuiltUp(String word) => _builtUp.contains(_builtKey(word));
  void markBuiltUp(String word) => _builtUp.add(_builtKey(word));

  void selectLearner(String id) {
    _current = _profiles.firstWhere((p) => p.learner.id == id);
    queue.replaceAll(_current!.queue);
    notifyListeners();
  }

  void signOut() {
    _current = null;
    queue.replaceAll(const []);
    notifyListeners();
  }

  /// Adds words to the shared queue with their source. Returns how many were new.
  int addWords(Iterable<String> words, WordSource source) {
    final now = DateTime.now();
    return queue.addAll(words.map((w) => DemoSeed.word(w.toLowerCase(), source, now)));
  }

  /// Saves the latest Diagnostic as the current learner's sound profile.
  void applyDiagnostic(List<SoundScore> profile) {
    final current = _current;
    if (current == null) return;
    current.soundProfile = profile;
    notifyListeners();
  }

  /// Debug menu: restore the sample data and keep the current learner.
  void resetDemo() {
    final id = _current?.learner.id;
    _load();
    if (id != null) selectLearner(id);
    notifyListeners();
  }

  void _load() {
    _profiles = DemoSeed.profiles();
    _current = null;
  }
}
