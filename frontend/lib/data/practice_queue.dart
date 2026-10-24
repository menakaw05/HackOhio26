import 'package:flutter/foundation.dart';
import 'models.dart';

/// Shared queue every practice "door" deposits words into. In memory for now.
class PracticeQueue extends ChangeNotifier {
  PracticeQueue([List<WordItem> initial = const []]) : _items = [...initial];

  final List<WordItem> _items;

  List<WordItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  WordItem? peek() => _items.isEmpty ? null : _items.first;

  bool contains(String text) =>
      _items.any((w) => w.text.toLowerCase() == text.toLowerCase());

  /// Adds words that aren't already queued. Returns how many were added.
  int addAll(Iterable<WordItem> words) {
    var added = 0;
    for (final w in words) {
      if (contains(w.text)) continue;
      _items.add(w);
      added++;
    }
    if (added > 0) notifyListeners();
    return added;
  }

  void remove(String id) {
    _items.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  WordItem? next() {
    if (_items.isEmpty) return null;
    final first = _items.removeAt(0);
    notifyListeners();
    return first;
  }

  void replaceAll(List<WordItem> words) {
    _items
      ..clear()
      ..addAll(words);
    notifyListeners();
  }
}
