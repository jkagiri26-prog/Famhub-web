import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/finance_page.dart';

class FinanceModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'finance',
      name: 'Finance',
      description: 'Payments, loans, wallets, billing, and financial operations.',
      icon: Icons.account_balance_wallet,
      builder: () => const FinancePage(),
    );
  }
}