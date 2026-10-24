import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Record page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Text to say'), findsOneWidget);
  });
}
