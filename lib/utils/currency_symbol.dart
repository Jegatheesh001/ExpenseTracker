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
      case 'Pound':
        currencySymbol = '£';
        break;
      case 'Euro':
        currencySymbol = '€';
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
      case 'Pound':
        currencySymbol = 'GBP';
        break;
      case 'Euro':
        currencySymbol = 'EUR';
        break;
      default:
        currencySymbol = 'INR'; // Default to INR if currency is unknown
    }
    return currencySymbol;
  }
  List<String> getCurrencies() {
    return ['Rupee', 'Dirham', 'Dollar', 'Pound', 'Euro'];
  }
}