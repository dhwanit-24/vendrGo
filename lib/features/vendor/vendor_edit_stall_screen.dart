import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/media_service.dart';
import '../../shared/widgets/form_widgets.dart';

class VendorEditStallScreen extends StatefulWidget {
  const VendorEditStallScreen({super.key});

  @override
  State<VendorEditStallScreen> createState() => _VendorEditStallScreenState();
}

class _VendorEditStallScreenState extends State<VendorEditStallScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _stall;

  XFile? _newStallImage;
  XFile? _newMenuImage;

  @override
  void initState() {
    super.initState();
    _loadStall();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadStall() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      _showMessage('No logged-in vendor found.', isError: true);
      return;
    }

    try {
      final stall = await _client
          .from('stalls')
          .select()
          .eq('vendor_id', user.id)
          .maybeSingle();

      if (stall == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
        });

        _showMessage('No stall was found.', isError: true);
        return;
      }

      String categoryName = '';

      final categoryId = stall['category_id']?.toString();

      if (categoryId != null && categoryId.isNotEmpty) {
        final category = await _client
            .from('categories')
            .select('name')
            .eq('id', categoryId)
            .maybeSingle();

        categoryName = category?['name']?.toString() ?? '';
      }

      final openingHours = stall['opening_hours'];

      String hours = '';

      if (openingHours is Map) {
        hours = openingHours['all']?.toString() ?? '';
      }

      if (!mounted) {
        return;
      }

      _nameController.text = stall['name']?.toString() ?? '';
      _descriptionController.text = stall['description']?.toString() ?? '';
      _categoryController.text = categoryName;
      _addressController.text = stall['address']?.toString() ?? '';
      _hoursController.text = hours;

      setState(() {
        _stall = Map<String, dynamic>.from(stall);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage('Could not load stall information.', isError: true);
    }
  }

  Future<void> _pickStallImage() async {
    final image = await MediaService.pickCompressed(_imagePicker);

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _newStallImage = image;
    });
  }

  Future<void> _pickMenuImage() async {
    final image = await MediaService.pickCompressed(_imagePicker);

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _newMenuImage = image;
    });
  }

  Future<String?> _uploadImage(XFile image, String prefix) {
    return MediaService.upload(image, prefix);
  }

  Future<String> _getOrCreateCategory(String categoryName) async {
    final cleanedName = categoryName.trim();

    if (cleanedName.length < 2) {
      throw Exception('Food category must contain at least 2 characters.');
    }

    final existing = await _client
        .from('categories')
        .select('id')
        .ilike('name', cleanedName)
        .maybeSingle();

    if (existing != null) {
      return existing['id'].toString();
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User session not found.');
    }

    final created = await _client
        .from('categories')
        .insert({'name': cleanedName, 'created_by': user.id})
        .select('id')
        .single();

    return created['id'].toString();
  }

  Future<void> _selectOpeningHours() async {
    final openingTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select opening time',
    );

    if (openingTime == null || !mounted) {
      return;
    }

    final closingTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (openingTime.hour + 8) % 24,
        minute: openingTime.minute,
      ),
      helpText: 'Select closing time',
    );

    if (closingTime == null || !mounted) {
      return;
    }

    setState(() {
      _hoursController.text =
          '${openingTime.format(context)} – ${closingTime.format(context)}';
    });
  }

  Future<void> _saveChanges() async {
    if (_saving) {
      return;
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      _showMessage('No logged-in vendor found.', isError: true);
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    final address = _addressController.text.trim();
    final hours = _hoursController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your stall name.', isError: true);
      return;
    }

    if (description.isEmpty) {
      _showMessage('Please enter a stall description.', isError: true);
      return;
    }

    if (category.isEmpty) {
      _showMessage('Please enter a food category.', isError: true);
      return;
    }

    if (address.isEmpty) {
      _showMessage('Please enter the stall address.', isError: true);
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final categoryId = await _getOrCreateCategory(category);

      String? stallImagePath;
      String? menuImagePath;

      if (_newStallImage != null) {
        stallImagePath = await _uploadImage(_newStallImage!, 'stall');
      }

      if (_newMenuImage != null) {
        menuImagePath = await _uploadImage(_newMenuImage!, 'menu');
      }

      final updateData = <String, dynamic>{
        'name': name,
        'description': description,
        'category_id': categoryId,
        'address': address,
        'opening_hours': {'all': hours},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (stallImagePath != null) {
        updateData['stall_image_path'] = stallImagePath;
      }

      if (menuImagePath != null) {
        updateData['menu_image_path'] = menuImagePath;
      }

      await _client.from('stalls').update(updateData).eq('vendor_id', user.id);

      if (!mounted) {
        return;
      }

      _showMessage('Stall updated successfully.');

      Navigator.pop(context);
    } catch (e) {
      _showMessage('Could not save stall changes.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? VendrgoColors.error
              : VendrgoColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendrgoColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Stall',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stall == null
          ? const Center(child: Text('No stall information available.'))
          : Form(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Stall Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  AppFormField(
                    controller: _nameController,
                    label: 'Stall Name',
                    hint: 'Enter stall name',
                    icon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppFormField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Describe your stall',
                    icon: Icons.description_outlined,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  AppFormField(
                    controller: _categoryController,
                    label: 'Food Category',
                    hint: 'Example: Street Food',
                    icon: Icons.restaurant_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppFormField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Enter stall address',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  AppFormField(
                    controller: _hoursController,
                    label: 'Opening Hours',
                    hint: 'Select opening and closing time',
                    icon: Icons.access_time_outlined,
                    readOnly: true,
                    onTap: _selectOpeningHours,
                  ),
                  const SizedBox(height: 24),
                  ImagePickerCard(
                    title: 'Stall Image',
                    file: _newStallImage,
                    existingUrl: _mediaUrl(_stall?['stall_image_path']),
                    icon: Icons.storefront_rounded,
                    onPick: _pickStallImage,
                  ),
                  const SizedBox(height: 14),
                  ImagePickerCard(
                    title: 'Menu Image',
                    file: _newMenuImage,
                    existingUrl: _mediaUrl(_stall?['menu_image_path']),
                    icon: Icons.restaurant_menu_rounded,
                    onPick: _pickMenuImage,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveChanges,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'SAVE CHANGES',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String? _mediaUrl(dynamic path) => MediaService.urlFor(path);
}
