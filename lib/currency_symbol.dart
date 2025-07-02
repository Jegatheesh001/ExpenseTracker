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
        currencySymbol = '₹'; // Default to rupee if currency is unknown
    }
    return currencySymbol;
  }
  String getLabel(String currency) {
    String currencySymbol;
    switch (currency) {
      case 'Rupee':
        currencySymbol = 'INR';
        break;
      case 'Dirham':
        currencySymbol = 'AED';
        break;
      case 'Dollar':
        currencySymbol = 'USD';
        break;
      default:
        currencySymbol = 'INR'; // Default to INR if currency is unknown
    }
    return currencySymbol;
  }
}