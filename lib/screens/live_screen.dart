import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/agora_service.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_pill.dart';
import '../widgets/room_users_sheet.dart';
import '../widgets/live_share_sheet.dart';
import 'room_settings_screen.dart';
import 'inbox_screen.dart';

class LiveScreen extends StatefulWidget {
  final bool isHost;
  final int seatCount;
  final String? roomId;
  final String? hostName;

  const LiveScreen({
    super.key,
    required this.isHost,
    this.seatCount = 15,
    this.roomId,
    this.hostName,
  });

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _ChatLine {
  final String user;
  final String text;
  final bool isGift;
  _ChatLine(this.user, this.text, this.isGift);
}

class _FlyingGift {
  final String id;
  final String icon;
  final double left;
  _FlyingGift(this.id, this.icon, this.left);
}

const List<Map<String, dynamic>> kGifts = [
  {'id': 'rose', 'icon': '🌹', 'name': 'Rose', 'price': 10},
  {'id': 'heart', 'icon': '❤️', 'name': 'Heart', 'price': 20},
  {'id': 'star', 'icon': '⭐', 'name': 'Star', 'price': 50},
  {'id': 'crown', 'icon': '👑', 'name': 'Crown', 'price': 150},
  {'id': 'diamond', 'icon': '💎', 'name': 'Diamond', 'price': 300},
  {'id': 'car', 'icon': '🏎️', 'name': 'Sports Car', 'price': 1000},
];

class _LiveScreenState extends State<LiveScreen> {
  final _agora = AgoraService();
  final _firestore = FirestoreService();
  final _chatCtrl = TextEditingController();
  final List<_ChatLine> _chat = [];
  final List<_FlyingGift> _flyingGifts = [];

  String? _roomId;
  int? _mySeatIndex;
  bool _micMuted = false;
  bool _roomMuted = false;
  bool _connecting = true;
  String? _errorMessage;

  String? _selectedGift;
  bool _giftTrayOpen = false;

  Set<int> _speakingAgoraUids = {};

  StreamSubscription<DocumentSnapshot>? _roomSub;
  StreamSubscription<bool>? _presenceSub;
  bool _sawSelfPresence = false;
  bool _endRoomOnExit = false;
  bool _leaving = false;
  bool _countedViewer = false;
  bool _registeredListener = false;

  bool _isRoomAdmin = false;
  bool get _canManage => widget.isHost || _isRoomAdmin;

  Stream<DocumentSnapshot>? _topStream;
  Stream<DocumentSnapshot>? _seatsStream;
  Stream<List<Map<String, dynamic>>>? _countStream;

  String get _myName {
    final s = AppState.instance;
    if (s.nickname.isNotEmpty) return s.nickname;
    if (s.username.isNotEmpty) return s.username;
    return widget.isHost ? 'Host' : 'Guest';
  }

  @override
  void initState() {
    super.initState();
    _agora.onSpeakingUpdate = (speaking) {
      if (!mounted) return;
      setState(() => _speakingAgoraUids = speaking.toSet());
    };
    if (widget.isHost) {
      if (widget.roomId != null) {
        _rejoinAsHost();
      } else {
        _createRoomAndJoin();
      }
    } else {
      _roomId = widget.roomId;
      _joinAsListener();
    }
  }

