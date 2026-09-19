import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textCtrl = TextEditingController();
  final _fs = FirestoreService();
  final _storage = StorageService();

  File? _pickedFile;
  String? _pickedType;
  bool _posting = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedFile = File(picked.path);
        _pickedType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedFile = File(picked.path);
        _pickedType = 'video';
      });
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _pickedFile == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add some text or media first')));
      return;
    }

    setState(() => _posting = true);

    String? mediaUrl;
    if (_pickedFile != null) {
      mediaUrl = await _storage.uploadPostMedia(
        file: _pickedFile!,
        uid: AppState.instance.uid,
      );
    }

    final name = AppState.instance.nickname.isNotEmpty
        ? AppState.instance.nickname
        : AppState.instance.username;

    await _fs.createPost(
      uid: AppState.instance.uid,
      authorName: name,
      text: text,
      mediaUrl: mediaUrl,
      mediaType: _pickedFile != null ? _pickedType : null,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _submit,
            child: _posting
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: "What's on your mind?"),
            ),
            const SizedBox(height: 12),
            if (_pickedFile != null)
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _pickedType == 'video'
                    ? const Center(
                        child: Icon(Icons.videocam, size: 40, color: AppColors.muted))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_pickedFile!, fit: BoxFit.cover),
                      ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Photo'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
