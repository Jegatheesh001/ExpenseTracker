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
    default:
      return Icons.category; // A default icon
  }
}
