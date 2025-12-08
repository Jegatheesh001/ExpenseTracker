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
