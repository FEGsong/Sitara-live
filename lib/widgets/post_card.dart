import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../screens/comments_screen.dart';
import 'verified_badge.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final myUid = AppState.instance.uid;
    final postId = post['id'] as String;
    final authorUid = post['uid'] as String? ?? '';
    final authorName = post['authorName'] ?? 'User';
    final text = post['text'] ?? '';
    final mediaUrl = post['mediaUrl'] as String?;
    final mediaType = post['mediaType'] as String?;
    final likesCount = post['likesCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;

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
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: authorUid.isEmpty ? null : fs.getUserById(authorUid),
                    builder: (context, snap) {
                      final isVerified = snap.data?['isVerified'] == true;
                      return Row(
                        children: [
                          Flexible(
                            child: Text(authorName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          if (isVerified) const VerifiedBadge(),
                        ],
                      );
                    },
                  ),
                ),
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                StreamBuilder<bool>(
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
                              size: 19,
                              color: liked ? AppColors.hot : AppColors.muted),
                          const SizedBox(width: 5),
                          Text('$likesCount',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CommentsScreen(postId: postId)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined,
                          size: 18, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text('$commentsCount',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    final shareText = text.isNotEmpty
                        ? '$authorName on Sitara Live: $text'
                        : 'Check out $authorName\'s post on Sitara Live!';
                    Share.share(shareText);
                  },
                  child: const Icon(Icons.share_outlined,
                      size: 18, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
