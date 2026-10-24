import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'speech_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HackOhio26',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const RecordPage(),
    );
  }
}

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final SpeechController _speechController = SpeechController();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _referenceTextController =
      TextEditingController(text: 'hello');

  bool _isRecording = false;
  File? _lastRecording;

  @override
  void dispose() {
    _speechController.dispose();
    _player.dispose();
    _referenceTextController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final file = await _speechController.onStopClicked();
      setState(() {
        _isRecording = false;
        _lastRecording = file;
      });
    } else {
      final started = await _speechController.onStartClicked(context);
      setState(() => _isRecording = started);
    }
  }

  Future<void> _playLastRecording() async {
    if (_lastRecording == null) return;
    await _player.setFilePath(_lastRecording!.path);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pronunciation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _referenceTextController,
              decoration: const InputDecoration(
                labelText: 'Text to say',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop' : 'Record'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  _lastRecording == null || _isRecording ? null : _playLastRecording,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play recording'),
            ),
            const SizedBox(height: 16),
            if (_lastRecording != null)
              Text(
                'Saved ${_lastRecording!.lengthSync()} bytes to\n${_lastRecording!.path}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
