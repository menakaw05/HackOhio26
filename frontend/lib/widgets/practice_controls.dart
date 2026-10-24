import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'feedback_banner.dart';

/// Big round mic button. The listening animation is added in the polish pass.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.listening, required this.onPressed});

  final bool listening;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Start talking',
      child: SizedBox.square(
        dimension: AppSize.micButton,
        child: Material(
          shape: const CircleBorder(),
          color: listening ? AppColors.lotus : AppColors.lake,
          elevation: 4,
          shadowColor: AppColors.shadow,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hear → Watch → Try → Feedback.
class StepperBar extends StatelessWidget {
  const StepperBar({super.key, required this.steps, required this.current, this.onStepTap});

  final List<String> steps;
  final int current;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Semantics(
              button: onStepTap != null,
              selected: i == current,
              label: 'Step ${i + 1}: ${steps[i]}',
              child: InkWell(
                borderRadius: AppRadius.pillRadius,
                onTap: onStepTap == null ? null : () => onStepTap!(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSize.minTouch),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.medium,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= current ? AppColors.lake : AppColors.lakeMist,
                          borderRadius: AppRadius.pillRadius,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        steps[i],
                        style: (i == current ? AppText.bodyStrong : AppText.caption)
                            .copyWith(color: i == current ? AppColors.lakeDeep : null),
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
