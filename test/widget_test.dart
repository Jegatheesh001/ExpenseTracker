import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/currency_symbol.dart';

void main() {
  group('CurrencySymbol Tests', () {
    final currencyHelper = CurrencySymbol();

    test('getSymbol returns correct symbols', () {
      expect(currencyHelper.getSymbol('Rupee'), '₹');
      expect(currencyHelper.getSymbol('Dirham'), 'د.إ');
      expect(currencyHelper.getSymbol('Dollar'), '\$');
      expect(currencyHelper.getSymbol('Pound'), '£');
      expect(currencyHelper.getSymbol('Euro'), '€');
      expect(currencyHelper.getSymbol('Unknown'), '₹'); // Default case
    });

    test('getLabel returns correct ISO codes', () {
      expect(currencyHelper.getLabel('Rupee'), 'INR');
      expect(currencyHelper.getLabel('Dirham'), 'AED');
      expect(currencyHelper.getLabel('Dollar'), 'USD');
      expect(currencyHelper.getLabel('Pound'), 'GBP');
      expect(currencyHelper.getLabel('Euro'), 'EUR');
      expect(currencyHelper.getLabel('Unknown'), 'INR'); // Default case
    });

    test('getCurrencies returns list of supported currencies', () {
      final currencies = currencyHelper.getCurrencies();
      expect(currencies, containsAll(['Rupee', 'Dirham', 'Dollar', 'Pound', 'Euro']));
      expect(currencies.length, 5);
    });
  });
}
