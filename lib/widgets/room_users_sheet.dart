import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

/// Bottom sheet opened from the viewer-count button on the live screen.
/// Host sees 4 tabs (Online / Ban / Kick out / Mic request); a normal
/// viewer only sees the Online list.
/// When [inviteSeatIndex] is set, the Online tab shows an "Invite"
/// button next to each listener instead of Kick/Ban.
class RoomUsersSheet extends StatelessWidget {
  final String roomId;
  final bool isHost;
  final int? inviteSeatIndex;

  const RoomUsersSheet({
    super.key,
    required this.roomId,
    required this.isHost,
    this.inviteSeatIndex,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final tabs = isHost
        ? const ['Online', 'Ban', 'Kick out', 'Mic request']
        : const ['Online'];
    final title = inviteSeatIndex != null
        ? 'Invite to seat ${inviteSeatIndex! + 1}'
        : 'Room users';

    return DefaultTabController(
      length: tabs.length,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (tabs.length > 1)
              TabBar(
                isScrollable: true,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.gold,
                tabs: tabs.map((t) => Tab(text: t)).toList(),
              ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: TabBarView(
                children: [
                  _OnlineList(
                      fs: fs,
                      roomId: roomId,
                      isHost: isHost,
                      inviteSeatIndex: inviteSeatIndex),
                  if (isHost) _BannedList(fs: fs, roomId: roomId),
                  if (isHost) _KickedList(fs: fs, roomId: roomId),
                  if (isHost) _MicRequestList(fs: fs, roomId: roomId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- shared bits ----------

class _UserRow extends StatelessWidget {
  final String name;
  final String uid;
  final String? subtitle;
  final Widget trailing;
  const _UserRow({
    required this.name,
    required this.uid,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.hot,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(subtitle ?? 'ID: $uid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: AppColors.muted),
          SizedBox(height: 8),
          Text('No data',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message, String action) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style: const TextStyle(color: AppColors.hot))),
      ],
    ),
  );
  return result == true;
}

// ---------- Online ----------

class _OnlineList extends StatelessWidget {
  final FirestoreService fs;
  final String roomId;
  final bool isHost;
  final int? inviteSeatIndex;
  const _OnlineList({
    required this.fs,
    required this.roomId,
    required this.isHost,
    this.inviteSeatIndex,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.listenersOf(roomId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        if (users.isEmpty) return const _EmptyState();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i];
            final uid = (u['uid'] ?? '') as String;
            final name = (u['name'] ?? 'User') as String;

            Widget trailing = const SizedBox.shrink();
            if (isHost && inviteSeatIndex != null) {
              trailing = ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await fs.placeUserInSeat(roomId, uid, name,
                      preferredIndex: inviteSeatIndex);
                  if (context.mounted) Navigator.pop(context);
                  messenger.showSnackBar(SnackBar(
                      content: Text(
                          ok ? '$name invited to the mic' : 'No free seat available')));
                },
                child: const Text('Invite'),
              );
            } else if (isHost) {
              trailing = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () async {
                      if (await _confirm(context,
                          'Kick $name out of this room?', 'Kick')) {
                        fs.kickUser(roomId, uid, name);
                      }
                    },
                    child: const Text('Kick'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (await _confirm(context,
                          'Ban $name from this room?', 'Ban')) {
                        fs.banUser(roomId, uid, name);
                      }
                    },
                    child: const Text('Ban',
                        style: TextStyle(color: AppColors.hot)),
                  ),
                ],
              );
            }
            return _UserRow(name: name, uid: uid, trailing: trailing);
          },
        );
      },
    );
  }
}

// ---------- Ban ----------

class _BannedList extends StatelessWidget {
  final FirestoreService fs;
  final String roomId;
  const _BannedList({required this.fs, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.bannedOf(roomId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        if (users.isEmpty) return const _EmptyState();
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i];
            final uid = (u['uid'] ?? '') as String;
            final name = (u['name'] ?? 'User') as String;
            return _UserRow(
              name: name,
              uid: uid,
              trailing: TextButton(
                onPressed: () => fs.unbanUser(roomId, uid),
                child: const Text('Unban'),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------- Kick out ----------

class _KickedList extends StatelessWidget {
  final FirestoreService fs;
  final String roomId;
  const _KickedList({required this.fs, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.kickedOf(roomId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        if (users.isEmpty) return const _EmptyState();
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i];
            final uid = (u['uid'] ?? '') as String;
            final name = (u['name'] ?? 'User') as String;
            return _UserRow(
              name: name,
              uid: uid,
              subtitle: 'Kicked out — blocked for 30 min',
              trailing: TextButton(
                onPressed: () => fs.restoreKicked(roomId, uid),
                child: const Text('Restore'),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------- Mic request ----------

class _MicRequestList extends StatelessWidget {
  final FirestoreService fs;
  final String roomId;
  const _MicRequestList({required this.fs, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.micRequestsOf(roomId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data!;
        if (requests.isEmpty) return const _EmptyState();
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, i) {
            final r = requests[i];
            final uid = (r['uid'] ?? '') as String;
            final name = (r['name'] ?? 'User') as String;
            final seatIndex = r['seatIndex'] as int?;
            return _UserRow(
              name: name,
              uid: uid,
              subtitle: seatIndex != null
                  ? 'Wants seat ${seatIndex + 1}'
                  : 'Wants a seat',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => fs.cancelMicRequest(roomId, uid),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await fs.approveMicRequest(
                          roomId, uid, name, seatIndex);
                      if (!ok && context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            content: const Text('No free seat available'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK')),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
