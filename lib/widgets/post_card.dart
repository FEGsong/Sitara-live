import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final myUid = AppState.instance.uid;
    final postId = post['id'] as String;
    final authorName = post['authorName'] ?? 'User';
    final text = post['text'] ?? '';
    final mediaUrl = post['mediaUrl'] as String?;
    final mediaType = post['mediaType'] as String?;
    final likesCount = post['likesCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.hot,
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Text(authorName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(text, style: const TextStyle(fontSize: 13.5)),
            ),
          if (mediaUrl != null) ...[
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1,
              child: mediaType == 'video'
                  ? Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 50),
                      ),
                    )
                  : Image.network(mediaUrl, fit: BoxFit.cover),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<bool>(
              stream: fs.isPostLiked(postId, myUid),
              builder: (context, snap) {
                final liked = snap.data ?? false;
                return GestureDetector(
                  onTap: () => liked
                      ? fs.unlikePost(postId, myUid)
                      : fs.likePost(postId, myUid),
                  child: Row(
                    children: [
                      Icon(liked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: liked ? AppColors.hot : AppColors.muted),
                      const SizedBox(width: 6),
                      Text('$likesCount',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
