import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'speech_services.dart';

/// Plays Azure TTS from the backend. Segments like "/u/" in the text are spoken as that IPA sound.
class TtsService {
  final AudioPlayer _player = AudioPlayer();

  // Downloaded clips by text. Streaming the URL straight into the player failed now and then
  // ("resource unavailable") and made the backend synthesize every clip twice.
  static final Map<String, String> _clips = {};
  static int _clipCount = 0;

  Future<void> speak(String text) async {
    try {
      await _player.stop();
      final path = await _clip(text);
      if (path == null) return;
      await _player.setFilePath(path);
      await _player.play();
    } catch (e) {
      print('TTS playback failed: $e');
    }
  }

  Future<String?> _clip(String text) async {
    final cached = _clips[text];
    if (cached != null) return cached;
    final uri = Uri.parse('${SpeechServices.baseUrl}/api/tts/speak')
        .replace(queryParameters: {'text': text});
    print('Fetching TTS from: $uri');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      print('TTS failed: ${res.statusCode}');
      return null;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tts_${_clipCount++}.mp3');
    await file.writeAsBytes(res.bodyBytes);
    return _clips[text] = file.path;
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
