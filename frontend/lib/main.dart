import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'avatar_test_page.dart';
import 'speech_controller.dart';
import 'speech_models.dart';

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
  bool _isAssessing = false;
  File? _lastRecording;
  PAResult? _result;
  String? _error;

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
      if (file != null) await _assess(file);
    } else {
      final started = await _speechController.onStartClicked(context);
      setState(() {
        _isRecording = started;
        if (started) {
          _result = null;
          _error = null;
        }
      });
    }
  }

  Future<void> _assess(File file) async {
    final referenceText = _referenceTextController.text.trim();
    if (referenceText.isEmpty) {
      setState(() => _error = 'Enter the text you are going to say.');
      return;
    }

    setState(() => _isAssessing = true);
    try {
      final result = await _speechController.assess(
          file, referenceText, GradingLevel.phoneme);
      setState(() => _result = result);
    } catch (e) {
      print('assess error: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isAssessing = false);
    }
  }

  Future<void> _playLastRecording() async {
    if (_lastRecording == null) return;
    await _player.setFilePath(_lastRecording!.path);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isAssessing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pronunciation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.face),
            tooltip: 'Avatar test',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AvatarTestPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _referenceTextController,
            enabled: !_isRecording && !busy,
            decoration: const InputDecoration(
              labelText: 'Text to say',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : _toggleRecording,
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            label: Text(_isRecording ? 'Stop' : 'Record'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _lastRecording == null || _isRecording
                      ? null
                      : _playLastRecording,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _lastRecording == null || _isRecording || busy
                      ? null
                      : () => _assess(_lastRecording!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-assess'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_result != null) _ResultView(result: _result!),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final PAResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Heard: "${result.recognizedText}"', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _scoreChip('Pronunciation', result.pronunciationScore),
            _scoreChip('Accuracy', result.accuracyScore),
            _scoreChip('Fluency', result.fluencyScore),
            _scoreChip('Completeness', result.completenessScore),
            _scoreChip('Prosody', result.prosodyScore),
          ],
        ),
        const SizedBox(height: 16),
        for (final word in result.words)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${word.word}  ${word.accuracyScore.toStringAsFixed(0)}'
                    '${word.errorType != 'None' ? '  (${word.errorType})' : ''}',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final p in word.phonemes)
                    Text(
                      '/${p.phoneme}/  ${p.accuracyScore.toStringAsFixed(0)}'
                      '${p.nBestPhonemes.isNotEmpty ? '   heard: ${p.nBestPhonemes.map((n) => '/${n.phoneme}/ ${n.score.toStringAsFixed(0)}').join(', ')}' : ''}',
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _scoreChip(String label, double score) {
    return Chip(label: Text('$label: ${score.toStringAsFixed(0)}'));
  }
}
