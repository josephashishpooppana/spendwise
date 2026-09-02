import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spendwise_mobile/data/models/models.dart';

class AppTheme {
  static ThemeData light() {
    const seed = Color(0xFF0F766E);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class Formatters {
  static final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final date = DateFormat('dd MMM yyyy');
  static final dateTime = DateFormat('dd MMM yyyy, HH:mm');

  static String txnType(TransactionType type) =>
      type == TransactionType.income ? 'Income' : 'Expense';

  static String categoryLabel(String key) =>
      key.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

const expenseCategories = [
  'groceries',
  'rent',
  'utilities',
  'food_dining',
  'transport',
  'entertainment',
  'shopping',
  'health',
  'education',
  'subscriptions',
  'insurance',
  'travel',
  'personal_care',
  'other',
];

const incomeCategories = [
  'salary',
  'freelance',
  'investment_returns',
  'refund',
  'gift',
  'reimbursement',
  'cashback',
];
