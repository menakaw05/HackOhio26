import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'feedback_banner.dart';
import 'motion.dart';

/// Big round mic button with a gentle pulse while listening.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.listening, required this.onPressed});

  final bool listening;
  final VoidCallback? onPressed;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  void _sync() {
    if (widget.listening && !reduceMotion(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (old.listening != widget.listening) _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    final color = widget.listening ? AppColors.lotus : AppColors.lake;
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop listening' : 'Start talking',
      child: SizedBox.square(
        dimension: AppSize.micButton * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // expanding, fading ring behind the button
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => _pulse.value == 0
                  ? const SizedBox.shrink()
                  : Container(
                      width: AppSize.micButton * (1 + 0.5 * _pulse.value),
                      height: AppSize.micButton * (1 + 0.5 * _pulse.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.35 * (1 - _pulse.value)),
                      ),
                    ),
            ),
            PressScale(
              enabled: onPressed != null,
              child: SizedBox.square(
                dimension: AppSize.micButton,
                child: Material(
                  shape: const CircleBorder(),
                  color: onPressed == null ? AppColors.inkFaint : color,
                  elevation: 4,
                  shadowColor: AppColors.shadow,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPressed == null
                        ? null
                        : () {
                            AppHaptics.tap();
                            onPressed();
                          },
                    child: Icon(
                      widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hear → Watch → Try → Feedback.
class StepperBar extends StatelessWidget {
  const StepperBar({
    super.key,
    required this.steps,
    required this.current,
    this.onStepTap,
    this.locked = const {},
  });

  final List<String> steps;
  final int current;
  final ValueChanged<int>? onStepTap;

  /// Steps that can't be opened yet; shown faded.
  final Set<int> locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Semantics(
              button: onStepTap != null && !locked.contains(i),
              selected: i == current,
              label: 'Step ${i + 1}: ${steps[i]}${locked.contains(i) ? ', locked' : ''}',
              child: InkWell(
                borderRadius: AppRadius.pillRadius,
                onTap: onStepTap == null || locked.contains(i) ? null : () => onStepTap!(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSize.minTouch),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.medium,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= current && !locked.contains(i)
                              ? AppColors.lake
                              : AppColors.lakeMist,
                          borderRadius: AppRadius.pillRadius,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        steps[i],
                        style: (i == current ? AppText.bodyStrong : AppText.caption).copyWith(
                          color: i == current
                              ? AppColors.lakeDeep
                              : (locked.contains(i) ? AppColors.inkFaint : null),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (i < steps.length - 1) const SizedBox(width: AppSpace.xs),
        ],
      ],
    );
  }
}

/// One dot per attempt, colored by how it went; empty dots are attempts left.
class AttemptDots extends StatelessWidget {
  const AttemptDots({super.key, required this.total, required this.results});

  final int total;
  final List<FeedbackKind> results;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Attempt ${results.length} of $total',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < results.length ? results[i].color : null,
                border: Border.all(
                  color: i < results.length ? results[i].color : AppColors.inkFaint,
                  width: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
