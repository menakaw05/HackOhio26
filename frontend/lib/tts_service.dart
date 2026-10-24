import 'package:just_audio/just_audio.dart';
import 'speech_services.dart';

/// Plays Azure TTS from the backend. Segments like "/u/" in the text are spoken as that IPA sound.
class TtsService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> speak(String text) async {
    try {
      final uri = Uri.parse('${SpeechServices.baseUrl}/api/tts/speak')
          .replace(queryParameters: {'text': text});
      print('Fetching TTS from: $uri');
      await _player.stop();
      await _player.setUrl(uri.toString());
      await _player.play();
    } catch (e) {
      print('TTS playback failed: $e');
    }
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
