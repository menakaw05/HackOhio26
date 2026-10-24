/// Sent to the backend as `gradinglevel`; parsed case-insensitively into Azure's Granularity.
enum GradingLevel { phoneme, word, fullText }

class PhonemeConfusion {
  final String phoneme;
  final double score;

  PhonemeConfusion({
    required this.phoneme,
    required this.score,
  });

  factory PhonemeConfusion.fromJson(Map<String, dynamic> json) {
    return PhonemeConfusion(
      phoneme: json['phoneme'] as String,
      score: (json['score'] as num).toDouble(),
    );
  }
}

class PhonemeAssessment {
  final String phoneme;
  final double accuracyScore;
  final List<PhonemeConfusion> nBestPhonemes;

  PhonemeAssessment({
    required this.phoneme,
    required this.accuracyScore,
    required this.nBestPhonemes,
  });

  factory PhonemeAssessment.fromJson(Map<String, dynamic> json) {
    return PhonemeAssessment(
      phoneme: json['phoneme'] as String,
      accuracyScore: (json['accuracyScore'] as num).toDouble(),
      nBestPhonemes: (json['nBestPhonemes'] as List<dynamic>? ?? [])
          .map((e) => PhonemeConfusion.fromJson(e))
          .toList(),
    );
  }
}

class WordAssessment {
  final String word;
  final double accuracyScore;
  final String errorType;
  final List<PhonemeAssessment> phonemes;
  final DateTime timestamp;

  WordAssessment({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
    required this.phonemes,
    required this.timestamp,
  });

  factory WordAssessment.fromJson(Map<String, dynamic> json) {
    return WordAssessment(
      word: json['word'] as String,
      accuracyScore: (json['accuracyScore'] as num).toDouble(),
      errorType: json['errorType'] as String,
      phonemes: (json['phonemes'] as List<dynamic>? ?? [])
          .map((e) => PhonemeAssessment.fromJson(e))
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class PAResult {
  final String recognizedText;
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double prosodyScore;
  final double pronunciationScore;
  final List<WordAssessment> words;

  PAResult({
    required this.recognizedText,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.prosodyScore,
    required this.pronunciationScore,
    required this.words,
  });

  factory PAResult.fromJson(Map<String, dynamic> json) {
    return PAResult(
      recognizedText: json['recognizedText'] as String,
      accuracyScore: (json['accuracyScore'] as num).toDouble(),
      fluencyScore: (json['fluencyScore'] as num).toDouble(),
      completenessScore: (json['completenessScore'] as num).toDouble(),
      prosodyScore: (json['prosodyScore'] as num).toDouble(),
      pronunciationScore: (json['pronunciationScore'] as num).toDouble(),
      words: (json['words'] as List<dynamic>? ?? [])
          .map((e) => WordAssessment.fromJson(e))
          .toList(),
    );
  }
}
