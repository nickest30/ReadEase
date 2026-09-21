// Basic smoke test for ReadEase.
// Full widget tests will be added in a later milestone.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readease/main.dart';
import 'package:readease/providers/settings_provider.dart';

void main() {
  testWidgets('ReadEase app boots without crashing',
      (WidgetTester tester) async {
    // Mock SharedPreferences so SettingsProvider.load() works in test env
    SharedPreferences.setMockInitialValues({});

    final settingsProvider = SettingsProvider();
    await settingsProvider.load();

    await tester.pumpWidget(ReadEaseApp(settingsProvider: settingsProvider));
    await tester.pump();

    expect(find.byType(ReadEaseApp), findsOneWidget);
  });
}