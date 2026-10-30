import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Photos are stored in the Supabase Storage bucket (cloud, shared by every
/// user), never on the phone. This is the one place that knows how.
class MediaService {
  MediaService._();

  static const bucket = 'vendrgo-media';

  /// Phone photos are resized and re-encoded when picked, which typically
  /// turns a 3-6 MB photo into 100-300 KB before it is uploaded.
  static const maxDimension = 1280.0;
  static const jpegQuality = 70;

  static const maxUploadBytes = 5 * 1024 * 1024;

  static Future<XFile?> pickCompressed(
    ImagePicker picker, {
    ImageSource source = ImageSource.gallery,
  }) {
    return picker.pickImage(
      source: source,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: jpegQuality,
    );
  }

  /// Public link for a stored photo. Accepts a storage path (normal case) or
  /// a full web link (used by demo data). Returns null when there is no photo.
  static String? urlFor(dynamic path) {
    final value = path?.toString().trim();

    if (value == null || value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    return Supabase.instance.client.storage.from(bucket).getPublicUrl(value);
  }

  /// Uploads [image] under the signed-in user's folder and returns its storage
  /// path. Throws an [Exception] with a message that is safe to show.
  static Future<String> upload(XFile image, String kind) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('Your session has expired. Please login again.');
    }

    final file = File(image.path);

    if (await file.length() > maxUploadBytes) {
      throw Exception('The $kind photo is too large. Choose a smaller one.');
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
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$kind.$extension';

    try {
      await client.storage
          .from(bucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
    } on StorageException catch (error) {
      final code = error.statusCode?.toString();

      if (code == '401' || code == '403') {
        throw Exception(
          'Photo upload is not allowed for this account. '
          'Please contact the administrator.',
        );
      }

      throw Exception(
        'Could not upload the $kind photo. Please try again in a moment.',
      );
    } on SocketException {
      throw Exception(
        'No internet connection. Check your network and try again.',
      );
    }

    return path;
  }
}
