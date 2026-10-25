import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/mock/demo_seed.dart';
import '../../data/mock/mock_diagnostic.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  static const _gotItPause = Duration(milliseconds: 900);

  int _index = 0;
  bool _listening = false;
  bool _gotIt = false;
  Timer? _advance;

  String get _word => diagnosticWords[_index];

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _toggleMic() {
    if (!_listening) {
      setState(() => _listening = true);
      return;
    }
    // MOCK: nothing is scored yet; show "Got it" and move on
    setState(() {
      _listening = false;
      _gotIt = true;
    });
    _advance = Timer(_gotItPause, _next);
  }

  void _next() {
    if (_index == diagnosticWords.length - 1) {
      context.read<AppState>().applyDiagnostic(MockDiagnostic.profile);
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
              const ComingSoon(label: 'Picture of the word', icon: Icons.image_rounded, height: 140),
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
                        _listening ? "Listening… tap when you're done." : 'Tap the mic and say the word.',
                        key: ValueKey(_listening),
                        style: AppText.bodyStrong,
                        textAlign: TextAlign.center,
                      ),
              ),
              const Spacer(),
              MicButton(listening: _listening, onPressed: _gotIt ? null : _toggleMic),
              const SizedBox(height: AppSpace.l),
            ],
          ),
        ),
      ),
    );
  }
}
