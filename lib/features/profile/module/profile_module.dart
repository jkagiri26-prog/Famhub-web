import 'package:flutter/material.dart';

import 'package:famhub_app/system/modules_control/module_contract.dart';
import 'package:famhub_app/features/profile/presentation/pages/profile_page.dart';

class ProfileModule {
  static ModuleContract register() {
    return ModuleContract(
      key: 'profile',
      name: 'Profile',
      description:
          'User profile, account settings, preferences, and identity management.',
      icon: Icons.person,
      builder: (_) => const ProfilePage(),
    );
  }
}