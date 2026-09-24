import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'qr_code_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  late TextEditingController _nicknameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;

  File? _pickedAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: AppState.instance.nickname);
    _usernameCtrl = TextEditingController(text: AppState.instance.username);
    _bioCtrl = TextEditingController(text: AppState.instance.bio);
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedAvatar = File(picked.path));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? avatarUrl;
    if (_pickedAvatar != null) {
      avatarUrl = await _storage.uploadAvatar(file: _pickedAvatar!, uid: AppState.instance.uid);
    }
    await _fs.updateProfile(
      AppState.instance.uid,
      nickname: _nicknameCtrl.text.trim().isEmpty ? null : _nicknameCtrl.text.trim(),
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      avatarUrl: avatarUrl,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'My QR Code',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrCodeScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.surface2,
                    backgroundImage: _pickedAvatar != null
                        ? FileImage(_pickedAvatar!)
                        : (AppState.instance.avatarUrl.isNotEmpty
                            ? NetworkImage(AppState.instance.avatarUrl)
                            : null) as ImageProvider?,
                    child: (_pickedAvatar == null && AppState.instance.avatarUrl.isEmpty)
                        ? const Icon(Icons.person, size: 40, color: AppColors.muted)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Change profile picture',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          const SizedBox(height: 28),
          _field('Profile name', _nicknameCtrl, maxLen: 30),
          const SizedBox(height: 18),
          _field('Username', _usernameCtrl, maxLen: 24),
          const SizedBox(height: 18),
          _field('Bio', _bioCtrl, maxLen: 80, maxLines: 3),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLen = 100, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLength: maxLen,
          maxLines: maxLines,
        ),
      ],
    );
  }
}
