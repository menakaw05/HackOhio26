import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// eLEXir's word-image service (Azure): a picture per word, cached in Cosmos + Blob. A word
/// it hasn't seen gets drawn by DALL-E in the background, answering 202 until it's ready.
///   flutter run --dart-define=IMAGES_URL=https://...
const String imagesBaseUrl = String.fromEnvironment(
  'IMAGES_URL',
  defaultValue: 'https://elexirbackend-fqcub0hjhuaze2ey.eastus-01.azurewebsites.net',
);

abstract final class WordPictures {
  static final Map<String, Future<String?>> _urls = {};

  /// The picture's URL, or null if there isn't one (yet). Asks once per word per run; a
  /// miss is forgotten so the next screen can ask again.
  static Future<String?> urlFor(String word) {
    final key = word.trim().toLowerCase();
    return _urls.putIfAbsent(key, () async {
      final url = await _fetch(key);
      if (url == null) _urls.remove(key);
      return url;
    });
  }

  static Future<String?> _fetch(String word) async {
    // while it's being drawn, check back a few times
    for (var tries = 0; tries < 4; tries++) {
      try {
        final res = await http
            .get(Uri.parse('$imagesBaseUrl/api/images/get').replace(queryParameters: {'word': word}))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          return (jsonDecode(res.body) as Map<String, dynamic>)['fullUrl'] as String?;
        }
        if (res.statusCode != 202) return null;
      } catch (e) {
        debugPrint('word picture for "$word": $e');
        return null;
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
    return null;
  }
}
