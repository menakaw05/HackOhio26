import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.passageId});

  final String passageId;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  // MOCK: steps the highlight along at a steady pace. Real word tracking comes from the
  // speech service later.
  static const _mockWordPace = Duration(milliseconds: 450);

  late final Passage _passage = context
      .read<AppState>()
      .passages
      .firstWhere((p) => p.id == widget.passageId);
  Timer? _timer;
  int _current = -1;

  bool get _listening => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_listening) {
      _finish();
      return;
    }
    setState(() {
      _current = 0;
      _timer = Timer.periodic(_mockWordPace, (_) {
        if (_current >= _passage.words.length - 1) {
          _finish();
        } else {
          setState(() => _current++);
        }
      });
    });
  }

  void _finish() {
    _timer?.cancel();
    setState(() => _timer = null);
    context.pushReplacement(Routes.readingResults(_passage.id));
  }

  @override
  Widget build(BuildContext context) {
    final words = _passage.words;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_passage.title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.xl),
                children: [
                  Wrap(
                    children: [
                      for (var i = 0; i < words.length; i++)
                        AnimatedContainer(
                          duration: AppMotion.fast,
                          margin: const EdgeInsets.only(right: 6, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == _current ? AppColors.lotusBlush : Colors.transparent,
                            borderRadius: AppRadius.chipRadius,
                          ),
                          child: Text(
                            words[i],
                            style: AppText.reading.copyWith(
                              color: _listening && i < _current ? AppColors.inkSoft : AppColors.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Column(
                children: [
                  Text(
                    _listening
                        ? 'Keep reading! Tap when you\'re done.'
                        : 'Tap the mic and read the story out loud.',
                    style: AppText.bodyStrong,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.m),
                  MicButton(listening: _listening, onPressed: _toggle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
