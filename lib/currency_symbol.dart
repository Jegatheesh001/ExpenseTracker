class CurrencySymbol {
  String getSymbol(String currency) {
    String currencySymbol;
    switch (currency) {
      case 'Rupee':
        currencySymbol = '₹';
        break;
      case 'Dirham':
        currencySymbol = 'د.إ';
        break;
      case 'Dollar':
        currencySymbol = '\$';
        break;
      default:
        currencySymbol = '₹'; // Default to dollar if currency is unknown
    }
    return currencySymbol;
  }
}