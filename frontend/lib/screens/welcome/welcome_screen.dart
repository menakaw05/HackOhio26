import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../shell/debug_menu.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: OceanBackdrop(
        gradient: AppGradients.lakeDawn,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              const SizedBox(height: AppSpace.xl),
              Center(
                child: EchoLogo(size: 40, onLongPress: () => showDebugMenu(context)),
              ),
              const SizedBox(height: AppSpace.xs),
              Text('See it. Say it. Shine!',
                  style: AppText.section.copyWith(color: AppColors.lotusDeep), textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.s),
              const Center(child: BelugaBuddy(size: 180)),
              const SizedBox(height: AppSpace.l),
              Text("Who's practicing today?", style: AppText.title, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.l),
              for (final (i, learner) in state.learners.indexed) ...[
                FadeSlideIn(
                  index: i,
                  child: _LearnerCard(
                    learner: learner,
                    onTap: () {
                      state.selectLearner(learner.id);
                      context.go(Routes.home);
                    },
                  ),
                ),
                const SizedBox(height: AppSpace.m),
              ],
              AppCard(
                semanticLabel: 'Add a learner',
                color: AppColors.surface.withValues(alpha: 0.7),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adding learners is coming soon.'))),
                child: Row(children: [
                  const CircleAvatar(
                    radius: AppSize.avatar / 2,
                    backgroundColor: AppColors.lakeMist,
                    child: Icon(Icons.add_rounded, color: AppColors.lake),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Flexible(child: Text('Add a learner', style: AppText.section)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({required this.learner, required this.onTap});

  final Learner learner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: '${learner.name}, ${learner.streak} day streak',
      child: Row(
        children: [
          LearnerAvatar(learner: learner, size: 56),
          const SizedBox(width: AppSpace.m),
          Expanded(child: Text(learner.name, style: AppText.title)),
          if (learner.streak > 0)
            TagBadge(
              label: '🌊 ${learner.streak} days',
              color: AppColors.lotusDeep,
              background: AppColors.lotusBlush,
            ),
          const SizedBox(width: AppSpace.s),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
