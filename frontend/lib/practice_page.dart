import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'avatar_coach.dart';
import 'avatar_test_page.dart';
import 'avatar_view.dart';
import 'face_camera.dart';
import 'phoneme_classifier.dart';
import 'phoneme_feedback.dart';
import 'speech_controller.dart';
import 'speech_models.dart';
import 'tts_service.dart';

// word = stage 1, phoneme = stage 2 (sound practice), demo = stage 3 (avatar demonstrates)
enum PracticeMode { word, phoneme, demo }

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
  final FaceCamera _faceCamera = FaceCamera();
  final PhonemeQualityModel _model = PhonemeQualityModel();
  final TtsService _tts = TtsService();
  final TextEditingController _referenceTextController =
      TextEditingController(text: 'boot');

  PracticeMode _mode = PracticeMode.word;
  int _wordAttempt = 1;
  PhonemeAssessment? _targetPhoneme;
  bool _cameraUnavailable = false;
  String? _lastFaceJson;
  int? _lastFaceFrameCount;

  // Stage 3: the avatar demonstrates, the child retries until the sound passes.
  GlobalKey<AvatarViewState> _avatarKey = GlobalKey();
  bool _avatarReady = false;
  bool _demoPending = false;
  int _demoTry = 0;
  double _demoAccuracy = 0;

  bool _isRecording = false;
  bool _isAssessing = false;
  File? _lastRecording;
  PAResult? _result;
  String? _feedback;
  String? _error;

  String get _currentWord => _referenceTextController.text.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sayWord());
  }

  @override
  void dispose() {
    _tts.dispose();
    _speechController.dispose();
    _player.dispose();
    _faceCamera.dispose();
    _model.dispose();
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

  void _sayWord() {
    if (_currentWord.isNotEmpty) _tts.speak('Say $_currentWord!');
  }

  void _sayPhoneme() {
    final target = _targetPhoneme;
    if (target != null) _tts.speak('Say /${target.phoneme}/.');
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
      await _tts.stop();
      if (!mounted) return;
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
      _tts.speak(_feedback!);
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
    _tts.speak("Let's practice the /${worst.phoneme}/ sound. Say /${worst.phoneme}/.");
    _initCamera();
  }

  Future<void> _initCamera() async {
    final ready = await _faceCamera.initialize();
    if (!mounted) return;
    setState(() => _cameraUnavailable = !ready);
  }

  // -------------------------
  // SOUND attempt (stages 2 and 3): just the trouble sound, voice + camera
  // -------------------------
  Future<void> _togglePhonemeAttempt() async {
    if (_isRecording) {
      final file = await _speechController.onStopClicked();
      final frameCount = _faceCamera.frameCount;
      final faceJson = await _faceCamera.stopFaceStream();
      setState(() {
        _isRecording = false;
        _lastFaceJson = faceJson;
        _lastFaceFrameCount = frameCount;
      });
      if (file != null) await _assessSound(file);
    } else {
      await _tts.stop();
      if (!mounted) return;
      final started = await _speechController.onStartClicked(context);
      if (started) await _faceCamera.startFaceStream();
      setState(() {
        _isRecording = started;
        if (started) {
          _feedback = null;
          _error = null;
          _lastFaceFrameCount = null;
        }
      });
    }
  }

  /// Judges a single-sound attempt the way eLEXir's ice bridges game does:
  /// Azure scores the recording against the sound's spelling ("puh"), using
  /// only the target sound's score, and passes at 50. For sounds with a lip
  /// model (/p/, /æ/, /u/) the lips must also look right, and the model's tip
  /// explains a miss. A miss in stage 2 moves on to the avatar demo (stage 3);
  /// in stage 3 the avatar demonstrates again, with no cap on tries.
  Future<void> _assessSound(File file) async {
    final target = _targetPhoneme;
    if (target == null) return;
    setState(() => _isAssessing = true);
    try {
      final result = await _speechController.assess(
          file, soundPromptFor(target.phoneme).text, GradingLevel.phoneme);
      final score = soundScore(result, target.phoneme);
      final lipTip = await _faceModelFeedback(target.phoneme);
      setState(() {
        _result = result;
        _demoAccuracy = score;
        if (_mode == PracticeMode.demo) _demoTry += 1;
      });

      if (score >= soundPassScore && lipTip == null) {
        _afterPhonemeDecision('You got the /${target.phoneme}/ sound!');
        return;
      }

      final attempt = bestPhoneme(result, target.phoneme);
      final cue = lipTip ??
          (attempt == null
              ? "I couldn't hear the /${target.phoneme}/ sound."
              : voicingCue(attempt) ?? azureFeedbackFor(attempt));
      if (_mode == PracticeMode.phoneme) {
        _startDemo(cue);
      } else {
        setState(() => _feedback = '$cue Watch again, then try.');
        _speakThenDemonstrate(_feedback!);
      }
    } catch (e) {
      print('assess error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isAssessing = false);
    }
  }

  /// Runs the ONNX face model on the last sound attempt, or returns null if there's no model
  /// for this phoneme, no usable face data, or the lips looked right (the camera only
  /// explains a miss; then the tongue/voicing/Azure cue is used instead).
  Future<String?> _faceModelFeedback(String phoneme) async {
    final faceJson = _lastFaceJson;
    if (!PhonemeQualityModel.hasModelFor(phoneme) || faceJson == null) return null;

    try {
      await _model.loadModel(phoneme);
      final feedback = _model.getPhonemeFeedback(faceJson);
      print("visual feedback for /$phoneme/: ${_model.lastLabel} $feedback");
      if (_model.lastWasCorrect) return null;
      return feedback;
    } catch (e) {
      print('face model error: $e');
      return null;
    }
  }

  /// After the sound practice, retry the word if attempts remain, otherwise move on.
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
    _tts.speak(_feedback!);
  }

  // -------------------------
  // DEMO (stage 3): the avatar shows the sound, the child keeps practicing
  // just that sound until it passes (judged by _assessSound)
  // -------------------------
  void _startDemo(String cue) {
    final target = _targetPhoneme!;
    final tip = isTongueSound(target.phoneme)
        ? 'This sound is made with your tongue. Watch the coach closely.'
        : 'Watch the coach.';
    setState(() {
      _mode = PracticeMode.demo;
      _demoTry = 0;
      _demoAccuracy = target.accuracyScore;
      _avatarKey = GlobalKey();
      _avatarReady = false;
      _demoPending = false;
      _feedback = cue.isEmpty ? tip : '$cue $tip';
    });
    _speakThenDemonstrate(_feedback!);
  }

  /// Speaks the cue, then the avatar demonstrates once its page has loaded.
  Future<void> _speakThenDemonstrate(String cue) async {
    await _tts.speak(cue);
    if (!mounted || _mode != PracticeMode.demo) return;
    if (_avatarReady) {
      _demonstrate();
    } else {
      _demoPending = true;
    }
  }

  void _onAvatarMessage(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    switch (m['event']) {
      case 'ready':
        _avatarReady = true;
        if (_demoPending) {
          _demoPending = false;
          _demonstrate();
        }
      case 'error':
        setState(() => _error = 'Avatar: ${m['message']}');
    }
  }

  /// The avatar says the sound on its own ("puh", "sss"), holding on its mouth
  /// shape and exaggerating its movement less as the child gets closer.
  void _demonstrate() {
    final target = _targetPhoneme;
    if (target == null) return;
    final prompt = soundPromptFor(target.phoneme);
    final viseme = visemeFor(target.phoneme);
    final gains = boostFor(target.phoneme, boostGain(_demoAccuracy));
    _avatarKey.currentState?.say(prompt.text, opts: {
      'tts': {'ipa': prompt.ipa},
      if (viseme != null) 'holdViseme': viseme,
      'holdMs': 900,
      if (gains.isNotEmpty) 'boost': {'gains': gains, 'start': 0, 'end': 30},
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
    final isDemo = _mode == PracticeMode.demo;
    final isSound = isPhoneme || isDemo;
    final textTheme = Theme.of(context).textTheme;

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
            enabled: !_isRecording && !_isAssessing,
            onChanged: (_) => _resetSession(),
            onSubmitted: (_) => _sayWord(),
            decoration: const InputDecoration(
              labelText: 'Text to say',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  isSound ? '/${_targetPhoneme!.phoneme}/' : _currentWord,
                  style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: isDemo ? 'Watch again' : 'Hear it',
                onPressed: _isRecording
                    ? null
                    : (isDemo ? _demonstrate : (isPhoneme ? _sayPhoneme : _sayWord)),
                icon: const Icon(Icons.volume_up),
              ),
            ],
          ),
          Center(
            child: Text(
              isDemo
                  ? 'Watch the coach, then copy the sound. Try ${_demoTry + 1}'
                  : isPhoneme
                      ? '(sound practice)'
                      : 'Attempt $_wordAttempt of $maxWordAttempts',
              style: TextStyle(
                  color: isSound ? Colors.redAccent : textTheme.bodySmall?.color),
            ),
          ),
          if (isPhoneme) ...[
            const SizedBox(height: 16),
            _buildCameraPreview(),
          ],
          if (isDemo) ...[
            const SizedBox(height: 16),
            _buildDemoView(),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isAssessing
                ? null
                : (isSound ? _togglePhonemeAttempt : _toggleWordRecording),
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            label: Text(_isRecording
                ? 'Stop'
                : (isDemo
                    ? 'Try the sound'
                    : (isPhoneme ? 'Start sound attempt' : 'Record'))),
          ),
          const SizedBox(height: 8),
          if (isDemo) ...[
            OutlinedButton.icon(
              onPressed: _isRecording || _isAssessing ? null : _demonstrate,
              icon: const Icon(Icons.replay),
              label: const Text('Watch again'),
            ),
            const SizedBox(height: 8),
          ],
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
          if (_lastFaceFrameCount != null)
            Text('Captured $_lastFaceFrameCount face frames on the last sound attempt.',
                style: textTheme.bodySmall),
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

  /// Stage 3: the coach (avatar) and the child (camera) side by side.
  Widget _buildDemoView() {
    final controller = _faceCamera.controller;
    return SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                // the avatar fills this box; touches go to the buttons
                child: IgnorePointer(
                  child: AvatarView(
                    key: _avatarKey,
                    url: '$avatarBaseUrl/?embed=1&frame=0,0,1,1',
                    onMessage: _onAvatarMessage,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: _cameraUnavailable ||
                      controller == null ||
                      !_faceCamera.isInitialized
                  ? const Text('No camera available on this device.')
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(controller),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _faceCamera.controller;
    return SizedBox(
      height: 360,
      child: Center(
        child: _cameraUnavailable
            ? const Text('No camera available on this device.')
            : (controller == null || !_faceCamera.isInitialized)
                ? const CircularProgressIndicator()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CameraPreview(controller),
                  ),
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
