import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'ocean.dart';
import 'states.dart';

/// Standard scrollable page: app bar + padded list.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.titleWidget,
    this.actions,
    this.leading,
  });

  final String title;
  final Widget? titleWidget;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: titleWidget ?? Text(title),
        actions: actions,
        leading: leading,
      ),
      body: OceanBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.xxl),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Full-screen friendly error for a route or item that doesn't exist.
class MissingPage extends StatelessWidget {
  const MissingPage({super.key, required this.what});

  final String what;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ErrorState(
          title: "We couldn't find that $what",
          message: "It may have moved. Let's head back home.",
          actionLabel: 'Go home',
          onAction: () => context.go('/home'),
        ),
      ),
    );
  }
}
