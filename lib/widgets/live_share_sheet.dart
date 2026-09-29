import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';

/// Opened from the share icon on the live screen. Top: friends from
/// the user's inbox chats, tap to send them the room link directly.
/// Bottom row: Mute room, Message (reply without leaving live), Gift, More.
class LiveShareSheet extends StatelessWidget {
  final String roomId;
  final String roomName;
  final bool roomMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenGift;
  final VoidCallback onOpenMore;

  const LiveShareSheet({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.roomMuted,
    required this.onToggleMute,
    required this.onOpenInbox,
    required this.onOpenGift,
    required this.onOpenMore,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final myUid = AppState.instance.uid;
    final linkText = 'Join the live voice room on Sitara Live! 🎙\nRoom ID: $roomId';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            SizedBox(
              height: 96,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: fs.myChatFriends(myUid),
                builder: (context, snap) {
                  final friends = snap.data ?? [];
                  if (friends.isEmpty) {
                    return const Center(
                      child: Text('No chats yet — message someone first',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final f = friends[i];
                      final name = (f['nickname'] ?? f['username'] ?? 'User') as String;
                      return GestureDetector(
                        onTap: () async {
                          await fs.sendMessage(
                              fromUid: myUid, toUid: f['uid'] as String, text: linkText);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sent to $name')));
                          }
                        },
                        child: SizedBox(
                          width: 62,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.hot,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 5),
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Share.share(linkText);
                },
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('Share via other apps'),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionIcon(
                  roomMuted ? Icons.volume_off : Icons.volume_up,
                  roomMuted ? 'Unmute' : 'Mute',
                  () {
                    Navigator.pop(context);
                    onToggleMute();
                  },
                ),
                _actionIcon(Icons.mail_outline, 'Message', () {
                  Navigator.pop(context);
                  onOpenInbox();
                }),
                _actionIcon(Icons.card_giftcard, 'Gift', () {
                  Navigator.pop(context);
                  onOpenGift();
                }),
                _actionIcon(Icons.apps, 'More', () {
                  Navigator.pop(context);
                  onOpenMore();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
