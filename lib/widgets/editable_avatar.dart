import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/avatar_service.dart';

class EditableAvatar extends StatefulWidget {
  const EditableAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 50,
    this.editable = true,
  });

  final String photoUrl;
  final double radius;
  final bool editable;

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  final AvatarService _avatarService = AvatarService();
  bool _isUploading = false;

  Future<void> _changePhoto() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _showMessage('Please login first');
      return;
    }

    try {
      final file = await _avatarService.pickFromGallery();
      if (file == null) return;

      if (!mounted) return;
      setState(() => _isUploading = true);

      final url = await _avatarService.upload(userId: userId, file: file);
      await auth.updateProfilePhoto(url);

      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage('Profile photo updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage('Could not update photo: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildPhoto(),
        if (widget.editable)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                onPressed: _isUploading ? null : _changePhoto,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoto() {
    final photo = widget.photoUrl;
    final isNetworkPhoto =
        photo.startsWith('http://') || photo.startsWith('https://');
    if (!isNetworkPhoto) return _buildPlaceholder();

    return ClipOval(
      child: Image.network(
        photo,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('Avatar load failed for $photo: $error');
          return _buildPlaceholder();
        },
      ),
    );
  }

  Widget _buildPlaceholder() => CircleAvatar(
        radius: widget.radius,
        child: Icon(Icons.person, size: widget.radius * 1.2),
      );
}
