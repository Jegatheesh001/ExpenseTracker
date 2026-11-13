import 'package:expense_tracker/widgets/expense_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildMenu({
    VoidCallback? onAdd,
    VoidCallback? onSearch,
    VoidCallback? onFilter,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: ExpenseActionMenu(
            onAdd: onAdd ?? () {},
            onSearch: onSearch ?? () {},
            onFilter: onFilter ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'search and filter start hidden and an upward swipe reveals them',
    (tester) async {
      await tester.pumpWidget(buildMenu());

      expect(find.byKey(const Key('expense_search_action')), findsNothing);
      expect(
        find.byKey(const Key('expense_category_filter_action')),
        findsNothing,
      );
      expect(find.byKey(const Key('expense_menu_swipe_hint')), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('expense_add_swipe_target')),
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_search_action')), findsOneWidget);
      expect(
        find.byKey(const Key('expense_category_filter_action')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('expense_menu_swipe_hint')), findsNothing);

      await tester.drag(
        find.byKey(const Key('expense_add_swipe_target')),
        const Offset(0, 60),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense_search_action')), findsNothing);
      expect(
        find.byKey(const Key('expense_category_filter_action')),
        findsNothing,
      );
      expect(find.byKey(const Key('expense_menu_swipe_hint')), findsOneWidget);
    },
  );

  testWidgets('tapping add still runs the primary action', (tester) async {
    var addCount = 0;
    await tester.pumpWidget(buildMenu(onAdd: () => addCount++));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(addCount, 1);
  });

  testWidgets('secondary action runs and collapses the menu', (tester) async {
    var searchCount = 0;
    await tester.pumpWidget(buildMenu(onSearch: () => searchCount++));
    await tester.drag(
      find.byKey(const Key('expense_add_swipe_target')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expense_search_action')));
    await tester.pumpAndSettle();

    expect(searchCount, 1);
    expect(find.byKey(const Key('expense_search_action')), findsNothing);
  });
}
