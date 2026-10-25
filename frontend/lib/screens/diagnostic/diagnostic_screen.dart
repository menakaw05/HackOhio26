import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/mock/demo_seed.dart';
import '../../data/mock/mock_diagnostic.dart';
import '../../data/sound_profile.dart';
import '../../practice_services.dart';
import '../../router.dart';
import '../../speech_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  static const _gotItPause = Duration(milliseconds: 900);

  final PracticeServices _services = createPracticeServices();
  final Map<String, PAResult> _scores = {};
  int _index = 0;
  bool _listening = false;
  bool _scoring = false;
  bool _gotIt = false;
  Timer? _advance;

  String get _word => diagnosticWords[_index];

  @override
  void dispose() {
    _advance?.cancel();
    _services.dispose();
    super.dispose();
  }

  /// Each word is scored by Azure (no feedback to the child, just "Got it!"); the phoneme
  /// scores build the sound profile at the end.
  Future<void> _toggleMic() async {
    if (!_listening) {
      final started = await _services.startRecording(context);
      if (mounted) setState(() => _listening = started);
      return;
    }
    setState(() {
      _listening = false;
      _scoring = true;
    });
    final word = _word;
    try {
      _scores[word] = await _services.stopAndScore(word);
    } catch (e) {
      debugPrint('diagnostic: could not score "$word": $e');
    }
    if (!mounted) return;
    setState(() {
      _scoring = false;
      _gotIt = true;
    });
    _advance = Timer(_gotItPause, _next);
  }

  void _next() {
    if (_index == diagnosticWords.length - 1) {
      final profile = profileFromScores(_scores);
      // nothing could be scored (e.g. no backend): show the sample profile instead
      if (profile.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't check your words, so this is a sample profile.")));
      }
      context.read<AppState>().applyDiagnostic(profile.isEmpty ? MockDiagnostic.profile : profile);
      context.pushReplacement(Routes.diagnosticResults);
      return;
    }
    setState(() {
      _index++;
      _gotIt = false;
    });
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the Diagnostic?'),
        content: const Text("You can start again any time. Progress so far won't be saved."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = diagnosticWords.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Exit',
          icon: const Icon(Icons.close_rounded),
          onPressed: _confirmExit,
        ),
        title: Text('Word ${_index + 1} of $total'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.s),
            child: ProgressBar(value: (_index + (_gotIt ? 1 : 0)) / total, height: 8),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: WordPicture(key: ValueKey(_word), word: _word, size: 170),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: Text(_word, key: ValueKey(_word), style: AppText.wordHero),
              ),
              const SizedBox(height: AppSpace.m),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: _gotIt
                    ? Row(
                        key: const ValueKey('got-it'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success),
                          const SizedBox(width: AppSpace.xs),
                          Text('Got it!', style: AppText.section.copyWith(color: AppColors.success)),
                        ],
                      )
                    : Text(
                        _scoring
                            ? 'Checking…'
                            : (_listening ? "Listening… tap when you're done." : 'Tap the mic and say the word.'),
                        key: ValueKey((_listening, _scoring)),
                        style: AppText.bodyStrong,
                        textAlign: TextAlign.center,
                      ),
              ),
              const Spacer(),
              MicButton(listening: _listening, onPressed: _gotIt || _scoring ? null : _toggleMic),
              const SizedBox(height: AppSpace.l),
            ],
          ),
        ),
      ),
    );
  }
}
