import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../stage4/golden_store.dart';
import '../../stage4/mouth_tracker.dart';
import '../../stage4/phonemes.dart';
import '../../stage4/trajectory_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Records golden takes for one phoneme: tap to start, tap to stop (auto-stops after a few
/// seconds). Each take is saved straight away.
class GoldenPhonemeScreen extends StatefulWidget {
  const GoldenPhonemeScreen({super.key, required this.ipa, this.store});

  final String ipa;
  final GoldenStore? store;

  @override
  State<GoldenPhonemeScreen> createState() => _GoldenPhonemeScreenState();
}

class _GoldenPhonemeScreenState extends State<GoldenPhonemeScreen> {
  static const _maxTake = Duration(seconds: 3);
  static const _minFrames = 5;

  late final GoldenStore _store = widget.store ?? GoldenStore.instance;
  final MouthTracker _tracker = MouthTracker();
  bool? _cameraReady;
  bool _faceFound = false;
  bool _recording = false;
  final List<MouthFrame> _buffer = [];
  Timer? _autoStop;

  // live frame rate, from the last second of frames
  final List<int> _recentFrameTimes = [];

  @override
  void initState() {
    super.initState();
    _store.load();
    _tracker.onFrame = _onFrame;
    _tracker.start().then((ok) {
      if (mounted) setState(() => _cameraReady = ok);
    });
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    _tracker.dispose();
    super.dispose();
  }

  void _onFrame(MouthFrame? frame) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentFrameTimes
      ..add(now)
      ..removeWhere((t) => now - t > 1000);
    if (_recording && frame != null) _buffer.add(frame);
    setState(() => _faceFound = frame != null);
  }

  void _toggle() {
    if (_recording) {
      _stop();
    } else {
      _buffer.clear();
      setState(() => _recording = true);
      _autoStop = Timer(_maxTake, _stop);
    }
  }

  Future<void> _stop() async {
    _autoStop?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    if (_buffer.length < _minFrames) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Didn't catch enough of your face. Try again, facing the camera.")));
      return;
    }
    // times relative to the first frame of the take
    final t0 = _buffer.first.t;
    final frames = [
      for (final f in _buffer) MouthFrame(t: f.t - t0, features: f.features, contours: f.contours)
    ];
    await _store.addTake(widget.ipa, frames);
  }

  void _next() {
    final i = goldenPhonemes.indexWhere((p) => p.ipa == widget.ipa);
    if (i < 0 || i == goldenPhonemes.length - 1) {
      context.pop();
    } else {
      context.pushReplacement(Routes.goldenPhoneme(goldenPhonemes[i + 1].ipa));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneme = goldenPhonemeFor(widget.ipa);
    if (phoneme == null) return const MissingPage(what: 'sound');

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final takes = _store.takesFor(widget.ipa);
        return AppPage(
          title: '/${phoneme.ipa}/',
          actions: [
            TextButton.icon(
              onPressed: _recording ? null : _next,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Next'),
            ),
          ],
          children: [
            Text('Say just the sound, as in "${phoneme.example}".', style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.m),
            _cameraView(),
            const SizedBox(height: AppSpace.s),
            Row(
              children: [
                Icon(Icons.circle,
                    size: 12, color: _faceFound ? AppColors.success : AppColors.inkFaint),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(_faceFound ? 'Face found' : 'Looking for your face',
                      style: AppText.caption, overflow: TextOverflow.ellipsis),
                ),
                Text('${_recentFrameTimes.length} fps', style: AppText.caption),
              ],
            ),
            const SizedBox(height: AppSpace.l),
            Center(
              child: MicButton(
                listening: _recording,
                onPressed: _cameraReady == true ? _toggle : null,
              ),
            ),
            Center(
              child: Text(
                _recording
                    ? 'Recording… tap to stop'
                    : 'Tap to record take ${takes.length + 1}',
                style: AppText.caption,
              ),
            ),
            SectionHeader(
              title: 'Takes (${takes.length} / ${GoldenStore.takesPerPhoneme})',
            ),
            if (takes.isNotEmpty) ...[
              const FeatureLegend(),
              const SizedBox(height: AppSpace.s),
            ],
            if (takes.isEmpty)
              Text('No takes yet.', style: AppText.caption)
            else
              for (final (i, take) in takes.indexed) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppSpace.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Take ${i + 1}', style: AppText.bodyStrong),
                          const SizedBox(width: AppSpace.s),
                          Expanded(
                            child: Text(
                              '${take.frames.length} frames · '
                              '${(take.durationMs / 1000).toStringAsFixed(1)}s · '
                              '${take.fps.toStringAsFixed(0)} fps',
                              style: AppText.caption,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete take ${i + 1}',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _store.deleteTake(widget.ipa, take.id),
                          ),
                        ],
                      ),
                      TrajectoryChart(series: [for (final f in take.frames) f.features]),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s),
              ],
          ],
        );
      },
    );
  }

  Widget _cameraView() {
    final controller = _tracker.controller;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        child: switch (_cameraReady) {
          null => const Center(child: CircularProgressIndicator()),
          false => const ComingSoon(
              label: 'No camera available',
              icon: Icons.videocam_off_rounded,
              height: null,
              detail: 'Record on a real iPhone.',
            ),
          true => DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _recording ? AppColors.lotus : Colors.transparent,
                  width: 4,
                ),
                borderRadius: AppRadius.cardRadius,
              ),
              child: controller == null ? const SizedBox() : CameraPreview(controller),
            ),
        },
      ),
    );
  }
}
