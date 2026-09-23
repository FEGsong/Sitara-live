import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadPostMedia({
    required File file,
    required String uid,
  }) async {
    final ext = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('posts/$uid/$fileName');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// Uploads a new profile picture, overwriting the previous one at
  /// the same fixed path (avatars/{uid}.jpg) so old images don't pile up.
  Future<String> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    final ref = _storage.ref().child('avatars/$uid.jpg');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }
}
