import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import 'vendor_home_screen.dart';

class VendorSetupScreen extends StatefulWidget {
  const VendorSetupScreen({super.key});

  @override
  State<VendorSetupScreen> createState() => _VendorSetupScreenState();
}

class _VendorSetupScreenState extends State<VendorSetupScreen> {
  final client = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();
  final imagePicker = ImagePicker();

  final stallNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final addressController = TextEditingController();
  final openingHoursController = TextEditingController();

  XFile? stallImage;
  XFile? menuImage;

  double? latitude;
  double? longitude;

  bool loading = true;
  bool loadingLocation = false;
  bool saving = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSignupData();
  }

  @override
  void dispose() {
    stallNameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    addressController.dispose();
    openingHoursController.dispose();
    super.dispose();
  }

  void _loadSignupData() {
    final metadata =
        client.auth.currentUser?.userMetadata ?? {};

    stallNameController.text =
        metadata['stall_name'] as String? ?? '';

    descriptionController.text =
        metadata['stall_description'] as String? ?? '';

    categoryController.text =
        metadata['category_name'] as String? ?? '';

    addressController.text =
        metadata['stall_address'] as String? ?? '';

    openingHoursController.text =
        metadata['opening_hours'] as String? ?? '';

    setState(() {
      loading = false;
    });
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
    openingHoursController.text =
        '${openingTime.format(context)} – ${closingTime.format(context)}';
  });
}

  Future<void> _pickImage({
    required bool stall,
  }) async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null || !mounted) {
      return;
    }

    final fileSize = await File(picked.path).length();

    if (fileSize > 5 * 1024 * 1024) {
      _showMessage(
        'Image must be smaller than 5 MB.',
        error: true,
      );
      return;
    }

    setState(() {
      if (stall) {
        stallImage = picked;
      } else {
        menuImage = picked;
      }
    });
  }

  Future<void> _loadLocation() async {
    setState(() {
      loadingLocation = true;
      errorMessage = null;
    });

    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Please enable location services on your device.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
              'Enable it from device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingLocation = false;
        });
      }
    }
  }

  Future<String> _uploadImage(
      XFile file,
      String type,
      ) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You are not signed in.');
    }

    final extension =
    file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';

    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final path =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$type.$extension';

    await client.storage.from('vendrgo-media').upload(
      path,
      File(file.path),
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    return path;
  }

  Future<String> _getOrCreateCategory() async {
    final categoryName =
    categoryController.text.trim();

    if (categoryName.isEmpty) {
      throw Exception(
        'Food category is required.',
      );
    }

    final existing = await client
        .from('categories')
        .select('id')
        .ilike('name', categoryName)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You are not signed in.',
      );
    }

    final created = await client
        .from('categories')
        .insert({
      'name': categoryName,
      'created_by': user.id,
      'is_active': true,
    })
        .select('id')
        .single();

    return created['id'] as String;
  }

  Future<void> _saveStall() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (latitude == null || longitude == null) {
      setState(() {
        errorMessage =
        'Update your current location before submitting your stall.';
      });
      return;
    }

    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        errorMessage = 'Your session has expired. Please login again.';
      });
      return;
    }

    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      final categoryId =
      await _getOrCreateCategory();

      String? stallImagePath;
      String? menuImagePath;

      if (stallImage != null) {
        stallImagePath = await _uploadImage(
          stallImage!,
          'stall',
        );
      }

      if (menuImage != null) {
        menuImagePath = await _uploadImage(
          menuImage!,
          'menu',
        );
      }

      await client.from('stalls').insert({
        'vendor_id': user.id,
        'category_id': categoryId,
        'name': stallNameController.text.trim(),
        'description': descriptionController.text.trim(),
        'address': addressController.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'opening_hours': {
          'all': openingHoursController.text.trim(),
        },
        'stall_image_path': stallImagePath,
        'menu_image_path': menuImagePath,
        'is_open': false,
        'approval_status': 'pending',
        'location_updated_at':
        DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      /*
       * Important:
       * VendorSetupScreen can currently be rendered directly
       * by AuthRouter. Creating the stall does not automatically
       * force AuthRouter to re-query it.
       *
       * Therefore we explicitly move into the vendor dashboard.
       * The next app launch/session resolution will still find
       * the stall normally.
       */
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const VendorHomeScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
        saving = false;
      });
    }
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          error
              ? VendrgoColors.error
              : VendrgoColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () async {
            await client.auth.signOut();
          },
        ),
        title: const Text('Finish stall setup'),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              36,
            ),
            children: [
              const Text(
                'Set up your stall.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Add the information customers will see. '
                    'Your stall will remain closed until an admin approves it.',
                style: TextStyle(
                  color: VendrgoColors.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 22),

              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: VendrgoColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _Field(
                controller: stallNameController,
                label: 'Stall name',
                icon: Icons.storefront_outlined,
                validator: _required('Stall name'),
              ),

              const SizedBox(height: 14),

              _Field(
                controller: descriptionController,
                label: 'Description',
                icon: Icons.description_outlined,
                maxLines: 3,
                validator: _required('Description'),
              ),

              const SizedBox(height: 14),

              _Field(
                controller: categoryController,
                label: 'Main food category',
                icon: Icons.restaurant_menu_outlined,
                validator: _required('Food category'),
              ),

              const SizedBox(height: 7),

              const Text(
                'Use an existing category or enter a new food type.',
                style: TextStyle(
                  fontSize: 12,
                  color: VendrgoColors.textSecondary,
                ),
              ),

              const SizedBox(height: 14),

              _Field(
                controller: addressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: _required('Address'),
              ),

              const SizedBox(height: 14),

              _Field(
    controller: openingHoursController,
    label: 'Opening hours',
    icon: Icons.schedule_outlined,
    validator: _required('Opening hours'),
    readOnly: true,
    onTap: _selectOpeningHours,
  ),  

              const SizedBox(height: 22),

              _ImageCard(
                title: 'Stall image',
                file: stallImage,
                icon: Icons.storefront_rounded,
                onPick: () => _pickImage(stall: true),
              ),

              const SizedBox(height: 12),

              _ImageCard(
                title: 'Menu image',
                file: menuImage,
                icon: Icons.restaurant_menu_rounded,
                onPick: () => _pickImage(stall: false),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: VendrgoColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current stall location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      latitude == null
                          ? 'No location selected yet.'
                          : 'Latitude: ${latitude!.toStringAsFixed(6)}\n'
                          'Longitude: ${longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: VendrgoColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                        loadingLocation
                            ? null
                            : _loadLocation,
                        icon: const Icon(
                          Icons.my_location_rounded,
                        ),
                        label: Text(
                          loadingLocation
                              ? 'Getting location...'
                              : latitude == null
                              ? 'Use current location'
                              : 'Update current location',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  saving ? null : _saveStall,
                  child: saving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Submit for approval',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: onTap == null
            ? null
            : const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String title;
  final XFile? file;
  final IconData icon;
  final VoidCallback onPick;

  const _ImageCard({
    required this.title,
    required this.file,
    required this.icon,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VendrgoColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file != null)
            Image.file(
              File(file!.path),
              fit: BoxFit.cover,
            )
          else
            Center(
              child: Icon(
                icon,
                size: 50,
                color: VendrgoColors.textSecondary,
              ),
            ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(
                Icons.photo_library_outlined,
              ),
              label: Text(
                file == null
                    ? 'Choose $title'
                    : 'Change $title',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? Function(String?) _required(
    String field,
    ) {
  return (value) {
    if (value == null ||
        value.trim().isEmpty) {
      return '$field is required.';
    }

    return null;
  };
}