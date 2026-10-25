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
    final face = onPressed == null ? AppColors.inkFaint : color;
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
              child: Container(
                width: AppSize.micButton,
                height: AppSize.micButton,
                // a big candy button: white rim, darker edge underneath, soft glow
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [
                    BoxShadow(color: AppColors.edgeOf(face), offset: const Offset(0, 7)),
                    BoxShadow(color: face.withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 4),
                  ],
                ),
                child: Material(
                  shape: const CircleBorder(),
                  color: face,
                  clipBehavior: Clip.antiAlias,
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
                      size: 48,
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
                        height: 12,
                        decoration: BoxDecoration(
                          color: i == current
                              ? AppColors.lotus
                              : (i < current && !locked.contains(i) ? AppColors.lake : AppColors.lakeMist),
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

/// One star per attempt, colored by how it went; empty stars are attempts left.
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
          // a star per try: gold when it was great, the result's color otherwise
          for (var i = 0; i < total; i++)
            Icon(
              i < results.length ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 30,
              color: i >= results.length
                  ? AppColors.inkFaint
                  : (results[i] == FeedbackKind.success ? AppColors.sun : results[i].color),
            ),
        ],
      ),
    );
  }
}
