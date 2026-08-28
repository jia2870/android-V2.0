import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AvatarService {
  static const String bucketName = 'avatars';

  static const double _maxDimension = 512;
  static const int _quality = 80;

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final SupabaseClient _client = SupabaseService().client;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickFromGallery() => _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
      );

  Future<String> upload({required String userId, required XFile file}) async {
    final bytes = await file.readAsBytes();
    final extension = _extensionOf(file.name);
    final path = '$userId/avatar.$extension';

    await _client.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeOf(extension),
            upsert: true,
          ),
        );

    final url = _client.storage.from(bucketName).getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return 'jpg';

    final extension = fileName.substring(dot + 1).toLowerCase();
    return _allowedExtensions.contains(extension) ? extension : 'jpg';
  }

  String _contentTypeOf(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
