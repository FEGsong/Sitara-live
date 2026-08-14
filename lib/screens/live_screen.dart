import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/agora_service.dart';
import '../widgets/coin_pill.dart';

class LiveScreen extends StatefulWidget {
  final bool isHost;
  final String? hostName;
  final String? viewers;
  const LiveScreen({super.key, required this.isHost, this.hostName, this.viewers});

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
    _agora.joinChannel(channel: channel, isHost: widget.isHost).catchError((e) {
      _addChat('System', 'Could not connect: $e', false);
    });

    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) => _mockActivity());

    if (!widget.isHost && AppState.instance.adminMode) {
      Future.delayed(const Duration(milliseconds: 800), _triggerAdminEffect);
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
    const msgs = ['Assalam o Alaikum!', 'Hey everyone!', 'Nice stream 🔥', 'Audio is crystal clear', '👏👏👏'];
    final rnd = Random();
    _addChat(users[rnd.nextInt(users.length)], msgs[rnd.nextInt(msgs.length)], false);
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
      AppState.instance.spendCoins(gift['price'] as int);
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
            top: 14, left: 14, right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(.45), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.hot, Color(0xFF7A1BFF)]),
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
