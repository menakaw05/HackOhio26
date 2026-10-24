import 'dart:io';

import 'package:flutter/material.dart';
import 'recorder_controller.dart';
import 'speech_models.dart';
import 'speech_services.dart';

class SpeechController {
  final RecordingService _recorder = RecordingService();
  final SpeechServices _speechService = SpeechServices();

  /// Called by your “Start” button. Returns true if recording started.
  Future<bool> onStartClicked(BuildContext context) async {
    try {
      print("recorder started");
      await _recorder.start();
      return true;
    } on MicPermissionException catch (e) {
      print(' start error (mic permission): $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      print(' start error: $e');
    }
    return false;
  }

  /// Called by your “Stop” button.
  Future<File?> onStopClicked() async {
    try {
      print("SPEECH CONTROLLER: recorder has been stopped");
      final file = await _recorder.stop();
      if (file == null) throw Exception('No file recorded');
      return file;
    } catch (e) {
      print('stop error: $e');
      return null;
    }
  }

  /// Sends the recording to the backend for pronunciation assessment.
  /// Errors propagate so the UI can show them.
  Future<PAResult> assess(
      File file, String referenceText, GradingLevel level) {
    return _speechService.uploadAudio(file, referenceText, level);
  }

  /// Forward dispose when your controller dies.
  Future<void> dispose() => _recorder.dispose();
}
