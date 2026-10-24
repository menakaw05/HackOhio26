import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.page, AppSpace.s, AppSpace.page, AppSpace.xxl),
          children: children,
        ),
      ),
    );
  }
}
