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

  /// Overwrites the previous avatar at the same path (avatars/{uid}.jpg).
  Future<String> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    final ref = _storage.ref().child('avatars/$uid.jpg');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// Room covers get a timestamped name so the new image is never
  /// hidden behind a cached copy of the old one.
  Future<String> uploadRoomCover({
    required File file,
    required String roomId,
  }) async {
    final name = '${roomId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('room_covers/$name');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }
}
