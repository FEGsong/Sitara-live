import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/agora_service.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_pill.dart';

class LiveScreen extends StatefulWidget {
  final bool isHost;
  final String? hostName;
  final String? viewers;
  const LiveScreen(
      {super.key, required this.isHost, this.hostName, this.viewers});

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
  final _chatCtrl = TextEditingController();
  final List<_ChatLine> _chat = [];
  final List<_FlyingGift> _flyingGifts = [];

  Timer? _mockTimer;
  String? _selectedGift;
  bool _giftTrayOpen = false;
  bool _showAdminEffect = false;
  int _viewerCount = 128;

  @override
  void initState() {
    super.initState();
    // Channel name would normally be the room/session id from your backend.
    final channel = 'room_${widget.hostName ?? 'self'}';
    _connectToLive(channel);

    _mockTimer =

    if (!widget.isHost && AppState.instance.adminMode) {
      Future.delayed(const Duration(milliseconds: 800), _triggerAdminEffect);
    }
  }

  Future<void> _connectToLive(String channel) async {
  try {
    await _agora.joinChannel(channel: channel, isHost: widget.isHost);
    if (mounted) setState(() {});
  } catch (e) {
    _addChat('System', 'Could not connect: $e', false);
  }
}

  @override
  void dispose() {
    _mockTimer?.cancel();
    _agora.leaveChannel();
    super.dispose();
  }

  void _addChat(String user, String text, bool isGift) {
    setState(() {
      _chat.add(_ChatLine(user, text, isGift));
      if (_chat.length > 10) _chat.removeAt(0);
    });
  }

  void _mockActivity() {
    const users = ['Hamza', 'Iqra', 'Usman', 'Fatima', 'Ali_92', 'Noor'];
    const msgs = [
      'Assalam o Alaikum!',
      'Hey everyone!',
      'Nice stream 🔥',
      'Audio is crystal clear',
      '👏👏👏'
    ];
    final rnd = Random();
    _addChat(users[rnd.nextInt(users.length)], msgs[rnd.nextInt(msgs.length)],
        false);
    setState(() => _viewerCount = 120 + rnd.nextInt(40));
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

  void _triggerAdminEffect() {
    setState(() => _showAdminEffect = true);
    _addChat('System', '👑 Admin joined the live!', true);
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _showAdminEffect = false);
    });
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // video surface
          Positioned.fill(child: _buildVideoSurface()),

          // top bar: host chip + close
          Positioned(
            top: 14,
            left: 14,
            right: 14,
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [AppColors.hot, Color(0xFF7A1BFF)]),
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (_showAdminEffect)
                            Positioned.fill(
                              child: _RotatingAura(),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isHost
                                ? (AppState.instance.nickname.isNotEmpty
                                    ? AppState.instance.nickname
                                    : 'You (Host)')
                                : (widget.hostName ?? 'Host'),
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          Text('● $_viewerCount viewers',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.cyan)),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
          ),

          // admin gold pulsing border
          if (_showAdminEffect)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 3),
                ),
              ),
            ),

          // admin rising coin
          if (_showAdminEffect) const _RisingCoin(),

          // chat area
          Positioned(
            left: 0,
            bottom: 78,
            width: MediaQuery.of(context).size.width * .68,
            height: MediaQuery.of(context).size.height * .32,
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _chat.reversed.map((c) => _chatBubble(c)).toList(),
            ),
          ),

          // flying gifts
          ..._flyingGifts.map((g) => _FlyingGiftWidget(gift: g)),

          // bottom bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent]),
              ),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
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
                          gradient: LinearGradient(
                              colors: [AppColors.hot, Color(0xFFFF6B9D)]),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('🎁'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // gift tray
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

  Widget _buildVideoSurface() {
    if (widget.isHost && _agora.engine != null) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _agora.engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
    // Viewer surface would use VideoViewController.remote() once you track
    // the remote uid from onUserJoined — placeholder shown until then.
    return Container(
      color: const Color(0xFF050508),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.isHost ? '📷' : '🎥',
              style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          Text(
            widget.isHost
                ? 'Connecting camera…'
                : '${widget.hostName ?? 'Host'} is broadcasting live',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
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

class _RotatingAura extends StatefulWidget {
  @override
  State<_RotatingAura> createState() => _RotatingAuraState();
}

class _RotatingAuraState extends State<_RotatingAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            AppColors.gold,
            Colors.transparent,
            AppColors.gold,
            Colors.transparent
          ]),
        ),
      ),
    );
  }
}

class _RisingCoin extends StatefulWidget {
  const _RisingCoin();
  @override
  State<_RisingCoin> createState() => _RisingCoinState();
}

class _RisingCoinState extends State<_RisingCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900))
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
        final opacity = t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
        return Positioned(
          bottom: 100 + t * (h * 0.4),
          left: 0,
          right: 0,
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.rotate(
              angle: t * 10,
              child: const Center(
                  child: Text('🪙', style: TextStyle(fontSize: 40))),
            ),
          ),
        );
      },
    );
  }
}
