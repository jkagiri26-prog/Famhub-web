/// ============================================================
/// AGRI CONNECT — CREATE COMMUNITY PAGE
/// ============================================================
///
/// Creates a community via `create_community` RPC (through the existing
/// controller). Never inserts into `communities` directly.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community.dart';
import '../../domain/enums/community_enums.dart';
import '../../application/providers/community_provider.dart';
import '../format.dart';
import 'community_details_page.dart';

class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key});

  @override
  ConsumerState<CreateCommunityPage> createState() =>
      _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  CommunityType _type = CommunityType.interest;
  CommunityVisibility _visibility = CommunityVisibility.public;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncSlugFromName(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _slugController.text = slug;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final community = await ref
          .read(communityControllerProvider.notifier)
          .createCommunity(
            name: _nameController.text.trim(),
            slug: _slugController.text.trim(),
            type: _type,
            visibility: _visibility,
            description: _descriptionController.text.trim(),
          );
      if (!mounted) return;
      _navigateTo(community);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create community: $e')));
    }
  }

  void _navigateTo(Community community) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CommunityDetailsPage(communityId: community.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Create Community'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Name', Icons.badge_outlined),
                onChanged: _syncSlugFromName,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slugController,
                decoration: _decoration('Slug', Icons.link),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Slug is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _decoration(
                  'Description (optional)',
                  Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CommunityType>(
                initialValue: _type,
                decoration: _decoration(
                  'Community type',
                  Icons.category_outlined,
                ),
                items: [
                  for (final t in CommunityType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CommunityVisibility>(
                initialValue: _visibility,
                decoration: _decoration(
                  'Visibility',
                  Icons.visibility_outlined,
                ),
                items: [
                  for (final v in CommunityVisibility.values)
                    DropdownMenuItem(value: v, child: Text(v.label)),
                ],
                onChanged: (v) =>
                    setState(() => _visibility = v ?? _visibility),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Community',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
