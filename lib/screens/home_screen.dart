import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/coin_pill.dart';
import 'live_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';

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
    final pages = [_HomeTab(), const WalletScreen(embedded: true), const ProfileScreen(embedded: true)];

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
          NavigationDestination(icon: Icon(Icons.person_outline, color: AppColors.muted), selectedIcon: Icon(Icons.person, color: AppColors.hot), label: 'Profile'),
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
