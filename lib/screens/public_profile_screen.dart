import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';

/// Shown when you open someone ELSE's profile — e.g. tapping their
/// name/avatar in a live room, or opening a profile via search.
/// Shows their public info + a Follow/Following button (TikTok style).
class PublicProfileScreen extends StatefulWidget {
  final String targetUid;
  const PublicProfileScreen({super.key, required this.targetUid});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _fs = FirestoreService();
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _fs.getUserById(widget.targetUid);
    if (!mounted) return;
    setState(() {
      _user = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AppState.instance.uid;
    final isMe = myUid == widget.targetUid;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    final username = _user!['username'] ?? 'Unknown';
    final nickname = _user!['nickname'] ?? username;
    final followers = _user!['followersCount'] ?? 0;
    final following = _user!['followingCount'] ?? 0;
    final isPublic = _user!['profilePublic'] ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(nickname)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppColors.hot, Color(0xFF7A1BFF)]),
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(nickname,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('@$username',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text('ID: ${widget.targetUid}',
                      style:
                          const TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('Followers', followers),
                _statItem('Following', following),
              ],
            ),
            const SizedBox(height: 20),
            if (!isMe)
              StreamBuilder<bool>(
                stream: _fs.isFollowing(myUid, widget.targetUid),
                builder: (context, snap) {
                  final isFollowingNow = snap.data ?? false;
                  return SizedBox(
                    width: double.infinity,
                    child: isFollowingNow
                        ? OutlinedButton(
                            onPressed: () =>
                                _fs.unfollowUser(myUid, widget.targetUid),
                            child: const Text('Following ✓'),
                          )
                        : ElevatedButton(
                            onPressed: () =>
                                _fs.followUser(myUid, widget.targetUid),
                            child: const Text('Follow'),
                          ),
                  );
                },
              ),
            if (!isPublic && !isMe) ...[
              const SizedBox(height: 20),
              const Center(
                child: Text('🔒 This profile is private',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      children: [
        Text('$count',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }
}
