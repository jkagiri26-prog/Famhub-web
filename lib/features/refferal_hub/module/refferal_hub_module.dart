import 'package:flutter/material.dart';

import '../../system/models/module_definition.dart';
import '../presentation/pages/referral_hub_page.dart';

class ReferralHubModule {
  static ModuleDefinition register() {
    return ModuleDefinition(
      key: 'referral_hub',
      name: 'Referral Hub',
      description: 'Referrals, affiliate programs, and growth campaigns.',
      icon: Icons.share,
      builder: () => const ReferralHubPage(),
    );
  }
}