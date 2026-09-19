import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a photo or video picked from the device to Firebase
/// Storage and returns its public download URL.
class StorageService {
  final _storage = FirebaseStorage.instance;

  /// Uploads [file] under posts/{uid}/{timestamp}.{ext} and returns
  /// the download URL once the upload finishes.
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
}
