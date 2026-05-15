import 'package:flutter/material.dart';

import '../../../system/modules_control/module_contract.dart';
import '../presentation/pages/profile_page.dart';

class ProfileModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'profile',
      name: 'Profile',
      description:
          'User profile, account settings, preferences, and identity management.',
      icon: Icons.person,
      builder: () => const ProfilePage(),
    );
  }
}