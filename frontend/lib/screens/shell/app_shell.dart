import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'debug_menu.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Home', Icons.home_outlined, Icons.home_rounded),
  _Destination('Practice', Icons.auto_awesome_outlined, Icons.auto_awesome),
  _Destination('Progress', Icons.insights_outlined, Icons.insights_rounded),
  _Destination('SLP/Parent', Icons.family_restroom_outlined, Icons.family_restroom_rounded),
  _Destination('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

/// Bottom navigation on phones, sidebar on wide screens (iPad).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppSize.sidebarBreakpoint;
    if (!wide) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                  icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    final learner = context.watch<AppState>().learner;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MirrorULogo(size: 24, onLongPress: () => showDebugMenu(context)),
                  const SizedBox(height: AppSpace.l),
                  if (learner != null)
                    Row(children: [
                      LearnerAvatar(learner: learner, size: 36),
                      const SizedBox(width: AppSpace.s),
                      Text(learner.name, style: AppText.bodyStrong),
                    ]),
                ],
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
