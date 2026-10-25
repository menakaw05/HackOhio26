import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

import 'model/feature_extraction.dart';

class PhonemeQualityModel {
  // Azure IPA phoneme -> model asset suffix. Only phonemes listed here have a face model.
  // u as in "boot", p as in "pop", æ as in "apple".
  static const Map<String, String> phonemeMap = {'u': 'O', 'p': 'P', 'æ': 'A'};

  // The label each model gives a correct attempt.
  static const Set<String> correctLabels = {'OO', 'GOOD', 'APPLE'};

  static bool hasModelFor(String phoneme) => phonemeMap.containsKey(phoneme);

  // Majority label of the last scored attempt, e.g. "HALFCLOSED".
  String? lastLabel;
  bool get lastWasCorrect => correctLabels.contains(lastLabel);

  // Share of the last attempt's frames that got the correct label (0-1).
  double lastCorrectFraction = 0;

  // OrtEnv.init() creates a new native env on every call, so only do it once per app
  static bool _envInitialized = false;

  OrtSession? _session;
  String? _loadedPhoneme;

  // maps class index -> class label string, from class_label_map_<X>.json
  late Map<String, dynamic> _idxToLabel;

  // maps class label -> feedback string, from label_feedback_map_<X>.json
  late Map<String, dynamic> _labelToFeedback;

  bool get isLoaded => _session != null;

  /// The tips this model can give for a miss (needs [loadModel] first).
  List<String> get missTips => [
        for (final e in _labelToFeedback.entries)
          if (!correctLabels.contains(e.key)) e.value as String,
      ];

  /// load ONNX model + label maps for a specific phoneme
  Future<void> loadModel(String phoneme) async {
    final suffix = phonemeMap[phoneme];
    if (suffix == null) {
      throw ArgumentError('No face model for phoneme /$phoneme/');
    }
    if (_loadedPhoneme == phoneme) return;

    final classJsonString = await rootBundle
        .loadString('assets/models/mappings/class_label_map_$suffix.json');
    _idxToLabel = jsonDecode(classJsonString);

    final feedbackJsonString = await rootBundle
        .loadString('assets/models/mappings/label_feedback_map_$suffix.json');
    _labelToFeedback = jsonDecode(feedbackJsonString);

    if (!_envInitialized) {
      OrtEnv.instance.init();
      _envInitialized = true;
    }
    final onnxBytes =
        await rootBundle.load('assets/models/phoneme_models/${suffix}_model.onnx');

    _session?.release();
    _session = OrtSession.fromBuffer(
      onnxBytes.buffer.asUint8List(),
      OrtSessionOptions(),
    );
    _loadedPhoneme = phoneme;
    print("onnx model for /$phoneme/ ($suffix) loaded");
  }

  /// full attempt scoring:
  /// - parse raw JSON with all frames from one attempt
  /// - extract mouth features per frame
  /// - run ONNX per frame
  /// - majority vote final label
  /// - map to human feedback
  ///
  /// returns null if there was no usable mouth data
  String? getPhonemeFeedback(String jsonInput) {
    if (!isLoaded) {
      throw StateError("model not loaded");
    }

    // 1. parse attempt JSON into raw per-frame geometry
    final rawFrames = extractAllRawFrameFeaturesFromPayload(jsonInput);
    if (rawFrames.isEmpty) return null;

    // 2. build 15-dim feature vectors for every frame, in order
    final frameVectors = buildFeatureVectorsForAttempt(rawFrames);

    // 3. run model on each frame and collect predicted labels
    final preds = frameVectors.map(predictClassForVector).toList();
    print("per-frame predictions for /$_loadedPhoneme/: $preds");

    // 4. majority vote
    final finalLabel = _majorityVote(preds);
    lastLabel = finalLabel;
    lastCorrectFraction = preds.where(correctLabels.contains).length / preds.length;

    // 5. map to feedback
    return _labelToFeedback[finalLabel] as String? ??
        "Keep practicing /$_loadedPhoneme/.";
  }

  String predictClassForVector(List<double> featureVec) {
    final session = _session;
    if (session == null) {
      throw StateError("model not loaded yet");
    }

    // input tensor: shape [1, feature_dim]
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(featureVec),
      [1, featureVec.length],
    );
    final runOptions = OrtRunOptions();

    try {
      final results = session.run(
        runOptions,
        {session.inputNames.first: inputTensor},
        [session.outputNames.first],
      );

      if (results.isEmpty || results[0] == null) {
        throw StateError("onnx runtime returned empty/null output");
      }

      final rawVal = results[0]!.value;
      for (final r in results) {
        r?.release();
      }

      // shape [1, num_classes]
      final logits = rawVal is List<List<double>>
          ? rawVal.first
          : (rawVal as List).first.map<double>((n) => (n as num).toDouble()).toList();

      final predIdx = _argMaxIndex(logits);
      return _idxToLabel["$predIdx"] as String? ?? "UNKNOWN";
    } finally {
      inputTensor.release();
      runOptions.release();
    }
  }

  /// pick the mode of a list of labels
  String _majorityVote(List<String> labels) {
    final counts = <String, int>{};
    for (final l in labels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    String bestLabel = labels.first;
    int bestCount = 0;
    counts.forEach((lbl, c) {
      if (c > bestCount) {
        bestCount = c;
        bestLabel = lbl;
      }
    });
    return bestLabel;
  }

  int _argMaxIndex(List<double> vals) {
    var bestI = 0;
    var bestV = vals[0];
    for (var i = 1; i < vals.length; i++) {
      if (vals[i] > bestV) {
        bestV = vals[i];
        bestI = i;
      }
    }
    return bestI;
  }

  void dispose() {
    _session?.release();
    _session = null;
    _loadedPhoneme = null;
  }
}
