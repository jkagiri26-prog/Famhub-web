/// ============================================================
/// ROLE SELECTION SCREEN — Multi-select stakeholder capabilities
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Allow multi-selection of stakeholder roles (capabilities)
///   - Roles define what content modules emphasize, not identity
///   - Show role descriptions to guide selection
///
/// ✅ DESIGN:
///   - Multiple roles can be selected (chip-style)
///   - "Continue" only enabled when at least one is selected
///   - Roles are saved to session after selection
///
/// ❌ Does NOT:
///   - Restrict or filter content
///   - Gate features by role
///   - Send role data to backend
/// ============================================================

import 'package:flutter/material.dart';

/// Represents a stakeholder role/capability.
class StakeholderRole {
  final String id;
  final String label;
  final IconData icon;
  final String description;

  const StakeholderRole({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
  });
}

/// Available roles (capabilities, not identity labels)
/// Users can select multiple — these personalize the experience
/// but do not restrict platform access.
const List<StakeholderRole> availableRoles = [
  StakeholderRole(
    id: 'farmer',
    label: 'Farmer',
    icon: Icons.agriculture_outlined,
    description: 'Manage crops, livestock, and farm operations',
  ),
  StakeholderRole(
    id: 'trader',
    label: 'Trader',
    icon: Icons.swap_horiz_outlined,
    description: 'Trade farm inputs and produce across markets',
  ),
  StakeholderRole(
    id: 'buyer',
    label: 'Buyer',
    icon: Icons.shopping_cart_outlined,
    description: 'Purchase farm products, produce, and commodities',
  ),
  StakeholderRole(
    id: 'input_supplier',
    label: 'Input Supplier',
    icon: Icons.inventory_2_outlined,
    description: 'Supply seeds, fertilizers, equipment, and farm inputs',
  ),
  StakeholderRole(
    id: 'agronomist',
    label: 'Agronomist',
    icon: Icons.biotech_outlined,
    description: 'Provide crop science, soil analysis, and advisory',
  ),
  StakeholderRole(
    id: 'extension_officer',
    label: 'Extension Officer',
    icon: Icons.school_outlined,
    description: 'Deliver agricultural training and field advisory',
  ),
  StakeholderRole(
    id: 'transporter',
    label: 'Transporter',
    icon: Icons.local_shipping_outlined,
    description: 'Transport agricultural goods and inputs',
  ),
  StakeholderRole(
    id: 'processor',
    label: 'Processor',
    icon: Icons.factory_outlined,
    description: 'Process raw agricultural products into finished goods',
  ),
  StakeholderRole(
    id: 'exporter',
    label: 'Exporter',
    icon: Icons.flight_takeoff_outlined,
    description: 'Export agricultural products to international markets',
  ),
  StakeholderRole(
    id: 'cooperative',
    label: 'Cooperative / SACCO',
    icon: Icons.groups_outlined,
    description: 'Manage group farming, collective sales, and savings',
  ),
  StakeholderRole(
    id: 'warehouse',
    label: 'Warehouse Operator',
    icon: Icons.warehouse_outlined,
    description: 'Provide storage and warehousing for farm produce',
  ),
  StakeholderRole(
    id: 'investor',
    label: 'Investor',
    icon: Icons.trending_up_outlined,
    description: 'Invest in agricultural enterprises and agri-tech',
  ),
  StakeholderRole(
    id: 'farm_worker',
    label: 'Farm Worker',
    icon: Icons.construction_outlined,
    description: 'Work on farms and agricultural operations',
  ),
];

class RoleSelectionScreenPage extends StatefulWidget {
  final List<String> initialSelectedRoles;
  final VoidCallback onContinue;
  final void Function(List<String> selectedRoles) onRolesChanged;

  const RoleSelectionScreenPage({
    super.key,
    this.initialSelectedRoles = const [],
    required this.onContinue,
    required this.onRolesChanged,
  });

  @override
  State<RoleSelectionScreenPage> createState() =>
      _RoleSelectionScreenPageState();
}

class _RoleSelectionScreenPageState extends State<RoleSelectionScreenPage> {
  late Set<String> _selectedRoles;

  @override
  void initState() {
    super.initState();
    _selectedRoles = Set.from(widget.initialSelectedRoles);
  }

  void _toggleRole(String roleId) {
    setState(() {
      if (_selectedRoles.contains(roleId)) {
        _selectedRoles.remove(roleId);
      } else {
        _selectedRoles.add(roleId);
      }
    });
    widget.onRolesChanged(_selectedRoles.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Your Role',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How do you participate in agriculture?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select all that apply. You can change these anytime.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Role Options ──
                    ...availableRoles.map(
                      (role) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RoleOptionTile(
                          role: role,
                          isSelected: _selectedRoles.contains(role.id),
                          onTap: () => _toggleRole(role.id),
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Continue Button ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedRoles.isEmpty ? null : widget.onContinue,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selectedRoles.isEmpty
                        ? 'Select at least one'
                        : 'Continue with ${_selectedRoles.length} role${_selectedRoles.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOptionTile extends StatelessWidget {
  final StakeholderRole role;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _RoleOptionTile({
    required this.role,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                role.icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
