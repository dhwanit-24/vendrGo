import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class VendorEditStallScreen extends StatefulWidget {
  const VendorEditStallScreen({super.key});

  @override
  State<VendorEditStallScreen> createState() =>
      _VendorEditStallScreenState();
}

class _VendorEditStallScreenState extends State<VendorEditStallScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController =
  TextEditingController();
  final TextEditingController _categoryController =
  TextEditingController();
  final TextEditingController _addressController =
  TextEditingController();
  final TextEditingController _hoursController =
  TextEditingController();

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
      _showMessage(
        'No logged-in vendor found.',
        isError: true,
      );
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

        _showMessage(
          'No stall was found.',
          isError: true,
        );
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
      _descriptionController.text =
          stall['description']?.toString() ?? '';
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

      _showMessage(
        'Could not load stall information.',
        isError: true,
      );
    }
  }

  Future<void> _pickStallImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _newStallImage = image;
    });
  }

  Future<void> _pickMenuImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _newMenuImage = image;
    });
  }

  Future<String?> _uploadImage(
      XFile image,
      String prefix,
      ) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final file = File(image.path);

    final fileSize = await file.length();

    if (fileSize > 5 * 1024 * 1024) {
      throw Exception(
        '$prefix image must be smaller than 5 MB.',
      );
    }

    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';

    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final path =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$prefix.$extension';

    await _client.storage.from('vendrgo-media').upload(
      path,
      file,
      fileOptions: FileOptions(
        upsert: false,
        contentType: contentType,
      ),
    );

    return path;
  }

  Future<String> _getOrCreateCategory(
      String categoryName,
      ) async {
    final cleanedName = categoryName.trim();

    if (cleanedName.length < 2) {
      throw Exception(
        'Food category must contain at least 2 characters.',
      );
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
        .insert({
      'name': cleanedName,
      'created_by': user.id,
    })
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
      _showMessage(
        'No logged-in vendor found.',
        isError: true,
      );
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    final address = _addressController.text.trim();
    final hours = _hoursController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Please enter your stall name.',
        isError: true,
      );
      return;
    }

    if (description.isEmpty) {
      _showMessage(
        'Please enter a stall description.',
        isError: true,
      );
      return;
    }

    if (category.isEmpty) {
      _showMessage(
        'Please enter a food category.',
        isError: true,
      );
      return;
    }

    if (address.isEmpty) {
      _showMessage(
        'Please enter the stall address.',
        isError: true,
      );
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
        stallImagePath = await _uploadImage(
          _newStallImage!,
          'stall',
        );
      }

      if (_newMenuImage != null) {
        menuImagePath = await _uploadImage(
          _newMenuImage!,
          'menu',
        );
      }

      final updateData = <String, dynamic>{
        'name': name,
        'description': description,
        'category_id': categoryId,
        'address': address,
        'opening_hours': {
          'all': hours,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (stallImagePath != null) {
        updateData['stall_image_path'] = stallImagePath;
      }

      if (menuImagePath != null) {
        updateData['menu_image_path'] = menuImagePath;
      }

      await _client
          .from('stalls')
          .update(updateData)
          .eq('vendor_id', user.id);

      if (!mounted) {
        return;
      }

      _showMessage('Stall updated successfully.');

      Navigator.pop(context);
    } catch (e) {
      _showMessage(
        'Could not save stall changes.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? VendrgoColors.error : VendrgoColors.success,
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _stall == null
          ? const Center(
        child: Text(
          'No stall information available.',
        ),
      )
          : Form(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Stall Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            _buildField(
              controller: _nameController,
              label: 'Stall Name',
              hint: 'Enter stall name',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your stall',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _categoryController,
              label: 'Food Category',
              hint: 'Example: Street Food',
              icon: Icons.restaurant_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _addressController,
              label: 'Address',
              hint: 'Enter stall address',
              icon: Icons.location_on_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _buildField(
  controller: _hoursController,
  label: 'Opening Hours',
  hint: 'Select opening and closing time',
  icon: Icons.access_time_outlined,
  readOnly: true,
  onTap: _selectOpeningHours,
),
            const SizedBox(height: 24),
            _ImageCard(
              title: 'Stall Image',
              selectedImage: _newStallImage,
              existingPath: _stall?['stall_image_path']
                  ?.toString(),
              onTap: _pickStallImage,
            ),
            const SizedBox(height: 14),
            _ImageCard(
              title: 'Menu Image',
              selectedImage: _newMenuImage,
              existingPath: _stall?['menu_image_path']
                  ?.toString(),
              onTap: _pickMenuImage,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
  VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: onTap == null
    ? null
    : const Icon(Icons.keyboard_arrow_down_rounded),
        filled: true,
        fillColor: VendrgoColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: VendrgoColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: VendrgoColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: VendrgoColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String title;
  final XFile? selectedImage;
  final String? existingPath;
  final VoidCallback onTap;

  const _ImageCard({
    required this.title,
    required this.selectedImage,
    required this.existingPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String? publicUrl;

    if (existingPath != null && existingPath!.isNotEmpty) {
      publicUrl = Supabase.instance.client.storage
          .from('vendrgo-media')
          .getPublicUrl(existingPath!);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: VendrgoColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: selectedImage != null
                  ? Image.file(
                File(selectedImage!.path),
                fit: BoxFit.cover,
              )
                  : publicUrl != null
                  ? Image.network(
                publicUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _emptyImage();
                },
              )
                  : _emptyImage(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              selectedImage == null
                  ? 'Choose Image'
                  : 'Change Image',
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyImage() {
    return Container(
      color: VendrgoColors.background,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 50,
          color: VendrgoColors.textSecondary  ,
        ),
      ),
    );
  }
}