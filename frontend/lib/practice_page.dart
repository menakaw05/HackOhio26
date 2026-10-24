import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'phoneme_feedback.dart';
import 'speech_controller.dart';
import 'speech_models.dart';

enum PracticeMode { word, phoneme }

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  static const double passingAccuracy = 80;
  static const int maxWordAttempts = 3;

  final SpeechController _speechController = SpeechController();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _referenceTextController =
      TextEditingController(text: 'boot');

  PracticeMode _mode = PracticeMode.word;
  int _wordAttempt = 1;
  PhonemeAssessment? _targetPhoneme;

  bool _isRecording = false;
  bool _isAssessing = false;
  File? _lastRecording;
  PAResult? _result;
  String? _feedback;
  String? _error;

  String get _currentWord => _referenceTextController.text.trim();

  @override
  void dispose() {
    _speechController.dispose();
    _player.dispose();
    _referenceTextController.dispose();
    super.dispose();
  }

  /// Typing a new word starts a fresh practice session.
  void _resetSession() {
    setState(() {
      _mode = PracticeMode.word;
      _wordAttempt = 1;
      _targetPhoneme = null;
      _result = null;
      _feedback = null;
      _error = null;
    });
  }

  // -------------------------
  // WORD attempt
  // -------------------------
  Future<void> _toggleWordRecording() async {
    if (_isRecording) {
      final file = await _speechController.onStopClicked();
      setState(() {
        _isRecording = false;
        _lastRecording = file;
      });
      if (file != null) await _assessWord(file);
    } else {
      if (_currentWord.isEmpty) {
        setState(() => _error = 'Enter the text you are going to say.');
        return;
      }
      final started = await _speechController.onStartClicked(context);
      setState(() {
        _isRecording = started;
        if (started) {
          _feedback = null;
          _error = null;
        }
      });
    }
  }

  Future<void> _assessWord(File file) async {
    setState(() => _isAssessing = true);
    try {
      final result = await _speechController.assess(
          file, _currentWord, GradingLevel.phoneme);
      setState(() => _result = result);
      _handleWordEvaluation(result);
    } catch (e) {
      print('assess error: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isAssessing = false);
    }
  }

  void _handleWordEvaluation(PAResult result) {
    if (result.accuracyScore >= passingAccuracy) {
      setState(() {
        _feedback = 'Great job! You said the word correctly.';
        _wordAttempt = 1;
      });
      return;
    }

    _wordAttempt += 1;
    final worst = findWorstPhoneme(result);
    if (worst == null) {
      // nothing scored (e.g. word omitted), so there's no phoneme to drill
      _afterPhonemeDecision("I couldn't hear that clearly.");
      return;
    }

    setState(() {
      _mode = PracticeMode.phoneme;
      _targetPhoneme = worst;
      _feedback = "Let's practice the /${worst.phoneme}/ sound.";
    });
  }

  // -------------------------
  // PHONEME attempt
  // -------------------------
  Future<void> _togglePhonemeAttempt() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      await _handlePhonemeEvaluation();
    } else {
      setState(() {
        _isRecording = true;
        _feedback = null;
      });
    }
  }

  Future<void> _handlePhonemeEvaluation() async {
    final target = _targetPhoneme;
    if (target == null) {
      _afterPhonemeDecision('');
      return;
    }
    _afterPhonemeDecision(azureFeedbackFor(target));
  }

  /// After the one phoneme attempt, retry the word if attempts remain, otherwise move on.
  void _afterPhonemeDecision(String feedback) {
    final canRetryWord = _wordAttempt <= maxWordAttempts;
    final next = canRetryWord
        ? 'Now try the whole word "$_currentWord" again.'
        : "Let's move on. Type a new word to practice.";

    setState(() {
      _mode = PracticeMode.word;
      _targetPhoneme = null;
      _feedback = feedback.isEmpty ? next : '$feedback $next';
      if (!canRetryWord) _wordAttempt = 1;
    });
  }

  Future<void> _playLastRecording() async {
    if (_lastRecording == null) return;
    await _player.setFilePath(_lastRecording!.path);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneme = _mode == PracticeMode.phoneme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pronunciation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _referenceTextController,
            enabled: !_isRecording && !_isAssessing,
            onChanged: (_) => _resetSession(),
            decoration: const InputDecoration(
              labelText: 'Text to say',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              isPhoneme ? '/${_targetPhoneme!.phoneme}/' : _currentWord,
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              isPhoneme
                  ? '(sound practice)'
                  : 'Attempt $_wordAttempt of $maxWordAttempts',
              style: TextStyle(
                  color: isPhoneme ? Colors.redAccent : textTheme.bodySmall?.color),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isAssessing
                ? null
                : (isPhoneme ? _togglePhonemeAttempt : _toggleWordRecording),
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            label: Text(_isRecording
                ? 'Stop'
                : (isPhoneme ? 'Start sound attempt' : 'Record')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _lastRecording == null || _isRecording
                ? null
                : _playLastRecording,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play last word recording'),
          ),
          const SizedBox(height: 16),
          if (_isAssessing) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_feedback != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_feedback!, style: textTheme.titleMedium),
              ),
            ),
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
        const SizedBox(height: 8),
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
