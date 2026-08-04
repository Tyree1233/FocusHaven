import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/main.dart';

void main() {
  testWidgets('shows the FocusHaven welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusHavenApp());

    expect(find.text('Welcome to FocusHaven'), findsOneWidget);
    expect(find.text('Begin focus'), findsOneWidget);
  });
}
