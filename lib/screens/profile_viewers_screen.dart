import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import 'public_profile_screen.dart';

class ProfileViewersScreen extends StatelessWidget {
  const ProfileViewersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Profile Viewers')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.profileViewersOf(AppState.instance.uid),
        builder: (context, snap) {
          final viewers = snap.data ?? [];
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (viewers.isEmpty) {
            return const Center(
              child: Text('No one has viewed your profile yet',
                  style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: viewers.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, i) {
              final v = viewers[i];
              final name = v['viewerName'] ?? 'User';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.hot,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(name),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PublicProfileScreen(targetUid: v['viewerUid'])),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
