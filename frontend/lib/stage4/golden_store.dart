import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'mouth_features.dart';

/// One camera frame: ms since the take started, the features, and the raw contour points
/// as flat [x0, y0, x1, y1, ...] lists keyed by [contourKeys].
class MouthFrame {
  const MouthFrame({required this.t, required this.features, required this.contours});

  final int t;
  final List<double> features;
  final Map<String, List<int>> contours;

  Map<String, dynamic> toJson() => {
        't': t,
        'f': [for (final v in features) double.parse(v.toStringAsFixed(4))],
        'c': contours,
      };

  factory MouthFrame.fromJson(Map<String, dynamic> json) => MouthFrame(
        t: json['t'] as int,
        features: [for (final v in json['f'] as List) (v as num).toDouble()],
        contours: {
          for (final e in (json['c'] as Map<String, dynamic>? ?? {}).entries)
            e.key: [for (final v in e.value as List) v as int],
        },
      );
}

class GoldenTake {
  const GoldenTake({required this.id, required this.recordedAt, required this.frames});

  final String id;
  final DateTime recordedAt;
  final List<MouthFrame> frames;

  int get durationMs => frames.isEmpty ? 0 : frames.last.t - frames.first.t;

  double get fps => durationMs == 0 ? 0 : (frames.length - 1) * 1000 / durationMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'frames': [for (final f in frames) f.toJson()],
      };

  factory GoldenTake.fromJson(Map<String, dynamic> json) => GoldenTake(
        id: json['id'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        frames: [
          for (final f in json['frames'] as List) MouthFrame.fromJson(f as Map<String, dynamic>)
        ],
      );
}

/// Golden recordings per phoneme, saved on the device and exported as one JSON file.
class GoldenStore extends ChangeNotifier {
  GoldenStore({this.file});

  static const takesPerPhoneme = 5;
  static const fileName = 'golden_data.json';
  static const formatVersion = 1;

  /// Shared instance for the recorder screens, saved in the app's documents folder.
  static final instance = GoldenStore();

  /// Null keeps everything in memory (tests).
  File? file;
  final Map<String, List<GoldenTake>> _takes = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  List<GoldenTake> takesFor(String ipa) => List.unmodifiable(_takes[ipa] ?? const []);

  int get totalTakes => _takes.values.fold(0, (sum, t) => sum + t.length);

  int completedCount(Iterable<String> phonemes) =>
      phonemes.where((ipa) => takesFor(ipa).length >= takesPerPhoneme).length;

  Future<void> load() async {
    if (_loaded) return;
    file ??= File(p.join((await getApplicationDocumentsDirectory()).path, fileName));
    if (await file!.exists()) {
      _fromJson(jsonDecode(await file!.readAsString()) as Map<String, dynamic>);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addTake(String ipa, List<MouthFrame> frames) async {
    final now = DateTime.now();
    (_takes[ipa] ??= []).add(GoldenTake(
      id: '$ipa-${now.millisecondsSinceEpoch}',
      recordedAt: now,
      frames: frames,
    ));
    notifyListeners();
    await _save();
  }

  Future<void> deleteTake(String ipa, String id) async {
    _takes[ipa]?.removeWhere((t) => t.id == id);
    if (_takes[ipa]?.isEmpty ?? false) _takes.remove(ipa);
    notifyListeners();
    await _save();
  }

  Map<String, dynamic> toJson() => {
        'version': formatVersion,
        'features': featureNames,
        'contours': contourKeys,
        'exportedAt': DateTime.now().toIso8601String(),
        'phonemes': {
          for (final e in _takes.entries) e.key: [for (final t in e.value) t.toJson()],
        },
      };

  void _fromJson(Map<String, dynamic> json) {
    _takes.clear();
    for (final e in (json['phonemes'] as Map<String, dynamic>).entries) {
      _takes[e.key] = [
        for (final t in e.value as List) GoldenTake.fromJson(t as Map<String, dynamic>)
      ];
    }
  }

  Future<void> _save() async {
    final f = file;
    if (f == null) return;
    await f.writeAsString(jsonEncode(toJson()));
  }
}
