import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/verified_badge.dart';

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

        if (widget.targetUid != AppState.instance.uid) {
      final myName = AppState.instance.nickname.isNotEmpty
          ? AppState.instance.nickname
          : AppState.instance.username;
      _fs.recordProfileView(widget.targetUid, AppState.instance.uid, myName);
    }
  void _openMoreMenu() {
    final myUid = AppState.instance.uid;
    final name = _user?['nickname'] ?? _user?['username'] ?? 'User';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.hot),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(myUid, name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code, color: AppColors.muted),
                title: const Text('QR Code'),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('QR Code'),
                      content: Text('ID: ${widget.targetUid}\n(QR image coming soon)',
                          style: const TextStyle(fontSize: 12.5)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder<bool>(
                stream: _fs.isBlocked(myUid, widget.targetUid),
                builder: (context, snap) {
                  final blocked = snap.data ?? false;
                  return ListTile(
                    leading: Icon(Icons.block,
                        color: blocked ? AppColors.gold : AppColors.hot),
                    title: Text(blocked ? 'Unblock' : 'Block'),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (blocked) {
                        _fs.unblockUser(myUid, widget.targetUid);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name unblocked')));
                      } else {
                        _fs.blockUser(myUid, widget.targetUid);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name blocked')));
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog(String myUid, String name) {
    const reasons = [
      'Spam',
      'Inappropriate content',
      'Harassment or bullying',
      'Fake account',
      'Other',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Report $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map((r) => ListTile(
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _fs.reportUser(
                        reporterUid: myUid,
                        reportedUid: widget.targetUid,
                        reportedName: name,
                        reason: r,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Report sent to Sitara Live team')),
                        );
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
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
    final isVerified = _user!['isVerified'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(nickname),
        actions: [
          if (!isMe)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _openMoreMenu,
            ),
        ],
      ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nickname,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (isVerified) const VerifiedBadge(),
                    ],
                  ),
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
                _statItem('Following', following),
                _statItem('Followers', followers),
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
