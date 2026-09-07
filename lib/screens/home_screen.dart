import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_pill.dart';
import 'live_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'inbox_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Keep AppState in sync with this user's Firestore document for
    // as long as HomeScreen (and its tabs) are on screen.
    _firestore.userDoc(AppState.instance.uid).listen((doc) {
      if (doc.exists) {
        setState(() => AppState.instance.syncFromFirestore(doc.data() as Map<String, dynamic>));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_HomeTab(), const WalletScreen(embedded: true), const InboxScreen(embed: true), const ProfileScreen(embedded: true)];

    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: AppColors.bgDeep,
        indicatorColor: Colors.transparent,
        destinations: const [
  NavigationDestination(icon: Icon(Icons.home_outlined, color: AppColors.muted), selectedIcon: Icon(Icons.home, color: AppColors.hot), label: 'Home'),
  NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.muted), selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.hot), label: 'Wallet'),
  NavigationDestination(icon: Icon(Icons.mail_outline, color: AppColors.muted), selectedIcon: Icon(Icons.mail, color: AppColors.hot), label: 'Inbox'),
  NavigationDestination(icon: Icon(Icons.person_outline, color: AppColors.muted), selectedIcon: Icon(Icons.person, color: AppColors.hot), label: 'Profile'),
],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final _firestore = FirestoreService();

  void _pickSeatsAndGoLive(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        const seatOptions = [15, 25, 50, 100];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose Room Size',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('How many seats should this voice room have?',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 18),
              ...seatOptions.map((count) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LiveScreen(isHost: true, seatCount: count),
                            ),
                          );
                        },
                        child: Text('$count Seats'),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sitara Live', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                CoinPill(coins: state.coins),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2A0E3D), Color(0xFF3A0F2E)]),
                border: Border.all(color: const Color(0xFF43223F)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start a Voice Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Pick a room size and go live — listeners can join, take a seat, and send gifts.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => _pickSeatsAndGoLive(context),
                    child: const Text('🔴 Go Live'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Text('LIVE NOW',
                style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold, letterSpacing: .8)),
          ),
        ),
        SliverToBoxAdapter(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestore.liveRooms(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final rooms = snapshot.data ?? [];

              if (rooms.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.mic_none_outlined, size: 40, color: AppColors.muted),
                        SizedBox(height: 10),
                        Text('No one is live right now',
                            style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Be the first — tap Go Live above!',
                            style: TextStyle(color: AppColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .82,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) => _LiveCard(room: rooms[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  final Map<String, dynamic> room;
  const _LiveCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final c1 = Color(room['c1'] ?? 0xFF7A1BFF);
    final c2 = Color(room['c2'] ?? 0xFFFF2E6B);
    final seats = List<dynamic>.from(room['seats'] ?? []);
    final seatedCount = seats.where((s) => s != null).length;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveScreen(
            isHost: false,
            roomId: room['id'],
            hostName: room['hostName'] ?? 'Host',
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c1, c2]),
                ),
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.hot, borderRadius: BorderRadius.circular(6)),
                        child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(.5), borderRadius: BorderRadius.circular(6)),
                        child: Text('🎙 $seatedCount/${room['seatCount'] ?? seats.length}', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room['hostName'] ?? 'Host', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Voice Room', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
