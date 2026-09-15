import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import 'public_profile_screen.dart';

/// Shows the list of users who currently follow you.
class NewFriendsScreen extends StatelessWidget {
  const NewFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final myUid = AppState.instance.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('New Friends')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.followersOf(myUid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final followers = snap.data!;
          if (followers.isEmpty) {
            return const Center(
              child: Text('No followers yet', style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            itemCount: followers.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, i) {
              final u = followers[i];
              final name = u['nickname'] ?? u['username'] ?? 'Unknown';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.hot,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(name),
                subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PublicProfileScreen(targetUid: u['uid'])),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
