import 'dart:math';

import 'package:flutter/material.dart';

IconData getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.fastfood;
    case 'transport':
      return Icons.directions_car;
    case 'shopping':
      return Icons.shopping_bag;
    case 'bills':
      return Icons.receipt;
    case 'health':
      return Icons.local_hospital;
    case 'utilities':
      return Icons.build;
    case 'entertainment':
      return Icons.movie;
    case 'education':
      return Icons.school;
    case 'travel':
      return Icons.flight;
    case 'gift':
      return Icons.card_giftcard;
    case 'salary':
      return Icons.attach_money;
    default:
      return Icons.category; // A default icon
  }
}

String getRandomBudgetTip() {
  final random = Random();
  var tips = [
      "Track small purchases like coffee and snacks. They add up quickly and are the easiest expenses to reduce!",
      "Implement the 24-hour rule for impulse buys. If you want something non-essential, wait a day before buying to see if the urge passes.",
      "Follow the 50/30/20 rule: allocate 50% to needs, 30% to wants, and 20% to savings and debt repayment.",
      "Audit your monthly subscriptions. Cancel any streaming services or memberships you haven't used in the last 30 days.",
      "Never go grocery shopping while hungry. You are statistically more likely to buy unnecessary snacks and expensive convenience foods.",
      "Automate your savings. Set up a direct transfer to your savings account on payday so you save before you have a chance to spend.",
      "Switch to generic or store-brand products. They often have the exact same ingredients as name brands but cost significantly less.",
      "Use the cash envelope system for discretionary spending. When the cash in the 'Dining Out' envelope is gone, you stop spending.",
      "Plan your meals for the week every Sunday. This reduces food waste and prevents last-minute, expensive takeout orders.",
      "Unplug electronics when not in use. Phantom energy usage from devices in standby mode can inflate your electricity bill.",
      "Check your local library before buying books or movies. Many libraries also offer free digital audiobooks and streaming services.",
      "Challenge yourself to a 'No-Spend Weekend' once a month. Find free entertainment like hiking, board games, or visiting public parks.",
      "Buy out-of-season clothing. Winter coats are cheapest in the summer, and swimsuits are cheapest in the fall.",
      "Create a zero-based budget. Give every dollar a job so that your income minus your expenses equals zero at the start of the month.",
      "Drink water instead of soda or alcohol when dining out. Beverages have the highest markup in restaurants.",
      "Shop around for insurance rates annually. You can often lower your car or renters insurance premiums just by switching providers.",
      "Use a specific list for every shopping trip. If an item isn't on the list, do not put it in the cart.",
      "Sell items you no longer use on online marketplaces. Use the profit to pad your emergency fund or pay down debt.",
      "Take advantage of cashback apps and coupons. Even saving a few dollars per trip compounds into significant savings over a year.",
      "Prioritize building an emergency fund. having \$1,000 set aside prevents you from using high-interest credit cards when unexpected costs arise.",
      "Learn basic repairs like sewing buttons or fixing leaks. Extending the life of items is cheaper than replacing them immediately.",
      "Buy non-perishable staples in bulk, but only if you have the storage space and will actually use them before they expire.",
      "Unsubscribe from marketing emails. Flash sales create a false sense of urgency that leads to unplanned spending.",
      "Switch to LED light bulbs. They use up to 90% less energy and last 25 times longer than traditional incandescent bulbs.",
      "Bring your lunch to work. Buying lunch daily costs \$10-\$15, while a packed lunch usually costs less than \$3.",
      "Negotiate your bills. Call your internet or cable provider and ask for the current promotional rate or a loyalty discount.",
      "Use loyalty programs for places you shop frequently, but don't let points tempt you into buying things you don't need.",
      "Make your own cleaning supplies. Vinegar, baking soda, and lemon are effective and much cheaper than chemical cleaners.",
      "Carpool or use public transportation. Reducing your driving cuts down on gas, maintenance, and vehicle depreciation.",
      "Review your bank statements weekly. This helps you catch errors, fraud, or forgotten subscriptions immediately."
  ];
  return tips[random.nextInt(tips.length)];
}
