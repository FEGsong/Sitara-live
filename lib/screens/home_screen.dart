import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_pill.dart';
import 'live_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'inbox_screen.dart';

/// Mock list of currently-live hosts — swap for a real Firestore query
/// (e.g. "rooms" collection where status == 'live') once the backend exists.
final List<Map<String, dynamic>> mockLiveHosts = [
  {'name': 'Ayesha_Live', 'tag': 'Music & Chill', 'viewers': '1.2k', 'c1': const Color(0xFFFF2E6B), 'c2': const Color(0xFF7A1BFF)},
  {'name': 'Bilal_Talks', 'tag': 'Just Chatting', 'viewers': '845', 'c1': const Color(0xFF2DE8C4), 'c2': const Color(0xFF12707F)},
  {'name': 'Sana_Vlogs', 'tag': 'Cooking Live', 'viewers': '2.4k', 'c1': const Color(0xFFFFC93C), 'c2': const Color(0xFFB5641A)},
  {'name': 'Zain_Gaming', 'tag': 'PUBG Live', 'viewers': '3.1k', 'c1': const Color(0xFF7A1BFF), 'c2': const Color(0xFFFF2E6B)},
];

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
    final pages = [_HomeTab(), const WalletScreen(embed: true), const InboxScreen(embed: true), const ProfileScreen(embed: true)];

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
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
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
                  const Text('Start Your Live Stream', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Turn on your camera and mic to start broadcasting — viewers can send you gifts.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LiveScreen(isHost: true)),
                    ),
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
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final h = mockLiveHosts[i];
                return _LiveCard(host: h);
              },
              childCount: mockLiveHosts.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  final Map<String, dynamic> host;
  const _LiveCard({required this.host});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveScreen(isHost: false, hostName: host['name'], viewers: host['viewers'])),
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
                  gradient: LinearGradient(colors: [host['c1'], host['c2']]),
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
                        child: Text('👁 ${host['viewers']}', style: const TextStyle(fontSize: 10)),
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
                  Text(host['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(host['tag'], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
