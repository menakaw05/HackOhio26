import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'speech_models.dart';

class SpeechServices {
  // localhost works on the iOS simulator; for a physical phone pass your Mac's LAN IP:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5250
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5250',
  );

  Future<PAResult> uploadAudio(
      File audioFile, String referenceText, GradingLevel level) async {
    print("attempting to post to backend");
    final uri = Uri.parse('$baseUrl/api/speechassess/assess');
    var request = http.MultipartRequest('POST', uri)
      ..fields['referenceText'] = referenceText
      ..fields['gradinglevel'] = level.name
      ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      return PAResult.fromJson(jsonMap);
    } else {
      throw Exception(
          'Failed to get assessment from backend: ${response.statusCode} $body');
    }
  }
}
