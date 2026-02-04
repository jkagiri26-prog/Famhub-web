import 'package:flutter/material.dart';

/// FAMHUB Module: SettingsPage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Style: Grouped configuration tiles with high-density scannability.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _biometricLogin = false;
  final String _selectedLanguage = "English (KE)";

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      // Betpawa Rule: 16.0 horizontal padding, minimal top padding
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your preferences and security.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),

            _buildSectionLabel("PREFERENCES"),
            _buildToggleTile(
              Icons.notifications_none_outlined,
              "Push Notifications",
              "Receive alerts on prices & weather",
              _notificationsEnabled,
              (val) => setState(() => _notificationsEnabled = val),
            ),
            _buildNavigationTile(Icons.language, "Language", _selectedLanguage),
            
            const SizedBox(height: 24),
            _buildSectionLabel("SECURITY"),
            _buildToggleTile(
              Icons.fingerprint,
              "Biometric Login",
              "Use FaceID or Fingerprint",
              _biometricLogin,
              (val) => setState(() => _biometricLogin = val),
            ),
            _buildNavigationTile(Icons.lock_outline, "Change PIN", "Last changed 3mo ago"),

            const SizedBox(height: 24),
            _buildSectionLabel("REGIONAL"),
            _buildNavigationTile(Icons.payments_outlined, "Default Currency", "KES (Shilling)"),
            _buildNavigationTile(Icons.location_on_outlined, "Primary Market", "Nakuru Central"),

            const SizedBox(height: 120), // BottomNav Clearance
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildToggleTile(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.black87),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        value: value,
        activeThumbColor: Theme.of(context).colorScheme.primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNavigationTile(IconData icon, String title, String trailingText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}