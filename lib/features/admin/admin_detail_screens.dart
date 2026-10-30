import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/media_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/text_input_dialog.dart';
import '../../shared/widgets/network_image_with_fallback.dart';

class AdminVendorReviewScreen extends StatefulWidget {
  final Map<String, dynamic> stall;
  final Map<String, dynamic> vendor;

  const AdminVendorReviewScreen({
    super.key,
    required this.stall,
    required this.vendor,
  });

  @override
  State<AdminVendorReviewScreen> createState() =>
      _AdminVendorReviewScreenState();
}

class _AdminVendorReviewScreenState extends State<AdminVendorReviewScreen> {
  final client = Supabase.instance.client;

  bool working = false;

  Future<void> _approve() async {
    await _setStatus('approved');
  }

  Future<void> _reject() async {
    final reason = await showTextInputDialog(
      context,
      title: 'Reject vendor',
      label: 'Reason for rejection',
      hint: 'Tell the vendor what to fix',
      actionLabel: 'Reject',
      maxLines: 3,
    );

    if (reason == null) return;

    await _setStatus(
      'rejected',
      reason: reason.isEmpty
          ? 'Please contact support for more information.'
          : reason,
    );
  }

  Future<void> _suspend() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Suspend vendor?',
      message:
          'The vendor account will be disabled and the stall will be '
          'hidden from customers.',
      confirmLabel: 'Suspend',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      working = true;
    });

    try {
      await client
          .from('profiles')
          .update({'is_active': false})
          .eq('id', widget.vendor['id']);

      await client
          .from('stalls')
          .update({'approval_status': 'suspended', 'is_open': false})
          .eq('id', widget.stall['id']);

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor suspended.'),
          backgroundColor: VendrgoColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        working = false;
      });
    }
  }

  Future<void> _setStatus(String status, {String? reason}) async {
    setState(() {
      working = true;
    });

    try {
      await client
          .from('stalls')
          .update({
            'approval_status': status,
            'rejection_reason': reason,
            if (status != 'approved') 'is_open': false,
          })
          .eq('id', widget.stall['id']);

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Vendor approved.' : 'Vendor rejected.',
          ),
          backgroundColor: VendrgoColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        working = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: VendrgoColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Vendor review'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          const Text('Vendor information', style: VendrgoText.display),

          const SizedBox(height: 16),

          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  label: 'Owner',
                  value: widget.vendor['full_name'] as String? ?? '',
                ),
                _InfoLine(
                  label: 'Email',
                  value: widget.vendor['email'] as String? ?? '',
                ),
                _InfoLine(
                  label: 'Phone',
                  value: widget.vendor['phone'] as String? ?? '',
                ),
                _InfoLine(
                  label: 'Stall',
                  value: widget.stall['name'] as String? ?? '',
                ),
                _InfoLine(
                  label: 'Address',
                  value: widget.stall['address'] as String? ?? '',
                ),
                _InfoLine(
                  label: 'Description',
                  value: widget.stall['description'] as String? ?? '',
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (widget.stall['stall_image_path'] != null)
            _AdminImage(
              title: 'Stall image',
              path: widget.stall['stall_image_path'] as String,
            ),

          if (widget.stall['menu_image_path'] != null) ...[
            const SizedBox(height: 14),
            _AdminImage(
              title: 'Menu image',
              path: widget.stall['menu_image_path'] as String,
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: working ? null : _approve,
              child: const Text('Approve vendor'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: working ? null : _reject,
              child: const Text('Reject vendor'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: working ? null : _suspend,
              style: TextButton.styleFrom(foregroundColor: VendrgoColors.error),
              child: const Text('Suspend vendor'),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminStallEditScreen extends StatefulWidget {
  final Map<String, dynamic> stall;

  const AdminStallEditScreen({super.key, required this.stall});

  @override
  State<AdminStallEditScreen> createState() => _AdminStallEditScreenState();
}

class _AdminStallEditScreenState extends State<AdminStallEditScreen> {
  final client = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController addressController;
  late final TextEditingController categoryController;
  late final TextEditingController hoursController;

  String approvalStatus = 'pending';
  bool isOpen = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.stall['name'] as String? ?? '',
    );

    descriptionController = TextEditingController(
      text: widget.stall['description'] as String? ?? '',
    );

    addressController = TextEditingController(
      text: widget.stall['address'] as String? ?? '',
    );

    categoryController = TextEditingController();

    hoursController = TextEditingController(
      text:
          ((widget.stall['opening_hours'] as Map<String, dynamic>?)?['all']
              as String?) ??
          '',
    );

    approvalStatus = widget.stall['approval_status'] as String? ?? 'pending';

    isOpen = widget.stall['is_open'] == true;

    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final categoryId = widget.stall['category_id'];

    if (categoryId == null) return;

    final category = await client
        .from('categories')
        .select('name')
        .eq('id', categoryId)
        .maybeSingle();

    if (!mounted) return;

    categoryController.text = category?['name'] as String? ?? '';

    setState(() {});
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    categoryController.dispose();
    hoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      String? categoryId;

      final categoryName = categoryController.text.trim();

      if (categoryName.isNotEmpty) {
        final existing = await client
            .from('categories')
            .select('id')
            .ilike('name', categoryName)
            .maybeSingle();

        if (existing != null) {
          categoryId = existing['id'] as String;
        } else {
          final created = await client
              .from('categories')
              .insert({'name': categoryName, 'is_active': true})
              .select('id')
              .single();

          categoryId = created['id'] as String;
        }
      }

      final shouldBeOpen = approvalStatus == 'approved' && isOpen;

      await client
          .from('stalls')
          .update({
            'name': nameController.text.trim(),
            'description': descriptionController.text.trim(),
            'address': addressController.text.trim(),
            if (categoryId != null) 'category_id': categoryId,
            'opening_hours': {'all': hoursController.text.trim()},
            'approval_status': approvalStatus,
            'is_open': shouldBeOpen,
          })
          .eq('id', widget.stall['id']);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save stall.'),
          backgroundColor: VendrgoColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Edit stall'),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AdminField(controller: nameController, label: 'Stall name'),
              const SizedBox(height: 14),
              _AdminField(
                controller: descriptionController,
                label: 'Description',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _AdminField(controller: categoryController, label: 'Category'),
              const SizedBox(height: 14),
              _AdminField(
                controller: addressController,
                label: 'Address',
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              _AdminField(controller: hoursController, label: 'Opening hours'),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: approvalStatus,
                decoration: const InputDecoration(labelText: 'Approval status'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(
                    value: 'suspended',
                    child: Text('Suspended'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    approvalStatus = value;

                    if (value != 'approved') {
                      isOpen = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Stall is open'),
                value: isOpen,
                onChanged: approvalStatus == 'approved'
                    ? (value) {
                        setState(() {
                          isOpen = value;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: VendrgoText.caption),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '-' : value,
            style: VendrgoText.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AdminImage extends StatelessWidget {
  final String title;
  final String path;

  const _AdminImage({required this.title, required this.path});

  @override
  Widget build(BuildContext context) {
    final url = MediaService.urlFor(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: VendrgoText.heading),
        const SizedBox(height: 8),
        NetworkImageWithFallback(
          url: url,
          height: 180,
          width: double.infinity,
          borderRadius: VendrgoRadius.lgAll,
        ),
      ],
    );
  }
}

class _AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _AdminField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required.';
        }

        return null;
      },
      decoration: InputDecoration(labelText: label),
    );
  }
}
