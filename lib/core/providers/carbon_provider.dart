import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CarbonProvider with ChangeNotifier {
  static const String _boxName = 'carbon_credit_cache';
  static const String _balanceKey = 'current_balance';

  double _balance = 0.0;
  
  double get balance => _balance;

  /// Load the saved balance from Hive during initialization
  Future<void> loadCarbonData() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    
    final box = Hive.box(_boxName);
    _balance = box.get(_balanceKey, defaultValue: 0.0);
    notifyListeners();
  }

  /// Update balance and persist to Hive
  Future<void> updateBalance(double value) async {
    _balance = value;
    final box = Hive.box(_boxName);
    await box.put(_balanceKey, _balance);
    
    notifyListeners();
  }

  /// Helper for incremental updates (e.g., after a successful sequestration action)
  Future<void> creditBalance(double amount) async {
    await updateBalance(_balance + amount);
  }
}