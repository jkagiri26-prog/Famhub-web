import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import '../presentation/pages/referral_hub_page.dart';

class ReferralHubModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'referral_hub',
      name: 'Referral Hub',
      description: 'Referrals, affiliate programs, and growth campaigns.',
      icon: Icons.share,
      builder: (_) => const ReferralHubPage(),
    );
  }
}