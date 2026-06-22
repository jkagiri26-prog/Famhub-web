import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CarbonTransaction {
  final String projectName;
  final double amountKg;
  final DateTime date;

  CarbonTransaction({
    required this.projectName,
    required this.amountKg,
    required this.date,
  });
}

class CarbonProvider extends ChangeNotifier {
  double _totalBalance = 1250.50;
  double _communityFund = 450.00;
  final List<CarbonTransaction> _transactions = [
    CarbonTransaction(projectName: 'Mau Forest Reforestation', amountKg: 50.0, date: DateTime.now()),
  ];

  double get totalBalance => _totalBalance;
  double get communityFund => _communityFund;
  List<CarbonTransaction> get transactions => _transactions;

  void processTrade(String name, double kg, double price) {
    _totalBalance += kg;
    // 10% of price goes to community fund
    _communityFund += (price * 0.1);
    
    _transactions.insert(0, CarbonTransaction(
      projectName: name,
      amountKg: kg,
      date: DateTime.now(),
    ));
    
    notifyListeners();
  }
}