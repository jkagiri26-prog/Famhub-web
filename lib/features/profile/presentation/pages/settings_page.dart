import 'package:flutter/material.dart';

import '../../../../shared/layouts/responsive_wrappers_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';
import '../../../../shared/layouts/section_container_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notifications = true;
  bool biometrics = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          /// HEADER
          ModuleHeaderWidget(
            title: "Settings",
            subtitle: "Preferences ? Security ? Region",
            trailingIcon: Icons.tune,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 20),

          const SectionHeaderWidget(title: "Preferences"),

          const SizedBox(height: 12),

          _SwitchTile(
            icon: Icons.notifications,
            title: "Push Notifications",
            subtitle: "Price & weather alerts",
            value: notifications,
            onChanged: (v) => setState(() => notifications = v),
          ),

          const SizedBox(height: 8),

          _SwitchTile(
            icon: Icons.fingerprint,
            title: "Biometric Login",
            subtitle: "FaceID / Fingerprint",
            value: biometrics,
            onChanged: (v) => setState(() => biometrics = v),
          ),

          const SizedBox(height: 20),

          const SectionHeaderWidget(title: "Security"),

          const SizedBox(height: 12),

          const _NavTile(
            icon: Icons.lock,
            title: "Change PIN",
            trailing: "Last changed 3mo ago",
          ),

          const SizedBox(height: 20),

          const SectionHeaderWidget(title: "Region"),

          const SizedBox(height: 12),

          const _NavTile(
            icon: Icons.location_on,
            title: "Primary Market",
            trailing: "Nakuru",
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// LOCAL ONLY (NOT SHARED YET)
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(trailing),
        onTap: () {},
      ),
    );
  }
}