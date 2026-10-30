import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import 'network_image_with_fallback.dart';

/// Themed text field for forms. Styling comes from the theme.
class AppFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
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
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: onTap == null
            ? null
            : const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }
}

/// Image picker tile showing the newly picked file, else the existing image.
class ImagePickerCard extends StatelessWidget {
  final String title;
  final XFile? file;
  final String? existingUrl;
  final IconData icon;
  final VoidCallback onPick;

  const ImagePickerCard({
    super.key,
    required this.title,
    required this.file,
    required this.onPick,
    this.existingUrl,
    this.icon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        file != null || (existingUrl != null && existingUrl!.isNotEmpty);

    final Widget preview = file != null
        ? Image.file(File(file!.path), fit: BoxFit.cover)
        : NetworkImageWithFallback(url: existingUrl, fallbackIcon: icon);

    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: VendrgoRadius.lgAll,
        border: Border.all(color: VendrgoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(hasImage ? 'Change $title' : 'Choose $title'),
            ),
          ),
        ],
      ),
    );
  }
}
