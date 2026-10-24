import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<void> dispose() => _recorder.dispose();

  // record's hasPermission() triggers the iOS mic prompt on first use
  Future<void> ensureMicPermission() async {
    final granted = await _recorder.hasPermission();

    if (granted) {
      print("Microphone permission granted");
      return;
    }

    print("Microphone permission denied.");
    throw MicPermissionException(
      'Microphone permission denied. Please enable it in Settings.',
    );
  }

  /// Returns the absolute file path it will record to, so the UI can store or upload it later.
  Future<String> start() async {
    print("get mic permission");
    await ensureMicPermission();

    final dir = await getTemporaryDirectory();
    final filePath =
        p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');

    // 16kHz mono 16-bit WAV is what Azure pronunciation assessment expects
    final cfg = const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 16000 * 16,
    );

    await _recorder.start(cfg, path: filePath);
    print('Recording to $filePath');
    return filePath;
  }

  Future<File?> stop() async {
    final path = await _recorder.stop();
    return path != null ? File(path) : null;
  }

  Future<void> cancel() => _recorder.cancel();
}

class MicPermissionException implements Exception {
  final String message;
  MicPermissionException(this.message);

  @override
  String toString() => "MicPermissionException: $message";
}
