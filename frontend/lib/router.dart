import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'avatar_test_page.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'practice_page.dart';
import 'screens/diagnostic/diagnostic_results_screen.dart';
import 'screens/diagnostic/diagnostic_screen.dart';
import 'screens/grownups/grownups_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/look_and_say/look_and_say_screen.dart';
import 'screens/practice/practice_hub_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/read_aloud/read_aloud_library_screen.dart';
import 'screens/read_aloud/reading_results_screen.dart';
import 'screens/read_aloud/reading_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/testing/testing_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/word_practice/word_practice_screen.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const home = '/home';
  static const practice = '/practice';
  static const readAloud = '/practice/read';
  static const progress = '/progress';
  static const grownups = '/grownups';
  static const settings = '/settings';
  static const testing = '/settings/testing';

  // full screen, outside the tab shell
  static const diagnostic = '/diagnostic';
  static const diagnosticResults = '/diagnostic/results';
  static const lookAndSay = '/look-and-say';
  static const wordDrill = '/testing/word-drill';
  static const avatarTest = '/testing/avatar';

  static String reading(String passageId) => '/read/$passageId';
  static String readingResults(String passageId) => '/read/$passageId/results';

  /// Word Practice for one word, e.g. from the queue or a flagged Reading word.
  static String wordPractice(String word, {WordSource source = WordSource.manual}) =>
      Uri(path: '/word-practice', queryParameters: {'word': word, 'source': source.name})
          .toString();
}

// Dev only: start somewhere other than Welcome, as a demo learner, e.g.
//   flutter run --dart-define=START_ROUTE=/home --dart-define=DEMO_LEARNER=maya
const _startRoute = String.fromEnvironment('START_ROUTE', defaultValue: Routes.welcome);

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AppState state) {
  GoRoute fullScreen(String path, Widget Function(GoRouterState s) builder) => GoRoute(
        path: path,
        parentNavigatorKey: _rootKey,
        builder: (context, s) => builder(s),
      );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: _startRoute,
    refreshListenable: state,
    // nobody picked yet: everything leads to Welcome
    redirect: (context, s) {
      final atWelcome = s.matchedLocation == Routes.welcome;
      if (!state.hasLearner && !atWelcome) return Routes.welcome;
      return null;
    },
    routes: [
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, s, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.practice,
              builder: (_, _) => const PracticeHubScreen(),
              routes: [
                GoRoute(path: 'read', builder: (_, _) => const ReadAloudLibraryScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.progress, builder: (_, _) => const ProgressScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.grownups, builder: (_, _) => const GrownupsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              builder: (_, _) => const SettingsScreen(),
              routes: [
                GoRoute(path: 'testing', builder: (_, _) => const TestingScreen()),
              ],
            ),
          ]),
        ],
      ),
      fullScreen('/word-practice', (s) {
        final source = WordSource.values.asNameMap()[s.uri.queryParameters['source']];
        return WordPracticeScreen(
          word: s.uri.queryParameters['word'],
          source: source ?? WordSource.manual,
        );
      }),
      fullScreen('/read/:id', (s) => ReadingScreen(passageId: s.pathParameters['id']!)),
      fullScreen('/read/:id/results',
          (s) => ReadingResultsScreen(passageId: s.pathParameters['id']!)),
      fullScreen(Routes.diagnostic, (_) => const DiagnosticScreen()),
      fullScreen(Routes.diagnosticResults, (_) => const DiagnosticResultsScreen()),
      fullScreen(Routes.lookAndSay, (_) => const LookAndSayScreen()),
      // the original prototype screens, with the theme they were built against
      fullScreen(Routes.wordDrill, (_) => const _PrototypeTheme(child: PracticePage())),
      fullScreen(Routes.avatarTest, (_) => const _PrototypeTheme(child: AvatarTestPage())),
    ],
  );
}

class _PrototypeTheme extends StatelessWidget {
  const _PrototypeTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        child: child,
      );
}
