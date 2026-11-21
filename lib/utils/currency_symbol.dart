class CurrencySymbol {
  String getSymbol(String currency) => switch (getCode(currency)) {
    'INR' => '₹',
    'AED' => 'د.إ',
    'USD' => r'$',
    'GBP' => '£',
    'EUR' => '€',
    final code => code ?? '₹',
  };

  String getLabel(String currency) => getCode(currency) ?? 'INR';

  String? getCode(String currency) {
    final normalized = currency.trim().toUpperCase();
    return switch (normalized) {
      'RUPEE' => 'INR',
      'DIRHAM' => 'AED',
      'DOLLAR' => 'USD',
      'POUND' => 'GBP',
      'EURO' => 'EUR',
      _ => RegExp(r'^[A-Z]{3}$').hasMatch(normalized) ? normalized : null,
    };
  }

  bool matches(String first, String second) {
    final code = getCode(first);
    return code != null && code == getCode(second);
  }

  List<String> getCurrencies() {
    return ['Rupee', 'Dirham', 'Dollar', 'Pound', 'Euro'];
  }
}
