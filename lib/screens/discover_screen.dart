import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'public_profile_screen.dart';
import 'live_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final bool embedded;
  const DiscoverScreen({super.key, this.embedded = false});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: 'Latest'),
            Tab(text: 'Hot'),
            Tab(text: 'New Faces'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _LatestTab(fs: _fs),
              _HotTab(fs: _fs),
              _NewFacesTab(fs: _fs),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Stack(
        children: [
          content,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: AppColors.hot,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Discover')),
      body: content,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.hot,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LatestTab extends StatelessWidget {
  final FirestoreService fs;
  const _LatestTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.latestPosts(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final posts = snap.data!;
        if (posts.isEmpty) {
          return const Center(
            child: Text('No posts yet — be the first!', style: TextStyle(color: AppColors.muted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (context, i) => PostCard(post: posts[i]),
        );
      },
    );
  }
}

class _HotTab extends StatelessWidget {
  final FirestoreService fs;
  const _HotTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('🔥 Trending Live Rooms',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold)),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: fs.topLiveRooms(),
          builder: (context, snap) {
            final rooms = snap.data ?? [];
            if (rooms.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No one is live right now', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              );
            }
            return SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final r = rooms[i];
                  final viewers = r['viewers'] ?? 0;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LiveScreen(
                          isHost: false,
                          roomId: r['id'],
                          hostName: r['hostName'] ?? 'Host',
                        ),
                      ),
                    ),
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Color(r['c1'] ?? 0xFF7A1BFF),
                          Color(r['c2'] ?? 0xFFFF2E6B),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['hostName'] ?? 'Host',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('🎧 $viewers', style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('⭐ Top Hosts',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold)),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: fs.topHosts(),
          builder: (context, snap) {
            final hosts = snap.data ?? [];
            if (hosts.isEmpty) {
              return const Text('No hosts yet', style: TextStyle(color: AppColors.muted, fontSize: 12));
            }
            return Column(
              children: hosts.map((u) {
                final name = u['nickname'] ?? u['username'] ?? 'User';
                final followers = u['followersCount'] ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.hot,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('$followers followers', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(targetUid: u['uid'])),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _NewFacesTab extends StatelessWidget {
  final FirestoreService fs;
  const _NewFacesTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    final myUid = AppState.instance.uid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.newFaces(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final users = snap.data!.where((u) => u['uid'] != myUid).toList();
        if (users.isEmpty) {
          return const Center(child: Text('No new users yet', style: TextStyle(color: AppColors.muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
          itemBuilder: (context, i) {
            final u = users[i];
            final name = u['nickname'] ?? u['username'] ?? 'User';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.hot,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
              ),
              title: Text(name),
              subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
              trailing: StreamBuilder<bool>(
                stream: fs.isFollowing(myUid, u['uid']),
                builder: (context, followSnap) {
                  final following = followSnap.data ?? false;
                  return OutlinedButton(
                    onPressed: () => following
                        ? fs.unfollowUser(myUid, u['uid'])
                        : fs.followUser(myUid, u['uid']),
                    child: Text(following ? 'Following' : 'Follow'),
                  );
                },
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PublicProfileScreen(targetUid: u['uid'])),
              ),
            );
          },
        );
      },
    );
  }
}
