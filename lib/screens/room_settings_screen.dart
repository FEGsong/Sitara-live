import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/agora_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

/// Host-only "Room settings" page: cover, name, theme, music, admins,
/// room lock, welcome message and mic mode.
class RoomSettingsScreen extends StatefulWidget {
  final String roomId;
  final AgoraService agora;
  const RoomSettingsScreen({
    super.key,
    required this.roomId,
    required this.agora,
  });

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  late final Stream<DocumentSnapshot> _roomStream = _fs.roomDoc(widget.roomId);
  bool _uploading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _changeCover() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 900);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await _storage.uploadRoomCover(
          file: File(picked.path), roomId: widget.roomId);
      await _fs.updateRoomCover(widget.roomId, url);
      _snack('Room cover updated');
    } catch (_) {
      _snack('Could not upload the cover — Firebase Storage must be enabled');
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<String?> _askText(
    String title,
    String initial, {
    int maxLen = 30,
    int maxLines = 1,
    String hint = '',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLength: maxLen,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _editName(String current) async {
    final name = await _askText('Room name', current, hint: 'Room name');
    if (name == null || name.isEmpty) return;
    await _fs.updateRoomName(widget.roomId, name);
  }

  Future<void> _editWelcome(String current) async {
    final msg = await _askText(
      'Welcome message',
      current,
      maxLen: 120,
      maxLines: 3,
      hint: 'Shown to everyone who enters your room',
    );
    if (msg == null) return;
    await _fs.updateWelcomeMessage(widget.roomId, msg);
    _snack(msg.isEmpty ? 'Welcome message removed' : 'Welcome message saved');
  }

  Future<void> _pickMicMode(int current, List<dynamic> seats) async {
    const options = [9, 15, 25, 30, 50, 100];
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text('Mic mode',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            ...options.map((n) => ListTile(
                  title: Text('$n mics'),
                  trailing: n == current
                      ? const Icon(Icons.check, color: AppColors.gold)
                      : null,
                  onTap: () => Navigator.pop(ctx, n),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == current) return;

    var displaced = 0;
    for (var i = chosen; i < seats.length; i++) {
      if (seats[i] != null) displaced++;
    }
    if (displaced > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          content: Text(
              '$displaced ${displaced == 1 ? 'person' : 'people'} will be removed from the mic. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue',
                    style: TextStyle(color: AppColors.hot))),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _fs.setSeatCount(widget.roomId, chosen);
    _snack('Room now has $chosen mics');
  }

  void _openMusic() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MusicSheet(agora: widget.agora),
    );
  }

  // ---------- small layout helpers ----------

  Widget _section(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(const Divider(height: 1, color: AppColors.line));
      }
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(
    String title, {
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? '',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 6),
            trailing ??
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Room settings')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _roomStream,
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final coverUrl = (data['coverUrl'] ?? '') as String;
          final roomName = (data['roomName'] ?? '') as String;
          final welcome = (data['welcomeMessage'] ?? '') as String;
          final locked = data['roomLocked'] == true;
          final seatCount = (data['seatCount'] ?? 0) as int;
          final seats = List<dynamic>.from(data['seats'] ?? []);
          final adminCount = List<dynamic>.from(data['adminUids'] ?? []).length;

          return ListView(
            padding: const EdgeInsets.only(top: 18, bottom: 30),
            children: [
              // ---- Room cover ----
              Center(
                child: GestureDetector(
                  onTap: _uploading ? null : _changeCover,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: coverUrl.isEmpty
                              ? const LinearGradient(
                                  colors: [AppColors.hot, Color(0xFF7A1BFF)])
                              : null,
                          image: coverUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(coverUrl),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: _uploading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : (coverUrl.isEmpty
                                ? const Text('🎙',
                                    style: TextStyle(fontSize: 34))
                                : null),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(20))),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('Room cover',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 18),
                  child: Text('Tap to edit',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ),
              ),

              _section([
                _row('Room name',
                    value: roomName, onTap: () => _editName(roomName)),
              ]),

              _section([
                _row('Theme',
                    value: 'Coming soon',
                    onTap: () => _snack('Themes are coming soon')),
                _row('Music', onTap: _openMusic),
                _row('Admin',
                    value: adminCount == 0 ? '' : '$adminCount',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            RoomAdminsScreen(roomId: widget.roomId)))),
                _row(
                  'Room lock',
                  trailing: Switch(
                    value: locked,
                    activeColor: AppColors.gold,
                    onChanged: (v) {
                      _fs.setRoomLocked(widget.roomId, v);
                      _snack(v
                          ? 'Room locked — only admins can enter'
                          : 'Room unlocked');
                    },
                  ),
                  onTap: () {
                    _fs.setRoomLocked(widget.roomId, !locked);
                    _snack(!locked
                        ? 'Room locked — only admins can enter'
                        : 'Room unlocked');
                  },
                ),
              ]),

              _section([
                _row('Welcome message',
                    value: welcome.isEmpty ? 'Not set' : welcome,
                    onTap: () => _editWelcome(welcome)),
                _row('Mic mode',
                    value: '$seatCount mics',
                    onTap: () => _pickMicMode(seatCount, seats)),
              ]),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'When the room is locked, nobody new can join except the admins you added. People already inside stay.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// Music sheet — plays a song from this phone into the room
// =====================================================================

class _MusicSheet extends StatefulWidget {
  final AgoraService agora;
  const _MusicSheet({required this.agora});

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
  late double _volume = widget.agora.musicVolume.toDouble();

  Future<void> _pickSong() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    try {
      await widget.agora.startMusic(file.path!, file.name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final agora = widget.agora;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Music',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Everyone in the room can hear the song. Use headphones to avoid echo.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String?>(
              valueListenable: agora.musicName,
              builder: (context, name, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: agora.musicPlaying,
                  builder: (context, playing, _) {
                    if (name == null) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text('No song playing',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                      );
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.music_note, color: AppColors.cyan),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          IconButton(
                            icon: Icon(
                                playing ? Icons.pause_circle : Icons.play_circle,
                                size: 30),
                            onPressed: () => playing
                                ? agora.pauseMusic()
                                : agora.resumeMusic(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop_circle_outlined,
                                size: 28, color: AppColors.hot),
                            onPressed: agora.stopMusic,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            Row(
              children: [
                const Icon(Icons.volume_down, size: 18, color: AppColors.muted),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 100,
                    activeColor: AppColors.gold,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      agora.setMusicVolume(v.round());
                    },
                  ),
                ),
                const Icon(Icons.volume_up, size: 18, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickSong,
                icon: const Icon(Icons.library_music),
                label: const Text('Choose a song from your phone'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Room admins — the host picks people from the online list
// =====================================================================

class RoomAdminsScreen extends StatelessWidget {
  final String roomId;
  const RoomAdminsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Room admins')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: fs.roomDoc(roomId),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final adminUids = List<String>.from(data['adminUids'] ?? []);
          final adminNames =
              Map<String, dynamic>.from(data['adminNames'] ?? {});

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _SectionLabel('ADMINS'),
              if (adminUids.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('No admins yet',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ),
              ...adminUids.map((uid) => _PersonRow(
                    name: (adminNames[uid] ?? 'User') as String,
                    uid: uid,
                    actionLabel: 'Remove',
                    danger: true,
                    onAction: () => fs.removeRoomAdmin(roomId, uid),
                  )),
              const _SectionLabel('ONLINE — TAP TO MAKE ADMIN'),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: fs.listenersOf(roomId),
                builder: (context, s) {
                  final users = (s.data ?? [])
                      .where((u) => !adminUids.contains(u['uid']))
                      .toList();
                  if (users.isEmpty) {
                    return const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('No one else is online right now',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                    );
                  }
                  return Column(
                    children: users.map((u) {
                      final uid = (u['uid'] ?? '') as String;
                      final name = (u['name'] ?? 'User') as String;
                      return _PersonRow(
                        name: name,
                        uid: uid,
                        actionLabel: 'Make admin',
                        onAction: () => fs.addRoomAdmin(roomId, uid, name),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontWeight: FontWeight.bold,
              letterSpacing: .6)),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String name;
  final String uid;
  final String actionLabel;
  final bool danger;
  final VoidCallback onAction;
  const _PersonRow({
    required this.name,
    required this.uid,
    required this.actionLabel,
    required this.onAction,
    this.danger = false,
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
                Text('ID: $uid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel,
                style: TextStyle(color: danger ? AppColors.hot : null)),
          ),
        ],
      ),
    );
  }
}
