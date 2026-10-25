import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class _SampleObject {
  const _SampleObject(this.word, this.icon);

  final String word;
  final IconData icon;
}

/// PROTOTYPE mode: pre-picked objects stand in for real-time detection.
const _sampleObjects = [
  _SampleObject('moon', Icons.nightlight_round),
  _SampleObject('cat', Icons.pets_rounded),
  _SampleObject('ball', Icons.sports_baseball_rounded),
  _SampleObject('spoon', Icons.restaurant_rounded),
  _SampleObject('star', Icons.star_rounded),
  _SampleObject('fish', Icons.set_meal_rounded),
];

class LookAndSayScreen extends StatefulWidget {
  const LookAndSayScreen({super.key});

  @override
  State<LookAndSayScreen> createState() => _LookAndSayScreenState();
}

class _LookAndSayScreenState extends State<LookAndSayScreen> {
  _SampleObject? _detected;

  @override
  Widget build(BuildContext context) {
    final detected = _detected;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Look & Say'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpace.l),
            child: Center(child: TagBadge(label: 'Prototype')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.xxl),
          children: [
            Text('Point the camera at something and say its name.', style: AppText.bodyStrong),
            const SizedBox(height: AppSpace.m),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppGradients.stage,
                  borderRadius: AppRadius.cardRadius,
                ),
                padding: const EdgeInsets.all(AppSpace.m),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ComingSoon(
                        label: 'Camera view',
                        icon: Icons.videocam_rounded,
                        height: null,
                        detail: 'Object detection is coming soon.',
                      ),
                    ),
                    if (detected != null) _DetectionBox(object: detected),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.l),
            Text('Prototype: pick an object to pretend the camera spotted it.',
                style: AppText.caption),
            const SizedBox(height: AppSpace.s),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                for (final o in _sampleObjects)
                  ChoiceChip(
                    avatar: Icon(o.icon, size: 18),
                    label: Text(o.word),
                    selected: detected == o,
                    onSelected: (_) => setState(() => _detected = o),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: detected == null ? 'Find something to say' : 'Say "${detected.word}"',
              icon: Icons.record_voice_over_rounded,
              expand: true,
              onPressed: detected == null
                  ? null
                  : () => context.push(
                      Routes.wordPractice(detected.word, source: WordSource.lookAndSay)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pretend bounding box with the detected label, over the camera area.
class _DetectionBox extends StatelessWidget {
  const _DetectionBox({required this.object});

  final _SampleObject object;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.1),
      child: FractionallySizedBox(
        widthFactor: 0.6,
        heightFactor: 0.45,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.lotus, width: 4),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(object.icon, size: 72, color: AppColors.lotusDeep)),
              Positioned(
                left: AppSpace.s,
                top: -16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.xs),
                  decoration: const BoxDecoration(
                    color: AppColors.lotus,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(object.word,
                      style: AppText.bodyStrong.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
