import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/agora_service.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_pill.dart';

class LiveScreen extends StatefulWidget {
  final bool isHost;
  final int seatCount; // used when isHost creates a brand-new room
  final String? roomId; // required when joining an existing room,
  // or when a host is rejoining their own already-live room
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
  bool _connecting = true;

  String? _selectedGift;
  bool _giftTrayOpen = false;

  @override
  void initState() {
    super.initState();
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
      final name = AppState.instance.nickname.isNotEmpty
          ? AppState.instance.nickname
          : 'Host';
      final id = await _firestore.createRoom(
        hostUid: uid,
        hostName: name,
        seatCount: widget.seatCount,
      );
      await _agora.joinChannel(channel: id, isHost: true);
      if (!mounted) return;
      setState(() {
        _roomId = id;
        _mySeatIndex = 0;
        _connecting = false;
      });
    } catch (e) {
      _addChat('System', 'Could not start room: $e', false);
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// Host tapped "My Room" on Home to jump back into their still-live
  /// room instead of creating a new one.
  Future<void> _rejoinAsHost() async {
    try {
      _roomId = widget.roomId;
      await _agora.joinChannel(channel: _roomId!, isHost: true);
      if (!mounted) return;
      setState(() {
        _mySeatIndex = 0;
        _connecting = false;
      });
    } catch (e) {
      _addChat('System', 'Could not rejoin room: $e', false);
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _joinAsListener() async {
    if (_roomId == null) {
      if (mounted) setState(() => _connecting = false);
      return;
    }
    try {
      final snap = await _firestore.getRoomOnce(_roomId!);
      final data = snap.data() as Map<String, dynamic>?;
      if (data != null) {
        _firestore.recordRecentRoom(
          uid: AppState.instance.uid,
          roomId: _roomId!,
          hostName: data['hostName'] ?? widget.hostName ?? 'Host',
          c1: data['c1'] ?? 0xFF7A1BFF,
          c2: data['c2'] ?? 0xFFFF2E6B,
        );
      }
      await _firestore.incrementViewers(_roomId!, 1);
      await _agora.joinChannel(channel: _roomId!, isHost: false);
    } catch (e) {
      _addChat('System', 'Could not connect: $e', false);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    if (_roomId != null) {
      if (widget.isHost) {
        _firestore.endRoom(_roomId!);
      } else {
        _firestore.incrementViewers(_roomId!, -1);
        if (_mySeatIndex != null) {
          _firestore.leaveSeat(_roomId!, _mySeatIndex!);
        }
      }
    }
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

  Future<void> _onSeatTap(int index, Map<String, dynamic>? seatData) async {
    if (_roomId == null) return;
    final uid = AppState.instance.uid;

    if (seatData != null && seatData['uid'] == uid) {
      await _firestore.leaveSeat(_roomId!, index);
      await _agora.setSpeakingRole(false);
      if (mounted) setState(() => _mySeatIndex = null);
      return;
    }

    if (seatData != null) {
      _snack('Seat already taken');
      return;
    }

    if (_mySeatIndex != null) {
      _snack('Leave your current seat first');
      return;
    }

    final name = AppState.instance.nickname.isNotEmpty
        ? AppState.instance.nickname
        : 'Guest';
    await _firestore.takeSeat(_roomId!, index, uid, name);
    await _agora.setSpeakingRole(true);
    if (mounted) setState(() => _mySeatIndex = index);
    _addChat('System', '$name joined the seat 🎙', false);
  }

  Future<void> _toggleMic() async {
    final newMuted = !_micMuted;
    setState(() => _micMuted = newMuted);
    await _agora.toggleMic(newMuted);
    if (_roomId != null && _mySeatIndex != null) {
      await _firestore.toggleSeatMute(_roomId!, _mySeatIndex!, newMuted);
    }
  }

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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _endOrLeave() async {
    Navigator.of(context).pop();
  }

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
          if (_connecting || _roomId == null)
            const Center(child: CircularProgressIndicator())
          else
            SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _seatsArea()),
                  _chatArea(),
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(.45),
                borderRadius: BorderRadius.circular(999)),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient:
                        LinearGradient(colors: [AppColors.hot, Color(0xFF7A1BFF)]),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎙', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.roomDoc(_roomId!),
                  builder: (context, snap) {
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final hostName =
                        data?['hostName'] ?? widget.hostName ?? 'Host';
                    final viewers = data?['viewers'] ?? 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hostName,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Text('● $viewers listening',
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.cyan)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleMic,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.45),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(_micMuted ? Icons.mic_off : Icons.mic,
                      size: 16,
                      color: _micMuted ? Colors.redAccent : Colors.white),
                ),
              ),
              GestureDetector(
                onTap: _endOrLeave,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.45),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child:
                      const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seatsArea() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.roomDoc(_roomId!),
      builder: (context, snap) {
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return const Center(
              child: Text('Room ended', style: TextStyle(color: AppColors.muted)));
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final seats = List<dynamic>.from(data['seats'] ?? []);

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
            return _SeatWidget(
              index: i,
              seat: seatData,
              isMe: seatData != null &&
                  seatData['uid'] == AppState.instance.uid,
              onTap: () => _onSeatTap(i, seatData),
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

class _SeatWidget extends StatelessWidget {
  final int index;
  final Map<String, dynamic>? seat;
  final bool isMe;
  final VoidCallback onTap;

  const _SeatWidget({
    required this.index,
    required this.seat,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final occupied = seat != null;
    final name = seat?['name'] as String?;
    final isMuted = seat?['isMuted'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                color: isMe
                    ? AppColors.gold
                    : (occupied ? Colors.transparent : AppColors.line),
                width: isMe ? 2 : 1,
              ),
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
                : const Icon(Icons.add, size: 18, color: AppColors.muted),
          ),
          const SizedBox(height: 3),
          if (occupied)
            Icon(isMuted ? Icons.mic_off : Icons.mic,
                size: 11, color: isMuted ? Colors.redAccent : AppColors.cyan)
          else
            Text('Seat ${index + 1}',
                style: const TextStyle(fontSize: 8, color: AppColors.muted)),
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
