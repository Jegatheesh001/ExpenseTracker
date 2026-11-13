import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/services/assistant_action_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AssistantActionService();

  test('parses the wallet balance action', () {
    final request = service.parse(
      Uri.parse('app://com.jegatheesh.expensetracker/open?featureName=wallet'),
    );

    expect(request, isA<WalletBalanceRequest>());
  });

  test('parses and validates a voice expense draft', () {
    final request = service.parse(
      Uri.parse(
        'app://com.jegatheesh.expensetracker/add-expense'
        '?expenseName=tea&categoryName=food&amount=2.50',
      ),
    );

    expect(request, isA<AddExpenseRequest>());
    final expense = request! as AddExpenseRequest;
    expect(expense.remarks, 'tea');
    expect(expense.categoryName, 'food');
    expect(expense.amount, 2.5);
    expect(
      expense.matchCategory([Category(1, 'Food'), Category(2, 'Transport')]),
      isNotNull,
    );
    expect(expense.matchCategory([Category(1, 'Food')])!.categoryId, 1);
  });

  test('category matching ignores case and repeated whitespace', () {
    const request = AddExpenseRequest(
      remarks: 'tea',
      categoryName: '  food   and drinks ',
      amount: 2.5,
    );

    expect(
      request.matchCategory([Category(9, 'Food and Drinks')])?.categoryId,
      9,
    );
  });

  test('rejects non-positive and non-finite amounts', () {
    for (final amount in ['0', '-2.5', 'NaN', 'Infinity']) {
      final request = service.parse(
        Uri.parse(
          'app://com.jegatheesh.expensetracker/add-expense'
          '?expenseName=tea&categoryName=food&amount=$amount',
        ),
      );

      expect(request, isA<InvalidAssistantActionRequest>());
    }
  });

  test('rejects missing fields and ignores unrelated links', () {
    expect(
      service.parse(
        Uri.parse(
          'app://com.jegatheesh.expensetracker/add-expense?amount=2.50',
        ),
      ),
      isA<InvalidAssistantActionRequest>(),
    );
    expect(service.parse(Uri.parse('https://example.com/add-expense')), isNull);
  });
}
