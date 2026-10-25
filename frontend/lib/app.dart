import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'router.dart';
import 'theme/app_theme.dart';

// Dev only: skip the profile picker, e.g. --dart-define=DEMO_LEARNER=maya
const _demoLearner = String.fromEnvironment('DEMO_LEARNER');

class MirrorUApp extends StatefulWidget {
  const MirrorUApp({super.key});

  @override
  State<MirrorUApp> createState() => _MirrorUAppState();
}

class _MirrorUAppState extends State<MirrorUApp> {
  late final AppState _state = AppState();
  late final GoRouter _router = buildRouter(_state);

  @override
  void initState() {
    super.initState();
    if (_demoLearner.isNotEmpty) _state.selectLearner(_demoLearner);
  }

  @override
  void dispose() {
    _router.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: ChangeNotifierProvider.value(
        value: _state.queue,
        child: MaterialApp.router(
          title: 'mirrorU',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: _router,
        ),
      ),
    );
  }
}
