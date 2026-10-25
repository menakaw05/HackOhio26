import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../shell/switch_learner.dart';

enum _Speed { slower, normal, faster }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // UI only for now: kept while the app is open, not saved or acted on
  bool _reminders = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 16, minute: 0);
  _Speed _speed = _Speed.normal;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) setState(() => _reminderTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final learner = context.watch<AppState>().learner;
    return AppPage(
      title: 'Settings',
      children: [
        const SectionHeader(title: 'Profile'),
        AppCard(
          child: Column(
            children: [
              if (learner != null)
                Row(
                  children: [
                    LearnerAvatar(learner: learner, size: 56),
                    const SizedBox(width: AppSpace.m),
                    Expanded(child: Text(learner.name, style: AppText.title)),
                  ],
                ),
              const SizedBox(height: AppSpace.m),
              SecondaryButton(
                label: 'Switch learner',
                icon: Icons.swap_horiz_rounded,
                expand: true,
                onPressed: () => confirmSwitchLearner(context),
              ),
            ],
          ),
        ),
        const _PreviewHeader(title: 'Practice reminders'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Daily reminder', style: AppText.bodyStrong),
                value: _reminders,
                onChanged: (v) => setState(() => _reminders = v),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: _reminders,
                title: Text('Time', style: AppText.bodyStrong),
                trailing: Text(_reminderTime.format(context), style: AppText.bodyText),
                onTap: _pickTime,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Camera & microphone'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
          child: const Column(
            children: [
              _PermissionRow(icon: Icons.videocam_rounded, label: 'Camera'),
              Divider(),
              _PermissionRow(icon: Icons.mic_rounded, label: 'Microphone'),
            ],
          ),
        ),
        const _PreviewHeader(title: 'Coach'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Avatar', style: AppText.bodyStrong),
              const SizedBox(height: AppSpace.s),
              const ComingSoon(
                label: 'Choose your avatar coach',
                icon: Icons.face_retouching_natural_rounded,
                height: 120,
              ),
              const SizedBox(height: AppSpace.l),
              Text('Speech speed', style: AppText.bodyStrong),
              const SizedBox(height: AppSpace.s),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Speed>(
                  segments: const [
                    ButtonSegment(value: _Speed.slower, label: Text('Slower')),
                    ButtonSegment(value: _Speed.normal, label: Text('Normal')),
                    ButtonSegment(value: _Speed.faster, label: Text('Faster')),
                  ],
                  selected: {_speed},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _speed = s.first),
                ),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'More'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.science_rounded, color: AppColors.lake),
                title: Text('Testing', style: AppText.bodyStrong),
                subtitle: Text('Working prototypes', style: AppText.caption),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go(Routes.testing),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_rounded, color: AppColors.lake),
                title: Text('About & credits', style: AppText.bodyStrong),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'echo-me',
                  applicationVersion: '0.1.0 (prototype)',
                  applicationLegalese:
                      'Built at HackOhio 2026. A practice aid that works alongside a '
                      'speech-language pathologist.\n\n'
                      'Fonts: Nunito and Inter, SIL Open Font License 1.1.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section header for settings that don't do anything yet.
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.s),
      child: Row(
        children: [
          Flexible(child: Semantics(header: true, child: Text(title, style: AppText.section))),
          const SizedBox(width: AppSpace.s),
          const TagBadge(label: 'Preview'),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.lake),
      title: Text(label, style: AppText.bodyStrong),
      subtitle: Text('Status check coming soon', style: AppText.caption),
    );
  }
}
