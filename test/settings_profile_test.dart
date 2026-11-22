import 'package:expense_tracker/screens/settings/settings_screen.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('highlights the active profile in $brightness mode', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.profileId: 1,
        '${PrefKeys.selectedCurrency}-0': 'Dirham',
        '${PrefKeys.selectedCurrency}-1': 'Dirham',
      });
      var profileChanges = 0;
      final theme = ThemeData(brightness: brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: SettingsScreen(
            onThemeToggle: () {},
            onCurrencyToggle: () {},
            onStatusBarToggle: () {},
            onMonthlyLimitSaved: (_) {},
            onWalletAmountUpdated: () {},
            onDeleteAllData: () {},
            onProfileChange: () => profileChanges++,
            onUsernameChange: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final active = find.text('Active profile #1 · AED');
      final label = tester.widget<Text>(active);
      expect(label.style?.color, theme.colorScheme.primary);
      expect(label.style?.fontWeight, FontWeight.w600);
      await tester.tap(find.text('Switch Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Switch'));
      await tester.pumpAndSettle();

      expect(find.text('Active profile #0 · AED'), findsOneWidget);
      expect(active, findsNothing);
      expect(profileChanges, 1);
      expect(
        (await SharedPreferences.getInstance()).getInt(PrefKeys.profileId),
        0,
      );
    });
  }
}