  Future<void> _createRoomAndJoin() async {
    try {
      final uid = AppState.instance.uid;
      final id = await _firestore.createRoom(
        hostUid: uid,
        hostName: _myName,
        seatCount: widget.seatCount,
      );
      _roomId = id;
      await _agora.joinChannel(channel: id, isHost: true, myUid: uid);
      if (!mounted) return;
      setState(() {
        _mySeatIndex = 0;
        _connecting = false;
      });
      _startRoomListeners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not start room: $e';
        _connecting = false;
      });
    }
  }

  Future<void> _rejoinAsHost() async {
    try {
      _roomId = widget.roomId;
      await _agora.joinChannel(
          channel: _roomId!, isHost: true, myUid: AppState.instance.uid);
      if (!mounted) return;
      setState(() {
        _mySeatIndex = 0;
        _connecting = false;
      });
      _startRoomListeners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not rejoin room: $e';
        _connecting = false;
      });
    }
  }

  Future<void> _joinAsListener() async {
    if (_roomId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No room specified.';
          _connecting = false;
        });
      }
      return;
    }
    try {
      final uid = AppState.instance.uid;

      final reason = await _firestore.entryBlockReason(_roomId!, uid);
      if (reason != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = reason == 'banned'
              ? 'You are banned from this room.'
              : 'You were removed from this room. Please try again later.';
          _connecting = false;
        });
        return;
      }

      final snap = await _firestore.getRoomOnce(_roomId!);
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null || data['status'] == 'ended') {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'This live has ended.';
          _connecting = false;
        });
        return;
      }

      final admins = List<String>.from(data['adminUids'] ?? []);
      if (data['roomLocked'] == true && !admins.contains(uid)) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'This room is locked by the host.';
          _connecting = false;
        });
        return;
      }

      _firestore.recordRecentRoom(
        uid: uid,
        roomId: _roomId!,
        hostName: data['hostName'] ?? widget.hostName ?? 'Host',
        c1: data['c1'] ?? 0xFF7A1BFF,
        c2: data['c2'] ?? 0xFFFF2E6B,
      );

      await _firestore.incrementViewers(_roomId!, 1);
      _countedViewer = true;
      await _firestore.joinRoomAsListener(_roomId!, uid, _myName);
      _registeredListener = true;

      await _agora.joinChannel(channel: _roomId!, isHost: false, myUid: uid);
      if (!mounted) return;
      setState(() => _connecting = false);
      _startRoomListeners();

      final welcome = ((data['welcomeMessage'] ?? '') as String).trim();
      if (welcome.isNotEmpty) {
        _addChat(data['hostName'] ?? widget.hostName ?? 'Host', welcome, false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not connect: $e';
        _connecting = false;
      });
    }
  }

  void _startRoomListeners() {
    if (_roomId == null) return;
    final myUid = AppState.instance.uid;

    _roomSub?.cancel();
    _roomSub = _firestore.roomDoc(_roomId!).listen((snap) async {
      if (!mounted) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      if (!widget.isHost && data['status'] == 'ended') {
        _exitWithMessage('The host ended this live');
        return;
      }

      if (!widget.isHost) {
        final admins = List<String>.from(data['adminUids'] ?? []);
        final nowAdmin = admins.contains(myUid);
        if (nowAdmin != _isRoomAdmin) {
          setState(() => _isRoomAdmin = nowAdmin);
          _addChat(
              'System',
              nowAdmin
                  ? 'The host made you an admin 🛡'
                  : 'You are no longer an admin',
              false);
        }
      }

      final seats = List<dynamic>.from(data['seats'] ?? []);
      final idx = seats.indexWhere((s) => s is Map && s['uid'] == myUid);
      final newIdx = idx == -1 ? null : idx;
      if (newIdx == _mySeatIndex) return;

      final wasSeated = _mySeatIndex != null;
      setState(() {
        _mySeatIndex = newIdx;
        if (newIdx != null && !wasSeated) _micMuted = false;
      });

      if (!widget.isHost) {
        if (newIdx != null && !wasSeated) {
          await _agora.setSpeakingRole(true);
          _addChat('System', 'You are on the mic 🎙', false);
        } else if (newIdx == null && wasSeated) {
          await _agora.setSpeakingRole(false);
        }
      }
    });

    if (!widget.isHost) {
      _presenceSub?.cancel();
      _presenceSub =
          _firestore.isListenerPresent(_roomId!, myUid).listen((present) {
        if (present) {
          _sawSelfPresence = true;
        } else if (_sawSelfPresence) {
          _exitWithMessage('You were removed from this room');
        }
      });
    }
  }

  void _exitWithMessage(String message) {
    if (_leaving || !mounted) return;
    _leaving = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _presenceSub?.cancel();

    final roomId = _roomId;
    final uid = AppState.instance.uid;
    if (roomId != null) {
      if (widget.isHost) {
        if (_endRoomOnExit) _firestore.endRoom(roomId);
      } else {
        if (_countedViewer) _firestore.incrementViewers(roomId, -1);
        if (_registeredListener) _firestore.leaveRoomAsListener(roomId, uid);
        if (_mySeatIndex != null) _firestore.leaveSeat(roomId, _mySeatIndex!);
        _firestore.cancelMicRequest(roomId, uid);
      }
    }
    _chatCtrl.dispose();
    _agora.leaveChannel();
    super.dispose();
  }

  void _addChat(String user, String text, bool isGift) {
    if (!mounted) return;
    setState(() {
      _chat.add(_ChatLine(user, text, isGift));
      if (_chat.length > 10) _chat.removeAt(0);
    });
  }

  // ---------------- seats ----------------

  Future<void> _takeSeatDirect(int index) async {
    await _firestore.takeSeat(_roomId!, index, AppState.instance.uid, _myName);
    await _agora.setSpeakingRole(true);
    if (mounted) {
      setState(() {
        _mySeatIndex = index;
        _micMuted = false;
      });
    }
  }

  void _showManageSeatMenu(int index, bool isLocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _menuItem('Invite to the microphone', () {
                Navigator.pop(ctx);
                _openRoomUsers(inviteSeatIndex: index);
              }),
              const Divider(height: 1),
              _menuItem(isLocked ? 'Unlock Mic' : 'Mic Locked', () {
                Navigator.pop(ctx);
                _firestore.toggleSeatLock(_roomId!, index, !isLocked);
                _snack(isLocked ? 'Seat unlocked' : 'Seat locked');
              }),
              const Divider(height: 1),
              _menuItem('Get on the microphone by yourself', () async {
                Navigator.pop(ctx);
                if (_mySeatIndex != null) {
                  await _firestore.leaveSeat(_roomId!, _mySeatIndex!);
                }
                await _takeSeatDirect(index);
              }),
              const Divider(height: 1),
              _menuItem('Cancel', () => Navigator.pop(ctx), isCancel: true),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem(String text, VoidCallback onTap, {bool isCancel = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isCancel ? Colors.grey : Colors.black87,
              fontWeight: isCancel ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSeatTap(
      int index, Map<String, dynamic>? seatData, List<int> lockedSeats) async {
    if (_roomId == null) return;
    final uid = AppState.instance.uid;

    if (seatData != null && seatData['uid'] == uid) {
      await _firestore.leaveSeat(_roomId!, index);
      if (!widget.isHost) await _agora.setSpeakingRole(false);
      if (mounted) setState(() => _mySeatIndex = null);
      return;
    }

    if (seatData != null) {
      _snack('Seat already taken');
      return;
    }

    if (_canManage) {
      _showManageSeatMenu(index, lockedSeats.contains(index));
      return;
    }

    if (lockedSeats.contains(index)) {
      _snack('This seat is locked by the host');
      return;
    }
    if (_mySeatIndex != null) {
      _snack('Leave your current seat first');
      return;
    }
    await _firestore.requestMic(_roomId!, uid, _myName, index);
    _snack('Mic request sent to the host');
  }

  Future<void> _toggleMic() async {
    final newMuted = !_micMuted;
    setState(() => _micMuted = newMuted);
    await _agora.toggleMic(newMuted);
    if (_roomId != null && _mySeatIndex != null) {
      await _firestore.toggleSeatMute(_roomId!, _mySeatIndex!, newMuted);
    }
  }

  // ---------------- top bar actions ----------------

  void _openRoomUsers({int? inviteSeatIndex}) {
    if (_roomId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RoomUsersSheet(
        roomId: _roomId!,
        isHost: _canManage,
        inviteSeatIndex: inviteSeatIndex,
      ),
    );
  }

  void _openSettings() {
    if (_roomId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomSettingsScreen(roomId: _roomId!, agora: _agora),
      ),
    );
  }

  void _toggleRoomMute() {
    setState(() => _roomMuted = !_roomMuted);
    _agora.muteRoomForMe(_roomMuted);
    _snack(_roomMuted ? 'Room muted for you' : 'Room unmuted');
  }

  void _shareRoom() {
    if (_roomId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LiveShareSheet(
        roomId: _roomId!,
        roomName: _myName,
        roomMuted: _roomMuted,
        onToggleMute: _toggleRoomMute,
        onOpenInbox: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const InboxScreen())),
        onOpenGift: () => setState(() => _giftTrayOpen = true),
        onOpenMore: () => _openRoomUsers(),
      ),
    );
  }

  void _onPowerTap() {
    if (!widget.isHost) {
      Navigator.of(context).pop();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _menuItem('Minimize (live stays on)', () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            }),
            const Divider(height: 1),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _endRoomOnExit = true;
                Navigator.of(context).pop();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Text('End live',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.red,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const Divider(height: 1),
            _menuItem('Cancel', () => Navigator.pop(ctx), isCancel: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------- gifts ----------------

  void _sendGift() {
    if (_selectedGift == null) {
      _snack('Please select a gift first');
      return;
    }
    final gift = kGifts.firstWhere((g) => g['id'] == _selectedGift);
    if (AppState.instance.coins < gift['price']) {
      _snack('Not enough coins — buy more from your wallet');
      return;
    }
    setState(() {
      FirestoreService()
          .spendCoins(AppState.instance.uid, gift['price'] as int);
      AppState.instance.giftsSent++;
      _giftTrayOpen = false;
    });
    _addChat('You', 'sent a ${gift['icon']} ${gift['name']}!', true);
    _launchGift(gift['icon'] as String);
  }

  void _launchGift(String icon) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final left = 0.3 + Random().nextDouble() * 0.4;
    setState(() => _flyingGifts.add(_FlyingGift(id, icon, left)));
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _flyingGifts.removeWhere((g) => g.id == id));
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0714),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B0E2B), Color(0xFF0B0714)],
                ),
              ),
            ),
          ),
          if (_connecting)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null || _roomId == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ?? 'Could not connect to the room.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _seatsArea()),
                  _chatArea(),
                  if (_mySeatIndex != null) _micRow(),
                  _bottomInputBar(),
                ],
              ),
            ),
          ..._flyingGifts.map((g) => _FlyingGiftWidget(gift: g)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            left: 0,
            right: 0,
            bottom: _giftTrayOpen ? 0 : -320,
            child: _giftTray(),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(.45), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    );
  }

  Widget _countPill() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _countStream ??= _firestore.listenersOf(_roomId!),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return GestureDetector(
          onTap: () => _openRoomUsers(),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(.45),
                borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_outlined,
                    size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text('$count',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _topStream ??= _firestore.roomDoc(_roomId!),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final hostName = data?['hostName'] ?? widget.hostName ?? 'Host';
          final roomName = data?['roomName'] ?? "$hostName's Room";
          final coverUrl = (data?['coverUrl'] ?? '') as String;
          final idText =
              _roomId!.length > 7 ? _roomId!.substring(0, 7) : _roomId!;

          return Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.45),
                      borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: coverUrl.isEmpty
                              ? const LinearGradient(
                                  colors: [AppColors.hot, Color(0xFF7A1BFF)])
                              : null,
                          shape: BoxShape.circle,
                          image: coverUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(coverUrl),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: coverUrl.isEmpty
                            ? const Text('🎙', style: TextStyle(fontSize: 14))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(roomName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold)),
                            Text('ID:$idText',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _countPill(),
              if (widget.isHost) ...[
                const SizedBox(width: 6),
                _circleBtn(Icons.settings_outlined, _openSettings),
              ],
              const SizedBox(width: 6),
              _circleBtn(Icons.share_outlined, _shareRoom),
              const SizedBox(width: 6),
              _circleBtn(Icons.power_settings_new, _onPowerTap),
            ],
          );
        },
      ),
    );
  }

  Widget _seatsArea() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _seatsStream ??= _firestore.roomDoc(_roomId!),
      builder: (context, snap) {
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return const Center(
              child: Text('Room ended', style: TextStyle(color: AppColors.muted)));
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final seats = List<dynamic>.from(data['seats'] ?? []);
        final lockedSeats = List<int>.from(data['lockedSeats'] ?? []);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: .78,
          ),
          itemCount: seats.length,
          itemBuilder: (context, i) {
            final seatData = seats[i] == null
                ? null
                : Map<String, dynamic>.from(seats[i] as Map);

            bool speaking = false;
            if (seatData != null && seatData['uid'] != null) {
              final agoraUid =
                  AgoraService.uidToAgoraUid(seatData['uid'] as String);
              speaking = _speakingAgoraUids.contains(agoraUid);
            }

            return _SeatWidget(
              index: i,
              seat: seatData,
              isMe: seatData != null &&
                  seatData['uid'] == AppState.instance.uid,
              isSpeaking: speaking,
              isLocked: lockedSeats.contains(i),
              onTap: () => _onSeatTap(i, seatData, lockedSeats),
            );
          },
        );
      },
    );
  }

  Widget _chatArea() {
    return SizedBox(
      height: 130,
      child: ListView(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: _chat.reversed.map((c) => _chatBubble(c)).toList(),
      ),
    );
  }

  Widget _chatBubble(_ChatLine c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.isGift
            ? AppColors.gold.withOpacity(.12)
            : Colors.black.withOpacity(.35),
        border:
            c.isGift ? Border.all(color: AppColors.gold.withOpacity(.3)) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12.5, color: Colors.white),
          children: [
            TextSpan(
                text: '${c.user}: ',
                style: TextStyle(
                    color: c.isGift ? AppColors.gold : AppColors.cyan,
                    fontWeight: FontWeight.bold)),
            TextSpan(text: c.text),
          ],
        ),
      ),
    );
  }

  Widget _micRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleMic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _micMuted
                    ? Colors.redAccent.withOpacity(.18)
                    : AppColors.cyan.withOpacity(.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: _micMuted ? Colors.redAccent : AppColors.cyan),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_micMuted ? Icons.mic_off : Icons.mic,
                      size: 18,
                      color: _micMuted ? Colors.redAccent : AppColors.cyan),
                  const SizedBox(width: 8),
                  Text(_micMuted ? 'Unmute yourself' : 'Mute yourself',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _micMuted ? Colors.redAccent : AppColors.cyan)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (val) {
                if (val.trim().isEmpty) return;
                _addChat('You', val.trim(), false);
                _chatCtrl.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _giftTrayOpen = true),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  gradient:
                      LinearGradient(colors: [AppColors.hot, Color(0xFFFF6B9D)]),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('🎁'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _giftTray() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Send a Gift',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              CoinPill(coins: AppState.instance.coins),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kGifts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final g = kGifts[i];
                final selected = _selectedGift == g['id'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedGift = g['id'] as String),
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      border: Border.all(
                          color: selected ? AppColors.gold : AppColors.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(g['icon'] as String,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text('${g['price']} 🪙',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600)),
                        Text(g['name'] as String,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _giftTrayOpen = false),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                    onPressed: _sendGift, child: const Text('Send Gift')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatWidget extends StatefulWidget {
  final int index;
  final Map<String, dynamic>? seat;
  final bool isMe;
  final bool isSpeaking;
  final bool isLocked;
  final VoidCallback onTap;

  const _SeatWidget({
    required this.index,
    required this.seat,
    required this.isMe,
    required this.isSpeaking,
    required this.isLocked,
    required this.onTap,
  });

  @override
  State<_SeatWidget> createState() => _SeatWidgetState();
}

class _SeatWidgetState extends State<_SeatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final occupied = widget.seat != null;
    final name = widget.seat?['name'] as String?;
    final isMuted = widget.seat?['isMuted'] == true;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final glow = widget.isSpeaking ? _pulseCtrl.value : 0.0;
              return Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: occupied
                      ? const LinearGradient(
                          colors: [AppColors.hot, Color(0xFF7A1BFF)])
                      : null,
                  color: occupied ? null : Colors.white.withOpacity(.06),
                  border: Border.all(
                    color: widget.isSpeaking
                        ? AppColors.cyan
                        : (widget.isMe
                            ? AppColors.gold
                            : (occupied ? Colors.transparent : AppColors.line)),
                    width: widget.isSpeaking ? 2.5 : (widget.isMe ? 2 : 1),
                  ),
                  boxShadow: widget.isSpeaking
                      ? [
                          BoxShadow(
                            color:
                                AppColors.cyan.withOpacity(0.15 + glow * 0.45),
                            blurRadius: 6 + glow * 10,
                            spreadRadius: 1 + glow * 4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: occupied
                    ? Text(
                        name != null && name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      )
                    : (widget.isLocked
                        ? const Icon(Icons.lock, size: 16, color: AppColors.muted)
                        : const Icon(Icons.add, size: 18, color: AppColors.muted)),
              );
            },
          ),
          const SizedBox(height: 3),
          if (occupied)
            Icon(isMuted ? Icons.mic_off : Icons.mic,
                size: 11,
                color: widget.isSpeaking
                    ? AppColors.cyan
                    : (isMuted ? Colors.redAccent : AppColors.cyan))
          else
            Text(
              widget.isLocked ? 'Locked' : 'Seat ${widget.index + 1}',
              style: const TextStyle(fontSize: 8, color: AppColors.muted),
            ),
          if (occupied)
            SizedBox(
              width: 50,
              child: Text(
                name ?? '',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlyingGiftWidget extends StatefulWidget {
  final _FlyingGift gift;
  const _FlyingGiftWidget({required this.gift});

  @override
  State<_FlyingGiftWidget> createState() => _FlyingGiftWidgetState();
}

class _FlyingGiftWidgetState extends State<_FlyingGiftWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final opacity = t < 0.1 ? t / 0.1 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        return Positioned(
          left: MediaQuery.of(context).size.width * widget.gift.left,
          bottom: 90 + t * (h * 0.42),
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Text(widget.gift.icon, style: const TextStyle(fontSize: 34)),
          ),
        );
      },
    );
  }
}
