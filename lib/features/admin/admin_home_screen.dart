import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_services.dart';
import '../../shared/widgets/app_ui.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<Map<String, int>> _loadStats() async {
    final client = Supabase.instance.client;

    final profiles = await client
        .from('profiles')
        .select('id, role, is_active');

    final stalls = await client
        .from('stalls')
        .select('id, approval_status, is_open');

    final profileRows = List<Map<String, dynamic>>.from(profiles);

    final stallRows = List<Map<String, dynamic>>.from(stalls);

    return {
      'customers': profileRows.where((row) => row['role'] == 'customer').length,
      'vendors': profileRows.where((row) => row['role'] == 'vendor').length,
      'open': stallRows
          .where(
            (row) =>
                row['approval_status'] == 'approved' && row['is_open'] == true,
          )
          .length,
      'pending': stallRows
          .where((row) => row['approval_status'] == 'pending')
          .length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, int>>(
          future: _loadStats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    const VendrgoLogo(size: 50),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Admin dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await AuthService.instance.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                const Text(
                  'Vendrgo overview',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 20),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _StatCard(
                      number: '${stats['customers']}',
                      label: 'Customers',
                      color: VendrgoColors.lavender,
                      icon: Icons.people_alt_outlined,
                    ),
                    _StatCard(
                      number: '${stats['vendors']}',
                      label: 'Vendors',
                      color: VendrgoColors.peach,
                      icon: Icons.storefront_outlined,
                    ),
                    _StatCard(
                      number: '${stats['open']}',
                      label: 'Open stalls',
                      color: VendrgoColors.mint,
                      icon: Icons.storefront_rounded,
                    ),
                    _StatCard(
                      number: '${stats['pending']}',
                      label: 'Pending approval',
                      color: const Color(0xFFFFF3D8),
                      icon: Icons.pending_actions_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _AdminMenuCard(
                  icon: Icons.pending_actions_rounded,
                  title: 'Vendor approvals',
                  description: 'Review and approve new vendor stalls.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminVendorsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _AdminMenuCard(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Manage stalls',
                  description: 'View, edit or remove stalls.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminStallsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _AdminMenuCard(
                  icon: Icons.flag_outlined,
                  title: 'Reports',
                  description: 'Moderation tools will arrive later.',
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Coming soon'),
                        content: const Text(
                          'Customer reporting and moderation are intentionally postponed for V1.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Okay'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  final client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _loadPending() async {
    final profiles = await client
        .from('profiles')
        .select()
        .eq('role', 'vendor');

    final stalls = await client
        .from('stalls')
        .select()
        .eq('approval_status', 'pending');

    final profileRows = List<Map<String, dynamic>>.from(profiles);

    final stallRows = List<Map<String, dynamic>>.from(stalls);

    final result = <Map<String, dynamic>>[];

    for (final stall in stallRows) {
      final vendor = profileRows.firstWhere(
        (profile) => profile['id'] == stall['vendor_id'],
        orElse: () => <String, dynamic>{},
      );

      result.add({'stall': stall, 'vendor': vendor});
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Vendor approvals'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadPending(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No vendors are waiting for approval.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final stall = items[index]['stall'] as Map<String, dynamic>;
              final vendor = items[index]['vendor'] as Map<String, dynamic>;

              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: VendrgoColors.border),
                ),
                title: Text(
                  stall['name'] as String? ?? 'Unnamed stall',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${vendor['full_name'] ?? 'Vendor'}\n'
                  '${vendor['email'] ?? ''}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminVendorReviewScreen(stall: stall, vendor: vendor),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

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
    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();

        return AlertDialog(
          title: const Text('Reject vendor'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Reason for rejection'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
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
          const Text(
            'Vendor information',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 20),

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

class AdminStallsScreen extends StatefulWidget {
  const AdminStallsScreen({super.key});

  @override
  State<AdminStallsScreen> createState() => _AdminStallsScreenState();
}

class _AdminStallsScreenState extends State<AdminStallsScreen> {
  final client = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> futureStalls;

  @override
  void initState() {
    super.initState();
    futureStalls = _loadStalls();
  }

  Future<List<Map<String, dynamic>>> _loadStalls() async {
    final data = await client
        .from('stalls')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _deleteStall(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete stall?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await client.from('stalls').delete().eq('id', id);

    if (!mounted) return;

    setState(() {
      futureStalls = _loadStalls();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Manage stalls'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureStalls,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stalls = snapshot.data!;

          if (stalls.isEmpty) {
            return const Center(child: Text('No stalls found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: stalls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final stall = stalls[index];

              final status = stall['approval_status'] as String? ?? 'pending';

              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: VendrgoColors.border),
                ),
                title: Text(
                  stall['name'] as String? ?? 'Unnamed stall',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${status.toUpperCase()} • '
                  '${stall['is_open'] == true ? 'OPEN' : 'CLOSED'}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminStallEditScreen(stall: stall),
                        ),
                      );

                      if (!mounted) return;

                      setState(() {
                        futureStalls = _loadStalls();
                      });
                    }

                    if (value == 'delete') {
                      await _deleteStall(stall['id'] as String);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
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

class _StatCard extends StatelessWidget {
  final String number;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.number,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const Spacer(),
          Text(
            number,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(color: VendrgoColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VendrgoColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: VendrgoColors.peach,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      color: VendrgoColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: VendrgoColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
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
    final url = Supabase.instance.client.storage
        .from('vendrgo-media')
        .getPublicUrl(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: Image.network(url, fit: BoxFit.cover),
          ),
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
