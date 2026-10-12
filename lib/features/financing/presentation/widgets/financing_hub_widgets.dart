/// ============================================================
/// FINANCING — SHARED LANDING CHROME
/// ============================================================
///
/// The elevated hub header and the segmented pill tab bar used by every
/// top-level Financing screen. Extracted so the landing, catalogue and
/// management screens share one visual language instead of each shipping a
/// near-identical copy.
///
/// Pure presentation: no providers, no networking, no permissions.
/// ============================================================
library;

import 'package:flutter/material.dart';

/// Deep green used across the Financing module accent system.
const Color kFinancingAccent = Color(0xFF2E7D32);
const Color kFinancingAccentDeep = Color(0xFF1B5E20);

/// Elevated hero header: soft green wash, gradient icon chip, optional
/// eyebrow badge and two lines of supporting copy.
class FinancingHubHeader extends StatelessWidget {
  const FinancingHubHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    this.icon = Icons.account_balance_outlined,
    this.eyebrow = 'FINANCE',
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF2F8F3), Color(0xFFE4F1E7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E7DB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6E33).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kFinancingAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: kFinancingAccent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        eyebrow,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: kFinancingAccentDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kFinancingAccent.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry of [FinancingSegmentedTabs].
class FinancingTabSpec {
  const FinancingTabSpec({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Segmented pill tab bar — reads as a switcher rather than a browser tab.
class FinancingSegmentedTabs extends StatelessWidget {
  const FinancingSegmentedTabs({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<FinancingTabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE3E6EA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: kFinancingAccentDeep,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          for (final tab in tabs)
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 16),
                  const SizedBox(width: 7),
                  Text(tab.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Filled primary action used by the Financing management screens.
class FinancingPrimaryButton extends StatelessWidget {
  const FinancingPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.add, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: kFinancingAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    return button;
  }
}
