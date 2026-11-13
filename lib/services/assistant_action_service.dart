import 'package:expense_tracker/db/entity.dart';

sealed class AssistantActionRequest {
  const AssistantActionRequest();
}

class WalletBalanceRequest extends AssistantActionRequest {
  const WalletBalanceRequest();
}

class AddExpenseRequest extends AssistantActionRequest {
  const AddExpenseRequest({
    required this.remarks,
    required this.categoryName,
    required this.amount,
  });

  final String remarks;
  final String categoryName;
  final double amount;

  Category? matchCategory(Iterable<Category> categories) {
    final expected = _normalizeText(categoryName);
    for (final category in categories) {
      if (_normalizeText(category.category) == expected) {
        return category;
      }
    }
    return null;
  }
}

class InvalidAssistantActionRequest extends AssistantActionRequest {
  const InvalidAssistantActionRequest(this.message);

  final String message;
}

class AssistantActionService {
  const AssistantActionService();

  static const String _scheme = 'app';
  static const String _host = 'com.jegatheesh.expensetracker';
  static const int _maximumTextLength = 200;

  AssistantActionRequest? parse(Uri uri) {
    if (uri.scheme.toLowerCase() != _scheme ||
        uri.host.toLowerCase() != _host) {
      return null;
    }

    if (uri.path == '/open' &&
        uri.queryParameters['featureName']?.toLowerCase() == 'wallet') {
      return const WalletBalanceRequest();
    }

    if (uri.path != '/add-expense') {
      return null;
    }

    final remarks = _validatedText(uri.queryParameters['expenseName']);
    final categoryName = _validatedText(uri.queryParameters['categoryName']);
    final amount = double.tryParse(uri.queryParameters['amount']?.trim() ?? '');

    if (remarks == null) {
      return const InvalidAssistantActionRequest(
        'The expense description is missing or invalid.',
      );
    }
    if (categoryName == null) {
      return const InvalidAssistantActionRequest(
        'The expense category is missing or invalid.',
      );
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      return const InvalidAssistantActionRequest(
        'The expense amount must be greater than zero.',
      );
    }

    return AddExpenseRequest(
      remarks: remarks,
      categoryName: categoryName,
      amount: amount,
    );
  }

  static String? _validatedText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed.length > _maximumTextLength ||
        trimmed.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
      return null;
    }
    return trimmed;
  }
}

String _normalizeText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
